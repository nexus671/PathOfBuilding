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
	item.affixes=model.byId
	if M.decorateItem then M.decorateItem(model,state,item) end
	item.rarity=state.rarity; item.title=state.rarity == "RARE" and "Simulated craft" or nil
	item.name=item.title or item.baseName
	item.crafted=true; item.prefixes={}; item.suffixes={}; item.explicitModLines={}
	local caps=M.capacities(model,state)
	item.affixLimit=caps.Prefix+caps.Suffix
	item.prefixes.limit=caps.Prefix
	item.suffixes.limit=caps.Suffix
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
		item.requirements.level=math.max(item.requirements.level or 0,math.floor((mod.level or 0)*0.8))
		for _,line in ipairs(mod) do item.explicitModLines[#item.explicitModLines+1]={line=itemLib.applyRange(line,entry.range or 0.5),crafted=true,fractured=entry.fractured,prefix=mod.type == "Prefix",suffix=mod.type == "Suffix"} end
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
	assert(not item.foulborn,"Foulborn items need a separate modifier-mutation model")
	local equipment={Helmet=true,["Body Armour"]=true,Gloves=true,Boots=true,Shield=true,Quiver=true,Amulet=true,Ring=true,Belt=true}
	assert(equipment[item.type] or item.type == "Jewel" or item.type == "Flask" or item.type == "Tincture" or data.weaponTypeInfo[item.type],"This engine currently supports ordinary equipment; this item type is unsupported")
	if item.fractured then for _,info in ipairs(itemLib.influenceInfo.all) do assert(not item[info.key],"Fractured and influenced combinations are unsupported") end end
	local model={raw=item.raw,item=item,byId={},mods={},bench={},essences={}}
	local extraTags={}
	if item.clusterJewel and item.clusterJewel.skills[item.clusterJewelSkill] then extraTags[item.clusterJewel.skills[item.clusterJewelSkill].tag]=true end
	for id,mod in pairs(item.affixes or { }) do model.byId[id]=mod end
	for id,mod in pairs((item.type == "Jewel" or item.type == "Flask" or item.type == "Tincture") and item.affixes or data.itemMods.Explicit) do
		if (mod.type == "Prefix" or mod.type == "Suffix") and mod.level <= item.itemLevel and not mod.affix:find("Elevated",1,true) then
			local weight=item:GetModSpawnWeight(mod,extraTags)
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
	local reconstructed=M.toItem(model,state)
	if renderLines(reconstructed) ~= renderLines(item) then
		state=require("Modules.CraftingImport").resolve(M,model,state)
		reconstructed=M.toItem(model,state)
	end
	local c=counts(model,state)
	for _,entry in ipairs(state.affixes) do if entry.fractured then for _,info in ipairs(itemLib.influenceInfo.all) do assert(not item[info.key],"Fractured and influenced combinations are unsupported") end end end
	local caps=M.capacities(model,state)
	assert(c.Prefix <= caps.Prefix and c.Suffix <= caps.Suffix,"Starting item exceeds affix limits")
	assert(renderLines(reconstructed) == renderLines(item),"Starting modifiers could not be resolved exactly. Use a blank base or advanced item text with recognized modifier IDs.")
	model.initial=state
	return model
end

function M.pool(model,state)
	local c,f=counts(model,state),flags(model,state)
	for key,value in pairs(state.rollBlock or { }) do f[key]=value end
	local caps=M.capacities(model,state)
	local result,total={},0
	for _,entry in ipairs(model.mods) do
		local mod=entry.mod
		local blocked=c[mod.type] >= caps[mod.type] or c.groups[mod.group]
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
		if pick < 0 then state.affixes[#state.affixes+1]={id=entry.id,range=M.rollRange(model.byId[entry.id],random)}; return end
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
		target=math.min(target,M.capacities(model,state).total)
		while #state.affixes < target do add(model,state,random) end
	elseif method == "augmentation" or method == "regal" or method == "exalt" then
		assert(state.rarity == (method == "exalt" and "RARE" or "MAGIC"),"This currency cannot be used on the current rarity")
		assert(c.total < (method == "augmentation" and 2 or M.capacities(model,{rarity="RARE"}).total),"The item has no open affix")
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
		for _,entry in ipairs(state.affixes) do if not protected(entry,model.byId[entry.id],f) then entry.range=M.rollRange(model.byId[entry.id],random) end end
	elseif method == "bench" then
		local mod=assert(model.byId[action.modId],"Unknown bench modifier")
		assert(action.modId:match("^bench:"),"Select a bench modifier")
		assert(c.crafted < (f.multipleCrafts and 3 or 1),"Crafted modifier limit reached")
		assert(not c.groups[mod.group],"A modifier from this group is already present")
		assert(c[mod.type] < M.capacities(model,state)[mod.type],"No open affix for this bench craft")
		if state.rarity == "NORMAL" then state.rarity="MAGIC" end
		state.affixes[#state.affixes+1]={id=action.modId,range=M.rollRange(mod,random),crafted=true}
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
		state.affixes[#state.affixes+1]={id=selected.modId,range=M.rollRange(mod,random)}
		local value=random(); local target=value < 8/12 and 4 or value < 11/12 and 5 or 6
		target=math.min(target,M.capacities(model,state).total)
		while #state.affixes < target do add(model,state,random) end
	else error("Unsupported crafting action: "..tostring(method)) end
	state.rollBlock=nil
	return state
end

function M.matches(state,targets,rarity,model,requirements,requiredGroups)
 if state.veil or state.destroyed then return false end
 if rarity and state.rarity ~= rarity then return false end
 local matched=0
 for _,group in ipairs(targets) do
  local count=0
  for _,entry in ipairs(group.scope == "implicit" and (state.corruptedImplicits or state.implicits or {}) or state.affixes) do
   local roll=type(entry.range) == "table" and math.min(unpack(entry.range)) or entry.range or 0.5
   for _,id in ipairs(group.anyOf) do if entry.id == id and roll >= (group.minRoll or 0) and (group.fractured == nil or (entry.fractured or false) == group.fractured) and (group.crafted == nil or (entry.crafted or false) == group.crafted) then count=count+1; break end end
  end
  local hit=count >= (group.atLeast or 1)
  if group.negate then hit=not hit end
  if hit then matched=matched+1 end
 end
 if matched < (requiredGroups or #targets) then return false end
 if requirements then
  assert(model,"A native item model is required for property conditions")
  local c=counts(model,state); local caps=M.capacities(model,state)
  local prefix=c.Prefix+(state.veil and state.veil.type == "Prefix" and 1 or 0)
  local suffix=c.Suffix+(state.veil and state.veil.type == "Suffix" and 1 or 0)
  if requirements.openPrefixes and caps.Prefix-prefix < requirements.openPrefixes then return false end
  if requirements.openSuffixes and caps.Suffix-suffix < requirements.openSuffixes then return false end
  if requirements.minAffixes and c.total < requirements.minAffixes or requirements.maxAffixes and c.total > requirements.maxAffixes then return false end
  local fractures=0;for _,entry in ipairs(state.affixes) do if entry.fractured then fractures=fractures+1 end end
  if requirements.minFractured and fractures < requirements.minFractured or requirements.maxFractured and fractures > requirements.maxFractured then return false end
  if requirements.minIntangibility and (state.intangibility or 0) < requirements.minIntangibility or requirements.maxIntangibility and (state.intangibility or 0) > requirements.maxIntangibility then return false end
  if requirements.minQuality and (state.quality or model.item.quality or 0) < requirements.minQuality then return false end
  if requirements.minMemoryStrands and (state.memoryStrands or 0) < requirements.minMemoryStrands then return false end
  if requirements.maxMemoryStrands and (state.memoryStrands or 0) > requirements.maxMemoryStrands then return false end
  if requirements.corrupted ~= nil and (state.corrupted or false) ~= requirements.corrupted then return false end
  if requirements.sockets and #(state.sockets or model.item.sockets or {}) < requirements.sockets then return false end
  if requirements.links then
   local groups={}; local best=0
   for _,socket in ipairs(state.sockets or model.item.sockets or {}) do groups[socket.group]=(groups[socket.group] or 0)+1;best=math.max(best,groups[socket.group]) end
   if best < requirements.links then return false end
  end
 end
 return true
end
function M.validateRecipe(recipe)
	assert(type(recipe) == "table" and type(recipe.steps) == "table" and #recipe.steps >= 1 and #recipe.steps <= 20,"Use one to twenty recipe steps")
	assert(type(recipe.targets) == "table" and #recipe.targets <= 6,"Choose up to six target groups")
	assert(#recipe.targets > 0 or recipe.requirements,"Choose targets or item property conditions")
	assert(not recipe.rarity or recipe.rarity == "MAGIC" or recipe.rarity == "RARE","Invalid target rarity")
	local methods={ }
	for _,method in ipairs(M.methods) do methods[method]=true end
	local function validateRequirements(requirements)
		if not requirements then return end
		assert(type(requirements) == "table" and next(requirements),"Choose at least one property condition")
		local limits={openPrefixes=3,openSuffixes=3,minAffixes=6,maxAffixes=6,minQuality=30,sockets=6,links=6,minMemoryStrands=100,maxMemoryStrands=100,minFractured=6,maxFractured=6,minIntangibility=100,maxIntangibility=100}
		for key,value in pairs(requirements) do if key == "corrupted" then assert(type(value) == "boolean","Invalid corruption condition") else integer(value,0,assert(limits[key],"Unknown property condition"),key) end end
		for _,pair in ipairs({{"minAffixes","maxAffixes"},{"minMemoryStrands","maxMemoryStrands"},{"minFractured","maxFractured"},{"minIntangibility","maxIntangibility"}}) do
			assert(not requirements[pair[1]] or not requirements[pair[2]] or requirements[pair[1]] <= requirements[pair[2]],"Minimum property condition exceeds maximum")
		end
	end
	validateRequirements(recipe.requirements)
	if recipe.requiredGroups then integer(recipe.requiredGroups,0,#recipe.targets,"required target groups") end
	local function validateTargets(targets)
	assert(type(targets) == "table" and #targets >= 1 and #targets <= 6,"Choose one to six target groups")
	for _,group in ipairs(targets) do
		assert(type(group.anyOf) == "table" and #group.anyOf >= 1 and #group.anyOf <= 30,"Use one to thirty modifier IDs per target group")
		for _,id in ipairs(group.anyOf) do assert(type(id) == "string" and #id <= 160,"Invalid target modifier ID") end
		if group.atLeast then integer(group.atLeast,1,6,"matching modifiers") end
		if group.minRoll then assert(type(group.minRoll) == "number" and group.minRoll >= 0 and group.minRoll <= 1,"Invalid minimum roll") end
		assert(not group.scope or group.scope == "explicit" or group.scope == "implicit","Invalid target scope")
		for _,key in ipairs({"fractured","crafted"}) do assert(group[key] == nil or type(group[key]) == "boolean","Invalid modifier condition") end
		assert(group.negate == nil or type(group.negate) == "boolean","Invalid exclusion condition")
	end
	end
	if #recipe.targets > 0 then validateTargets(recipe.targets) end
	for _,step in ipairs(recipe.steps) do
		assert(methods[step.method],"Unsupported crafting action: "..tostring(step.method))
		assert(step.onFailureAction==nil or ({route=true,stop=true,restart=true,salvage=true})[step.onFailureAction],"Unknown failure recovery action")
		assert(step.recoveryNotes==nil or type(step.recoveryNotes)=="string" and #step.recoveryNotes<=1000,"Recovery notes are too long")
		integer(step.maxAttempts or 1,1,200,"step attempt limit")
		if (step.maxAttempts or 1) > 1 then assert(step.untilTargets or step.untilRequirements,"Repeated steps need target or property conditions") end
		if step.untilTargets then validateTargets(step.untilTargets) end
		validateRequirements(step.untilRequirements)
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
	local caps=M.capacities(model,state)
	assert(c.Prefix <= caps.Prefix and c.Suffix <= caps.Suffix and (state.rarity ~= "NORMAL" or c.total == 0),"State exceeds rarity affix limits")
	return copyState(state)
end

function M.simulate(raw,recipe,options)
	options=options or { }
	recipe=M.validateRecipe(recipe)
	local trials=integer(options.trials or 200,1,2000,"trial count")
	local baseCost=options.baseCost or 0
	assert(type(baseCost) == "number" and baseCost == baseCost and baseCost >= 0 and baseCost <= 1e12,"Invalid starting item cost")
	assert(baseCost == 0 or type(options.currency) == "string" and #options.currency > 0,"Name the currency for the starting item cost")
	local retain=integer(options.retainSuccesses or 0,0,100,"retained successful items")
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
	for id in pairs(model.special or {}) do available[id]=true end
	for _,step in ipairs(recipe.steps) do if (step.method == "recombine" or step.method == "recombine_predictable") and step.donorItem then
		local donor=M.model(step.donorItem)
		for _,entry in ipairs(donor.mods) do available[entry.id]=true end
		for _,entry in ipairs(donor.initial.affixes) do available[entry.id]=true end
	end end
	local function checkTargets(targets) for _,group in ipairs(targets) do for _,id in ipairs(group.anyOf) do assert(available[id],"Target modifier ID is unavailable for this base: "..id) end end end
	checkTargets(recipe.targets)
	for _,step in ipairs(recipe.steps) do
		if step.untilTargets then checkTargets(step.untilTargets) end
		if step.method == "ducat_kishara" and not step.allflame then step.allflame={auto=true,upgradeTier=2} end
		if step.allflame and not step.allflame.preferredTargets and #recipe.targets > 0 then step.allflame.preferredTargets=copyTable(step.untilTargets or recipe.targets) end
	end
	local successes,totalCost,totalActions,totalExecuted=0,0,0,0
	local spent,missing,errors,times={},{},{},{}
	local actionHistogram,costSamples,successfulCosts,routes={},{},{},{}
	local budgetExhausted,destroyedTrials=0,0
	local recovery={restarts=0,stopped=0,salvaged=0}
	local sample,sampleSuccess
	local retained,affixDistribution,propertyDistribution={},{},{affixes={},fractured={},intangibility={},memoryStrands={}}
	for trial=1,trials do
		if options.checkpoint then options.checkpoint({trial=trial,trials=trials,successes=successes}) end
		local state=copyState(model.initial)
		local random=rng(encounter.seed(seed,trial,31))
		local at,actions,cost=1,0,baseCost
		while at <= #recipe.steps and actions < maxActions and not state.destroyed and (options.forceFirstAction and actions == 0 or not M.matches(state,recipe.targets,recipe.rarity,model,recipe.requirements,recipe.requiredGroups)) do
			local step=recipe.steps[at]
			local route=routes[at] or {visits=0,success=0,failure=0,executed=0};routes[at]=route;route.visits=route.visits+1
			local success=false
			for _=1,(step.maxAttempts or 1) do
				if actions >= maxActions then break end
				if options.checkpoint then options.checkpoint({trial=trial,trials=trials,actions=actions,successes=successes}) end
				actions=actions+1
				local ok,nextState=pcall(M.action,model,state,step,random)
				if not ok then local message=tostring(nextState):match("[^:]+$") or tostring(nextState); errors[message]=(errors[message] or 0)+1; break end
				state=nextState
				route.executed=route.executed+1
				totalExecuted=totalExecuted+1
				local setupKey=(M.priceKey or priceKey)(step)
				local components=options.prices and options.prices[setupKey] ~= nil and {[setupKey]=1} or M.components and M.components(step,state,model) or {[setupKey]=1}
				for key,amount in pairs(components) do
					spent[key]=(spent[key] or 0)+amount
					local price=options.prices and options.prices[key]
					if price then cost=cost+price*amount else missing[key]=true end
				end
				if state.destroyed then break end
				if M.matches(state,recipe.targets,recipe.rarity,model,recipe.requirements,recipe.requiredGroups) then success=true;break end
				if not (step.untilTargets or step.untilRequirements) or M.matches(state,step.untilTargets or {},nil,model,step.untilRequirements) then success=true; break end
			end
			route[success and "success" or "failure"]=route[success and "success" or "failure"]+1
			if not success and step.onFailureAction=="restart" then
				if actions<maxActions then recovery.restarts=recovery.restarts+1;state=copyState(model.initial);cost=cost+baseCost end;at=1
			elseif not success and (step.onFailureAction=="stop" or step.onFailureAction=="salvage") then
				local key=step.onFailureAction=="stop" and "stopped" or "salvaged";recovery[key]=recovery[key]+1;at=#recipe.steps+1
			else at=success and (step.onSuccess or at+1) or (step.onFailure or at+1) end
		end
		local hit=M.matches(state,recipe.targets,recipe.rarity,model,recipe.requirements,recipe.requiredGroups)
		if hit then successes=successes+1; times[#times+1]=actions end
		if hit and #retained < retain then retained[#retained+1]={trial=trial,actions=actions,cost=not next(missing) and cost or nil,state=copyTable(state),itemText=M.toItem(model,state).raw} end
		local fractures=0
		for _,entry in ipairs(state.affixes) do
			local bucket=affixDistribution[entry.id] or {trials=0,successes=0,fractured=0,crafted=0};affixDistribution[entry.id]=bucket
			bucket.trials=bucket.trials+1;if hit then bucket.successes=bucket.successes+1 end
			if entry.fractured then bucket.fractured=bucket.fractured+1;fractures=fractures+1 end
			if entry.crafted then bucket.crafted=bucket.crafted+1 end
		end
		if not state.destroyed then
			for key,value in pairs({affixes=#state.affixes,fractured=fractures,intangibility=state.intangibility or 0,memoryStrands=state.memoryStrands or 0}) do
				local histogram=propertyDistribution[key];histogram[value]=(histogram[value] or 0)+1
			end
		end
		if state.destroyed then destroyedTrials=destroyedTrials+1 end
		if not hit and not state.destroyed and at <= #recipe.steps and actions >= maxActions then budgetExhausted=budgetExhausted+1 end
		local bucket=actionHistogram[actions] or {actions=actions,trials=0,successes=0};actionHistogram[actions]=bucket;bucket.trials=bucket.trials+1;if hit then bucket.successes=bucket.successes+1 end
		costSamples[#costSamples+1]=cost;if hit then successfulCosts[#successfulCosts+1]=cost end
		if not sample or hit and not sampleSuccess then sample,sampleSuccess=state,hit end
		totalActions=totalActions+actions; totalCost=totalCost+cost
	end
	local low,high=encounter.wilson(successes,trials)
	local function quantiles(values)
		if #values == 0 then return nil end
		table.sort(values)
		local result={};for _,percent in ipairs({10,25,50,75,90,95,99}) do result["p"..percent]=values[math.max(1,math.ceil(#values*percent/100))] end
		return result
	end
	local distribution={};for _,bucket in pairs(actionHistogram) do distribution[#distribution+1]=bucket end;table.sort(distribution,function(a,b) return a.actions < b.actions end)
	assert(totalExecuted > 0 or successes > 0,"Recipe could not execute a supported action; inspect its starting rarity and open affixes")
	local result={trials=trials,successes=successes,successChance=successes/trials*100,confidenceLow=low,confidenceHigh=high,seed=seed,maxActions=maxActions,
		meanActions=totalActions/trials,currencySpent=spent,unpriced=missing,transitionErrors=errors,limitations=copyTable(M.limits),sampleSuccess=sampleSuccess,sampleItem=not sample.destroyed and not sample.veil and M.toItem(model,sample).raw or nil,sampleState=sample,
		engineVersion=2,dataPatch=M.dataPatch,sourceVersion=launch.versionNumber,treeVersion=latestTreeVersion,costCurrency=options.currency or "supplied price units",
		baseCost=baseCost,retainedSuccesses=retained,retentionLimit=retain,affixDistribution=affixDistribution,propertyDistribution=propertyDistribution,actionDistribution=distribution,successfulActionQuantiles=quantiles(times),routeCounts=routes,budgetExhausted=budgetExhausted,destroyedTrials=destroyedTrials}
	if not next(missing) then result.meanCost=totalCost/trials; result.costPerSuccess=successes > 0 and totalCost/successes or nil;result.spendingQuantiles=quantiles(costSamples);result.successfulSpendingQuantiles=quantiles(successfulCosts) end
	result.recovery=recovery
	return result
end

function M.perform(raw,action,seed,initialState)
	local model=M.model(raw)
	if initialState then model.initial=M.validateState(model,initialState) end
	local state,details=M.action(model,model.initial,action,rng(encounter.seed(integer(seed or 104729,1,2147483646,"seed"),1,31)))
	return {itemText=not state.veil and not state.destroyed and M.toItem(model,state).raw or nil,state=state,choices=details and details.choices,allflame=details and details.allflame,dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
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
M.rollRange=rollRange
function M.capacities(model,state)
 local prefix,suffix=3,3
 if model.item.type == "Jewel" then prefix,suffix=2,2 end
 if model.item.type == "Jewel" and model.item.base.subType == "Abyss" and state.corrupted then prefix,suffix=3,3 end
 if model.item.type == "Flask" or model.item.type == "Tincture" then prefix,suffix=1,1 end
 if state.rarity == "MAGIC" then prefix,suffix=1,1 end
 for _,line in ipairs(model.item.implicitModLines or {}) do
  local value=tonumber(line.line:match("(%d+) additional Prefix"));if value then prefix=prefix+value end
  value=tonumber(line.line:match("(%d+) fewer Prefix"));if value then prefix=prefix-value end
  value=tonumber(line.line:match("(%d+) additional Suffix"));if value then suffix=suffix+value end
  value=tonumber(line.line:match("(%d+) fewer Suffix"));if value then suffix=suffix-value end
 end
 prefix,suffix=math.max(0,prefix),math.max(0,suffix)
 return {Prefix=prefix,Suffix=suffix,total=prefix+suffix}
end
require("Modules.CraftingAdvanced").extend(M,{counts=counts,flags=flags,clear=clear,protected=protected,add=add,integer=integer,priceKey=priceKey})
require("Modules.CraftingCalculator").extend(M)
return M
