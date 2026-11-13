-- Match native bench effects to pinned services, never to their changing row index.
local B={}
local index
local function normalise(text)
	return text:gsub("%((%-?%d+%.?%d*)%-(%-?%d+%.?%d*)%)",function(a,b)
		if tonumber(a)>tonumber(b) then a,b=b,a end
		return "("..a.."-"..b..")"
	end)
end
local function signature(text,level,kind,class)
	return normalise(text).."\0"..tostring(level).."\0"..kind:lower().."\0"..class
end
local function equalCosts(a,b)
	for key,value in pairs(a) do if b[key]~=value then return false end end
	for key,value in pairs(b) do if a[key]~=value then return false end end
	return true
end
local function serviceKey(operation,value,class)
	return "service\0"..operation.."\0"..tostring(value).."\0"..class
end
function B.index(data)
	local result={}
	local function add(key,cost,id)
		-- GGG 3.30 replaces Chance with the same number of Alterations for
		-- every bench option. Keep the pinned modifier data unchanged.
		local chance="Metadata/Items/Currency/CurrencyUpgradeRandomly"
		local alteration="Metadata/Items/Currency/CurrencyRerollMagic"
		local updated=cost[chance]~=nil
		if updated then cost=copyTable(cost);cost[alteration]=(cost[alteration] or 0)+cost[chance];cost[chance]=nil end
		local entry=result[key]
		if not entry then result[key]={cost=cost,sources={[id]=true}}
		else entry.sources[id]=true;if not equalCosts(entry.cost,cost) then entry.ambiguous=true end end
		if updated then result[key].sources["GGG 3.30 patch notes"]=true end
	end
	for _,service in ipairs(data.bench) do
		local id=service.actions.add_explicit_mod
		local mod=id and (data.benchMods or {})[id]
		if mod and (mod.generation_type=="prefix" or mod.generation_type=="suffix") then
			for _,class in ipairs(service.item_classes) do
				local key=signature(mod.text,mod.required_level,mod.generation_type,class)
				add(key,service.cost,id)
			end
		end
		for _,operation in ipairs({"remove_crafted_mods","reroll_rare_mods"}) do
			local value=service.actions[operation]
			if value then for _,class in ipairs(service.item_classes) do
				add(serviceKey(operation,value,class),service.cost,operation..":"..tostring(value))
			end end
		end
	end
	return result
end
function B.class(item)
	local subtype=item.base.subType
	if subtype=="Warstaff" or subtype=="Rune Dagger" then return subtype end
	if item.type=="Jewel" and subtype=="Abyss" then return "AbyssJewel" end
	if item.type=="Fishing Rod" then return "FishingRod" end
	local class=item.type:gsub("One Handed","One Hand"):gsub("Two Handed","Two Hand")
	return class
end
local function lookupEntry(key,lookup)
	if not lookup then
		if not index then index=B.index(require("Modules.CraftingAdvanced").data()) end
		lookup=index
	end
	local entry=lookup[key]
	if not entry or entry.ambiguous then return end
	local sources={};for source in pairs(entry.sources) do sources[#sources+1]=source end;table.sort(sources)
	return copyTable(entry.cost),sources
end
function B.service(model,action)
	local operation,value
	if action.method=="remove_crafted" then operation,value="remove_crafted_mods",true
	elseif action.method=="bench_reroll" then operation,value="reroll_rare_mods",action.count
	else return end
	return lookupEntry(serviceKey(operation,value,B.class(model.item)))
end
function B.cost(model,id,lookup)
	local mod=model.byId[id]
	if not mod or not id:match("^bench:") then return end
	local cost,sources=lookupEntry(signature(table.concat(mod,"\n"),mod.level,mod.type,B.class(model.item)),lookup)
	if not cost then return end
	if not lookup and #mod==1 and (mod[1]=="Prefixes Cannot Be Changed" or mod[1]=="Suffixes Cannot Be Changed") then
		local item=model.item;local kind=item.type;local extra,amount
		if data.weaponTypeInfo[kind] then extra,amount="CurrencyRerollDefences",1
		elseif item.base.armour or kind=="Quiver" then extra,amount="CurrencyRerollImplicit",4
		elseif kind=="Ring" or kind=="Amulet" or kind=="Belt" then extra,amount="CurrencyAddModToRare",8 end
		-- Unknown classes must not inherit the old, cheaper 3.29 price.
		if not extra then return end
		return {["Metadata/Items/Currency/CurrencyModValues"]=4,["Metadata/Items/Currency/"..extra]=amount},{"GGG 3.30 patch notes"}
	end
	return cost,sources
end
return B
