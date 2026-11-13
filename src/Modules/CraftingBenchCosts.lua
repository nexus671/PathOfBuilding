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
function B.index(data)
	local result={}
	for _,service in ipairs(data.bench) do
		local id=service.actions.add_explicit_mod
		local mod=id and (data.benchMods or {})[id]
		if mod and (mod.generation_type=="prefix" or mod.generation_type=="suffix") then
			for _,class in ipairs(service.item_classes) do
				local key=signature(mod.text,mod.required_level,mod.generation_type,class)
				local entry=result[key]
				if not entry then result[key]={cost=service.cost,sources={[id]=true}}
				else
					entry.sources[id]=true
					if not equalCosts(entry.cost,service.cost) then entry.ambiguous=true end
				end
			end
		end
	end
	return result
end
function B.class(item)
	local subtype=item.base.subType
	if subtype=="Warstaff" or subtype=="Rune Dagger" then return subtype end
	local class=item.type:gsub("One Handed","One Hand"):gsub("Two Handed","Two Hand")
	return class
end
function B.cost(model,id,lookup)
	local mod=model.byId[id]
	if not mod or not id:match("^bench:") then return end
	if not lookup then
		if not index then index=B.index(require("Modules.CraftingAdvanced").data()) end
		lookup=index
	end
	local entry=lookup[signature(table.concat(mod,"\n"),mod.level,mod.type,B.class(model.item))]
	if not entry or entry.ambiguous then return end
	local sources={};for source in pairs(entry.sources) do sources[#sources+1]=source end;table.sort(sources)
	return copyTable(entry.cost),sources
end
return B
