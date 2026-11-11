-- Independent, bounded crafting model using PoB's game-data modifier tables.
local encounter = require("Modules.CalcEncounter")
local M = { }
M.methods = {"transmute","alteration","augmentation","regal","alchemy","chaos","exalt","annul","scour","divine","bench","remove_crafted","essence"}
M.labels = {transmute="Orb of Transmutation",alteration="Orb of Alteration",augmentation="Orb of Augmentation",regal="Regal Orb",alchemy="Orb of Alchemy",chaos="Chaos Orb",exalt="Exalted Orb",annul="Orb of Annulment",scour="Orb of Scouring",divine="Divine Orb",bench="Crafting bench",remove_crafted="Remove crafted modifiers",essence="Essence"}
M.limits = {"Experimental PoE 1 model, not a complete game crafting implementation.",
	"Supported: ordinary equipment, known modifier IDs, fractured modifiers, basic currencies, bench modifiers and essences. Meta modifiers protect/remap only the supported actions.",
	"Unsupported actions fail explicitly: fossils, Harvest, recombination, influence orbs, corruption, sockets/links, veiled crafts and special league mechanics.",
	"Rerolls model 4/5/6 rare modifiers with weights 8/3/1, and 1/2 magic modifiers equally. These distribution assumptions and PoB data coverage affect estimates.",
	"Integer roll ranges use inclusive integer draws. Fractional display ranges use illustrative normalized rolls because the underlying stat precision is not present in this data export.",
	"Targets match modifier IDs, not numeric roll thresholds. Wilson intervals measure sampling uncertainty only. Results describe the bounded recipe, not guaranteed in-game costs."}

local function integer(value,low,high,label)
	assert(type(value) == "number" and value == math.floor(value) and value >= low and value <= high,"Invalid "..label)
	return value
end
local function rng(seed)
	local value=seed
	return function() value=value*16807%2147483647; return value/2147483647 end
end
local function copyState(state)
	return copyTable(state)
end
local function renderLines(item)
	local lines={ }
	for _,line in ipairs(item.explicitModLines) do lines[#lines+1]=StripEscapes(itemLib.formatModLine(line,false) or "") end
	table.sort(lines)
	return table.concat(lines,"\n")
end
local function flags(model,state)
	local result={ }
	for _,entry in ipairs(state.affixes) do
		local mod=model.byId[entry.id]
		for _,line in ipairs(mod) do
			if line == "Prefixes Cannot Be Changed" then result.prefixes=true end
			if line == "Suffixes Cannot Be Changed" then result.suffixes=true end
			if line == "Cannot roll Attack Modifiers" then result.attack=true end
			if line == "Cannot roll Caster Modifiers" then result.caster=true end
			if line == "Can have up to 3 Crafted Modifiers" then result.multipleCrafts=true end
		end
	end
	return result
end
local function counts(model,state)
	local result={Prefix=0,Suffix=0,crafted=0,total=#state.affixes,groups={},tags={}}
	for _,entry in ipairs(state.affixes) do
		local mod=assert(model.byId[entry.id],"Unknown modifier ID: "..tostring(entry.id))
		result[mod.type]=result[mod.type]+1
		if mod.group then result.groups[mod.group]=true end
		if entry.crafted then result.crafted=result.crafted+1 end
		for _,tag in ipairs(mod.tags or { }) do result.tags[tag]=true end
	end
	return result
end

function M.toItem(model,state)
	local item=new("Item"):Item(model.raw)
	item.rarity=state.rarity; item.title=state.rarity == "RARE" and "Simulated craft" or nil
	item.name=item.title or item.baseName
	item.crafted=true; item.prefixes={}; item.suffixes={}; item.explicitModLines={}
	item.affixLimit=state.rarity == "MAGIC" and 2 or 6
	item.prefixes.limit=state.rarity == "MAGIC" and 1 or 3
	item.suffixes.limit=item.prefixes.limit
	for _,entry in ipairs(state.affixes) do
		local mod=model.byId[entry.id]
		if not entry.crafted then
			local list=mod.type == "Prefix" and item.prefixes or item.suffixes
			list[#list+1]={modId=entry.id,range=type(entry.range) == "table" and copyTable(entry.range) or {entry.range or 0.5},fractured=entry.fractured}
		end
	end
	for _,list in ipairs({item.prefixes,item.suffixes}) do for i=#list+1,list.limit do list[i]={modId="None"} end end
	item:Craft()
	local hasBench=false
	for _,entry in ipairs(state.affixes) do if entry.crafted then
		hasBench=true
		local mod=model.byId[entry.id]
		for _,line in ipairs(mod) do item.explicitModLines[#item.explicitModLines+1]={line=itemLib.applyRange(line,entry.range or 0.5),crafted=true,prefix=mod.type == "Prefix",suffix=mod.type == "Suffix"} end
	end end
	if hasBench then
		for _,list in ipairs({item.prefixes,item.suffixes}) do for _,entry in ipairs(list) do if type(entry.range) == "number" then entry.range={entry.range} end end end
		item:BuildAndParseRaw()
	end
	return item
end

function M.model(raw)
	assert(type(raw) == "string" and #raw <= 24000,"Invalid starting item")
	local item=new("Item"):Item(raw)
	assert(item.base and item.itemLevel,"A recognized base and explicit Item Level are required")
	assert(not raw:find("\nUnidentified",1,true),"Identify the starting item before importing its modifiers")
	integer(item.itemLevel,1,100,"item level")
	assert(item.rarity == "NORMAL" or item.rarity == "MAGIC" or item.rarity == "RARE","Unique and relic crafting is not supported")
	assert(not item.corrupted and not item.mirrored and not item.foulborn,"Corrupted, mirrored or foulborn items are not supported")
	local equipment={Helmet=true,["Body Armour"]=true,Gloves=true,Boots=true,Shield=true,Quiver=true,Amulet=true,Ring=true,Belt=true}
	assert(equipment[item.type] or data.weaponTypeInfo[item.type],"This engine currently supports ordinary equipment; this item type is unsupported")
	if item.fractured then for _,info in ipairs(itemLib.influenceInfo.all) do assert(not item[info.key],"Fractured and influenced combinations are unsupported") end end
	local model={raw=item.raw,item=item,byId={},mods={},bench={},essences={}}
	for id,mod in pairs(item.affixes or { }) do model.byId[id]=mod end
	for id,mod in pairs(data.itemMods.Explicit) do
		if (mod.type == "Prefix" or mod.type == "Suffix") and mod.level <= item.itemLevel and not mod.affix:find("Elevated",1,true) then
			local weight=item:GetModSpawnWeight(mod)
			if weight > 0 then model.mods[#model.mods+1]={id=id,mod=mod,weight=weight} end
		end
	end
	table.sort(model.mods,function(a,b) return a.id < b.id end)
	for index,mod in ipairs(data.masterMods) do
		if mod.types and mod.types[item.type] and (mod.type == "Prefix" or mod.type == "Suffix") then
			local id="bench:"..index
			model.byId[id]=mod; model.bench[#model.bench+1]={id=id,mod=mod}
		end
	end
	for id,essence in pairs(data.essences) do
		local modId=essence.mods[item.type]
		if modId and model.byId[modId] then model.essences[#model.essences+1]={id=id,name=essence.name,modId=modId,tier=essence.tier,type=essence.type} end
	end
	table.sort(model.essences,function(a,b) return a.id < b.id end)
	local state={rarity=item.rarity,affixes={}}
	for _,list in ipairs({item.prefixes,item.suffixes}) do for _,entry in ipairs(list) do
		if entry.modId ~= "None" then
			assert(model.byId[entry.modId],"Starting item has an unknown modifier")
			state.affixes[#state.affixes+1]={id=entry.modId,range=type(entry.range) == "table" and copyTable(entry.range) or entry.range,fractured=entry.fractured or false}
		end
	end end
	-- Resolve bench lines by their native crafted flag and exact rendered values.
	for _,line in ipairs(item.explicitModLines) do if line.crafted then
		local matched
		for _,entry in ipairs(model.bench) do if #entry.mod == 1 and itemLib.applyRange(entry.mod[1],line.range or 0.5) == itemLib.applyRange(line.line,line.range or 0.5) then matched=entry.id; break end end
		assert(matched,"Import this bench modifier through the native engine; its exact modifier ID is unresolved")
		state.affixes[#state.affixes+1]={id=matched,range=line.range or 0.5,crafted=true}
	end end
	local c=counts(model,state)
	for _,entry in ipairs(state.affixes) do if entry.fractured then for _,info in ipairs(itemLib.influenceInfo.all) do assert(not item[info.key],"Fractured and influenced combinations are unsupported") end end end
	assert(c.Prefix <= (state.rarity == "MAGIC" and 1 or 3) and c.Suffix <= (state.rarity == "MAGIC" and 1 or 3),"Starting item exceeds affix limits")
	assert(renderLines(M.toItem(model,state)) == renderLines(item),"Starting modifiers could not be resolved exactly. Use a blank base or advanced item text with recognized modifier IDs.")
	model.initial=state
	return model
end

function M.pool(model,state)
	local c,f=counts(model,state),flags(model,state)
	for key,value in pairs(state.rollBlock or { }) do f[key]=value end
	local cap=state.rarity == "MAGIC" and 1 or 3
	local result,total={},0
	for _,entry in ipairs(model.mods) do
		local mod=entry.mod
		local blocked=c[mod.type] >= cap or c.groups[mod.group]
		for _,tag in ipairs(mod.modTags or { }) do if f[tag] then blocked=true end end
		if not blocked then
			local weight=next(c.tags) and model.item:GetModSpawnWeight(mod,c.tags) or entry.weight
			if weight > 0 then result[#result+1]={id=entry.id,weight=weight}; total=total+weight end
		end
	end
	return result,total
end
local function rollRange(mod,random)
	local ranges={ }
	for _,line in ipairs(mod) do for range in line:gmatch("%b()") do
		local low,high=range:match("(%-?%d+%.?%d*)%-(%-?%d+%.?%d*)")
		if low and high then
			low,high=tonumber(low),tonumber(high)
			local value=random()
			if low < high and low == math.floor(low) and high == math.floor(high) then value=math.floor(value*(high-low+1))/(high-low) end
			ranges[#ranges+1]=value
		end
	end end
	return #ranges > 1 and ranges or ranges[1] or 0.5
end
local function add(model,state,random)
	local pool,total=M.pool(model,state)
	assert(total > 0,"No legal modifier can be added")
	local pick=random()*total
	for _,entry in ipairs(pool) do
		pick=pick-entry.weight
		if pick < 0 then state.affixes[#state.affixes+1]={id=entry.id,range=rollRange(model.byId[entry.id],random)}; return end
	end
	error("Could not select a modifier")
end
local function protected(entry,mod,f) return entry.fractured or mod.type == "Prefix" and f.prefixes or mod.type == "Suffix" and f.suffixes end
local function clear(model,state,ignoreMeta)
	local f=ignoreMeta and {} or flags(model,state)
	for i=#state.affixes,1,-1 do if not protected(state.affixes[i],model.byId[state.affixes[i].id],f) then table.remove(state.affixes,i) end end
end

function M.action(model,input,action,random)
	local state=copyState(input)
	local method=action.method
	local c,f=counts(model,state),flags(model,state)
	if method == "transmute" or method == "alteration" or method == "alchemy" or method == "chaos" then
		local magic=method == "transmute" or method == "alteration"
		local required=(method == "transmute" or method == "alchemy") and "NORMAL" or magic and "MAGIC" or "RARE"
		assert(state.rarity == required,"This currency cannot be used on the current rarity")
		clear(model,state)
		state.rollBlock={attack=f.attack,caster=f.caster}
		state.rarity=magic and "MAGIC" or "RARE"
		local value=random()
		local target=magic and (value < 0.5 and 1 or 2) or (value < 8/12 and 4 or value < 11/12 and 5 or 6)
		while #state.affixes < target do add(model,state,random) end
	elseif method == "augmentation" or method == "regal" or method == "exalt" then
		assert(state.rarity == (method == "exalt" and "RARE" or "MAGIC"),"This currency cannot be used on the current rarity")
		assert(c.total < (method == "augmentation" and 2 or 6),"The item has no open affix")
		if method == "regal" then state.rarity="RARE" end
		add(model,state,random)
	elseif method == "annul" then
		assert(state.rarity ~= "NORMAL","Annulment requires a magic or rare item")
		local eligible={ }
		for index,entry in ipairs(state.affixes) do if not protected(entry,model.byId[entry.id],f) then eligible[#eligible+1]=index end end
		assert(#eligible > 0,"No modifier can be removed")
		table.remove(state.affixes,eligible[math.floor(random()*#eligible)+1])
	elseif method == "scour" then
		assert(state.rarity ~= "NORMAL","Scouring requires a magic or rare item")
		clear(model,state)
		local left=counts(model,state)
		state.rarity=left.total == 0 and "NORMAL" or left.Prefix <= 1 and left.Suffix <= 1 and "MAGIC" or "RARE"
	elseif method == "divine" then
		assert(state.rarity ~= "NORMAL","Divine requires a magic or rare item")
		for _,entry in ipairs(state.affixes) do if not protected(entry,model.byId[entry.id],f) then entry.range=rollRange(model.byId[entry.id],random) end end
	elseif method == "bench" then
		local mod=assert(model.byId[action.modId],"Unknown bench modifier")
		assert(action.modId:match("^bench:"),"Select a bench modifier")
		assert(c.crafted < (f.multipleCrafts and 3 or 1),"Crafted modifier limit reached")
		assert(not c.groups[mod.group],"A modifier from this group is already present")
		assert(c[mod.type] < (state.rarity == "RARE" and 3 or 1),"No open affix for this bench craft")
		if state.rarity == "NORMAL" then state.rarity="MAGIC" end
		state.affixes[#state.affixes+1]={id=action.modId,range=rollRange(mod,random),crafted=true}
	elseif method == "remove_crafted" then
		assert(c.crafted > 0,"The item has no crafted modifiers")
		for i=#state.affixes,1,-1 do if state.affixes[i].crafted then table.remove(state.affixes,i) end end
	elseif method == "essence" then
		local selected
		for _,entry in ipairs(model.essences) do if entry.id == action.essenceId then selected=entry; break end end
		assert(selected,"This essence cannot be used on this base")
		assert(state.rarity == "NORMAL" or state.rarity == "RARE" and (selected.tier >= 5 or selected.type > 0),"This essence cannot be used on the current rarity")
		clear(model,state,true); state.rarity="RARE"
		local mod=model.byId[selected.modId]
		assert(not counts(model,state).groups[mod.group],"The essence modifier conflicts with a fractured modifier")
		state.affixes[#state.affixes+1]={id=selected.modId,range=rollRange(mod,random)}
		local value=random(); local target=value < 8/12 and 4 or value < 11/12 and 5 or 6
		while #state.affixes < target do add(model,state,random) end
	else error("Unsupported crafting action: "..tostring(method)) end
	state.rollBlock=nil
	return state
end

function M.matches(state,targets,rarity)
	if rarity and state.rarity ~= rarity then return false end
	for _,group in ipairs(targets) do
		local hit=false
		for _,entry in ipairs(state.affixes) do for _,id in ipairs(group.anyOf) do if entry.id == id then hit=true end end end
		if not hit then return false end
	end
	return true
end
function M.validateRecipe(recipe)
	assert(type(recipe) == "table" and type(recipe.steps) == "table" and #recipe.steps >= 1 and #recipe.steps <= 20,"Use one to twenty recipe steps")
	assert(type(recipe.targets) == "table" and #recipe.targets >= 1 and #recipe.targets <= 6,"Choose one to six target groups")
	assert(not recipe.rarity or recipe.rarity == "MAGIC" or recipe.rarity == "RARE","Invalid target rarity")
	local methods={ }
	for _,method in ipairs(M.methods) do methods[method]=true end
	local function validateTargets(targets)
	assert(type(targets) == "table" and #targets >= 1 and #targets <= 6,"Choose one to six target groups")
	for _,group in ipairs(targets) do
		assert(type(group.anyOf) == "table" and #group.anyOf >= 1 and #group.anyOf <= 30,"Use one to thirty modifier IDs per target group")
		for _,id in ipairs(group.anyOf) do assert(type(id) == "string" and #id <= 160,"Invalid target modifier ID") end
	end
	end
	validateTargets(recipe.targets)
	for _,step in ipairs(recipe.steps) do
		assert(methods[step.method],"Unsupported crafting action: "..tostring(step.method))
		integer(step.maxAttempts or 1,1,200,"step attempt limit")
		if (step.maxAttempts or 1) > 1 then assert(step.untilTargets,"Repeated steps need target conditions") end
		if step.untilTargets then validateTargets(step.untilTargets) end
		for _,key in ipairs({"onSuccess","onFailure"}) do if step[key] then integer(step[key],1,#recipe.steps+1,"recipe route") end end
	end
	return copyTable(recipe)
end
local function priceKey(action) return action.method == "bench" and action.modId or action.method == "essence" and action.essenceId or action.method end

function M.validateState(model,state)
	assert(type(state) == "table" and type(state.affixes) == "table" and #state.affixes <= 6,"Invalid crafting state")
	assert(state.rarity == "NORMAL" or state.rarity == "MAGIC" or state.rarity == "RARE","Invalid state rarity")
	local groups,allowed,fractured={},{},{}
	for _,entry in ipairs(model.mods) do allowed[entry.id]=true end
	for _,entry in ipairs(model.bench) do allowed[entry.id]=true end
	for _,entry in ipairs(model.essences) do allowed[entry.modId]=true end
	for _,entry in ipairs(model.initial.affixes) do allowed[entry.id]=true; if entry.fractured then fractured[entry.id]=true end end
	for _,entry in ipairs(state.affixes) do
		local mod=assert(model.byId[entry.id],"Unknown state modifier")
		assert(allowed[entry.id],"State modifier is unavailable on this base")
		assert(not entry.fractured or fractured[entry.id],"This recipe cannot create fractured modifiers")
		assert((entry.id:match("^bench:") ~= nil) == (entry.crafted == true),"State crafted flag does not match its modifier")
		assert(entry.crafted == nil or type(entry.crafted) == "boolean","Invalid crafted flag")
		assert(entry.fractured == nil or type(entry.fractured) == "boolean","Invalid fractured flag")
		assert(mod.type == "Prefix" or mod.type == "Suffix","Unsupported state modifier type")
		assert(not groups[mod.group],"State has conflicting modifier groups"); groups[mod.group]=true
		local ranges=type(entry.range) == "table" and entry.range or {entry.range or 0.5}
		assert(#ranges >= 1 and #ranges <= 20,"Invalid modifier roll range count")
		for _,value in ipairs(ranges) do assert(type(value) == "number" and value == value and math.abs(value) <= 100,"Invalid modifier roll range") end
	end
	local c=counts(model,state)
	local cap=state.rarity == "MAGIC" and 1 or 3
	assert(c.Prefix <= cap and c.Suffix <= cap and (state.rarity ~= "NORMAL" or c.total == 0),"State exceeds rarity affix limits")
	return copyState(state)
end

function M.simulate(raw,recipe,options)
	options=options or { }
	recipe=M.validateRecipe(recipe)
	local trials=integer(options.trials or 200,1,2000,"trial count")
	local maxActions=integer(options.maxActions or 100,1,2000,"action budget")
	assert(trials*maxActions <= 20000,"Use at most 20000 total budgeted actions per simulation")
	local seed=integer(options.seed or 104729,1,2147483646,"seed")
	if options.prices then assert(type(options.currency) == "string" and options.currency:match("%S"),"Specify a common currency for supplied prices") end
	for key,value in pairs(options.prices or { }) do assert(type(key) == "string" and type(value) == "number" and value == value and value >= 0 and value <= 1e12,"Invalid currency price") end
	local model=M.model(raw)
	if options.initialState or recipe.initialState then model.initial=M.validateState(model,options.initialState or recipe.initialState) end
	local available={ }
	for _,entry in ipairs(model.mods) do available[entry.id]=true end
	for _,entry in ipairs(model.bench) do available[entry.id]=true end
	for _,entry in ipairs(model.essences) do available[entry.modId]=true end
	for _,entry in ipairs(model.initial.affixes) do available[entry.id]=true end
	local function checkTargets(targets) for _,group in ipairs(targets) do for _,id in ipairs(group.anyOf) do assert(available[id],"Target modifier ID is unavailable for this base: "..id) end end end
	checkTargets(recipe.targets)
	for _,step in ipairs(recipe.steps) do if step.untilTargets then checkTargets(step.untilTargets) end end
	local successes,totalCost,totalActions=0,0,0
	local spent,missing,errors,times={},{},{},{}
	local sample,sampleSuccess
	for trial=1,trials do
		local state=copyState(model.initial)
		local random=rng(encounter.seed(seed,trial,31))
		local at,actions,cost=1,0,0
		while at <= #recipe.steps and actions < maxActions and not M.matches(state,recipe.targets,recipe.rarity) do
			local step=recipe.steps[at]
			local success=false
			for _=1,(step.maxAttempts or 1) do
				if actions >= maxActions then break end
				actions=actions+1
				local ok,nextState=pcall(M.action,model,state,step,random)
				if not ok then local message=tostring(nextState):match("[^:]+$") or tostring(nextState); errors[message]=(errors[message] or 0)+1; break end
				state=nextState
				local key=priceKey(step); spent[key]=(spent[key] or 0)+1
				local price=options.prices and options.prices[key]
				if price then assert(type(price) == "number" and price >= 0 and price < math.huge,"Invalid currency price"); cost=cost+price else missing[key]=true end
				if not step.untilTargets or M.matches(state,step.untilTargets) then success=true; break end
			end
			at=success and (step.onSuccess or at+1) or (step.onFailure or at+1)
		end
		local hit=M.matches(state,recipe.targets,recipe.rarity)
		if hit then successes=successes+1; times[#times+1]=actions end
		if not sample or hit and not sampleSuccess then sample,sampleSuccess=state,hit end
		totalActions=totalActions+actions; totalCost=totalCost+cost
	end
	local low,high=encounter.wilson(successes,trials)
	assert(next(spent) or successes > 0,"Recipe could not execute a supported action; inspect its starting rarity and open affixes")
	local result={trials=trials,successes=successes,successChance=successes/trials*100,confidenceLow=low,confidenceHigh=high,seed=seed,maxActions=maxActions,
		meanActions=totalActions/trials,currencySpent=spent,unpriced=missing,transitionErrors=errors,limitations=copyTable(M.limits),sampleSuccess=sampleSuccess,sampleItem=M.toItem(model,sample).raw,sampleState=sample,
		engineVersion=1,sourceVersion=launch.versionNumber,treeVersion=latestTreeVersion,costCurrency=options.currency or "supplied price units"}
	if not next(missing) then result.meanCost=totalCost/trials; result.costPerSuccess=successes > 0 and totalCost/successes or nil end
	return result
end

function M.perform(raw,action,seed,initialState)
	local model=M.model(raw)
	if initialState then model.initial=M.validateState(model,initialState) end
	local state=M.action(model,model.initial,action,rng(encounter.seed(integer(seed or 104729,1,2147483646,"seed"),1,31)))
	return {itemText=M.toItem(model,state).raw,state=state,limitations=copyTable(M.limits)}
end

function M.catalog(raw,query,limit)
	local model=M.model(raw)
	query=(query or ""):lower(); limit=limit or 50
	local result={methods=copyTable(M.methods),modifiers={},bench={},essences={},limitations=copyTable(M.limits)}
	for _,entry in ipairs(model.mods) do if #result.modifiers < limit and (entry.id.." "..table.concat(entry.mod," / ")):lower():find(query,1,true) then result.modifiers[#result.modifiers+1]={id=entry.id,text=table.concat(entry.mod," / "),level=entry.mod.level,type=entry.mod.type,weight=entry.weight,group=entry.mod.group} end end
	for _,entry in ipairs(model.bench) do if #result.bench < limit and (entry.id.." "..table.concat(entry.mod," / ")):lower():find(query,1,true) then result.bench[#result.bench+1]={id=entry.id,text=table.concat(entry.mod," / "),type=entry.mod.type} end end
	for _,entry in ipairs(model.essences) do if #result.essences < limit and entry.name:lower():find(query,1,true) then result.essences[#result.essences+1]=copyTable(entry) end end
	return result
end
return M
