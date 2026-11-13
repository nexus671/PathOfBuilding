-- Deterministic Harvest services; replacing an enchant never changes affix rolls.
local E={}
local catalog
function E.data()
	if not catalog then
		local root=GetScriptPath();local file=assert(io.open((root~="" and root.."/" or "").."Data/Crafting/HarvestEnchants.json","rb"))
		local raw=file:read("*a");file:close();catalog=assert(require("dkjson").decode(raw))
	end
	return catalog
end
function E.eligible(model,id)
	local data=E.data();local craft=data.crafts[id];if not craft then return false end
	local class=data.baseClasses[model.item.baseName]
	for _,allowed in ipairs(craft.classes) do if class==allowed then return true end end
	return false
end
function E.label(id)
	local craft=assert(E.data().crafts[id],"Unknown Harvest enchantment")
	local name=id:gsub("BodyEnchant$",""):gsub("^Weapon",""):gsub("Enchant$",""):gsub("(%l)(%u)","%1 %2")
	return name.." | "..craft.cost.." "..({"Wild","Vivid","Primal"})[craft.lifeforceType]
end
function E.extend(M,A,api)
	M.methods[#M.methods+1]="harvest_enchant";M.labels.harvest_enchant="Harvest: replace quality enchantment";table.sort(M.methods)
	local action,options,decorate,validate,price,components=M.action,M.actionOptions,M.decorateItem,M.validateState,M.priceKey,M.components
	local originalCatalog=M.catalog
	function M.catalog(raw,query,limit,initialState)
		local result=originalCatalog(raw,query,limit,initialState)
		local state=result.initialState;local model={item=new("Item"):Item(state and state.baseItem or raw)}
		result.harvestEnchants={};local search=(query or ""):lower()
		for id,craft in pairs(E.data().crafts) do
			if E.eligible(model,id) and (id.." "..E.label(id).." "..table.concat(craft.lines," ")):lower():find(search,1,true) then
				result.harvestEnchants[#result.harvestEnchants+1]={id=id,label=E.label(id),lines=copyTable(craft.lines),action={method="harvest_enchant",enchantId=id},components=M.components({method="harvest_enchant",enchantId=id})}
			end
		end
		table.sort(result.harvestEnchants,function(a,b) return a.id<b.id end)
		for i=#result.harvestEnchants,1,-1 do if i>(limit or 50) then result.harvestEnchants[i]=nil else break end end
		return result
	end
	local originalModel=M.model
	function M.model(raw)
		local model=originalModel(raw);local lines={}
		for _,line in ipairs(model.item.enchantModLines) do lines[#lines+1]=StripEscapes(itemLib.formatModLine(line,false) or line.line) end
		local imported=table.concat(lines,"\n")
		if imported~="" then for id,craft in pairs(E.data().crafts) do
			if E.eligible(model,id) and imported==table.concat(craft.lines,"\n") then model.initial.harvestEnchant=id;break end
		end end
		return model
	end
	function M.action(model,state,craft,random)
		if craft.method~="harvest_enchant" then return action(model,state,craft,random) end
		assert(not state.destroyed and not state.corrupted and not state.mirrored and not state.veil,"Harvest enchanting requires an uncorrupted, usable item without a pending unveil")
		assert(E.eligible(model,craft.enchantId),"Choose a Harvest enchantment available for this base")
		local next=copyTable(state);next.harvestEnchant=craft.enchantId;return next
	end
	function M.actionOptions(model,state,method)
		if method~="harvest_enchant" then return options(model,state,method) end
		local result={}
		for id,craft in pairs(E.data().crafts) do if E.eligible(model,id) then
			result[#result+1]={label=E.label(id),action={method=method,enchantId=id}}
		end end
		table.sort(result,function(a,b) return a.label<b.label end);return result
	end
	function M.decorateItem(model,state,item)
		decorate(model,state,item)
		if state.harvestEnchant then
			item.enchantModLines={}
			for _,line in ipairs(assert(E.data().crafts[state.harvestEnchant],"Unknown Harvest enchantment").lines) do item.enchantModLines[#item.enchantModLines+1]={line=line,enchant=true} end
		end
	end
	function M.validateState(model,state)
		if state.harvestEnchant then assert(E.eligible(model,state.harvestEnchant),"Invalid Harvest enchantment for this base") end
		local result=validate(model,state)
		-- Older structured states inherit enchantments from their starting text.
		if result.harvestEnchant==nil then result.harvestEnchant=model.initial.harvestEnchant end
		return result
	end
	function M.priceKey(craft) if craft.method=="harvest_enchant" then return "harvest_enchant:"..tostring(craft.enchantId) end;return price(craft) end
	function M.components(craft,state,model)
		if craft.method=="harvest_enchant" then
			local entry=assert(E.data().crafts[craft.enchantId],"Choose a known Harvest enchantment")
			return {[({"wild_lifeforce","vivid_lifeforce","primal_lifeforce"})[entry.lifeforceType]]=entry.cost}
		end
		return components(craft,state,model)
	end
	M.limits[#M.limits+1]="Harvest quality enchantments are deterministic services from pinned client data. They replace existing enchantments and preserve affixes, sockets and quality. Lifeforce costs use supplied resource prices."
end
return E
