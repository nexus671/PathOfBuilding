-- Apply client-verified Abyss weights only to this crafting model. Shared PoB
-- item data remains unchanged, and legacy modifiers can still be imported.
local M={}
local cached
local updated=setmetatable({},{__mode="k"})
local function weights()
	if not cached then
		local root=GetScriptPath();local f=assert(io.open((root~="" and root.."/" or "").."Data/Crafting/3.30-abyss-weights.json","rb"))
		local raw=f:read("*a");f:close();local data=assert(require("dkjson").decode(raw))
		assert(data.schemaVersion==1 and data.clientVersion=="3.30.0.1.4","Invalid 3.30 Abyss weights");cached=data.weights
	end
	return cached
end
function M.prepare(item)
	local legacy={}
	if item.type~="Jewel" or item.base.subType~="Abyss" then return legacy end
	local original=item.affixes;local copy={};for id,mod in pairs(original) do copy[id]=mod end;item.affixes=copy
	for id,entries in pairs(weights()) do
		local old=original[id]
		if old then
			local before=item:GetModSpawnWeight(old);local mod=updated[old]
			if not mod then
				mod={};for key,value in pairs(old) do mod[key]=value end;mod.weightKey={};mod.weightVal={}
				for _,entry in ipairs(entries) do mod.weightKey[#mod.weightKey+1]=entry.tag;mod.weightVal[#mod.weightVal+1]=entry.weight end
				updated[old]=mod
			end
			copy[id]=mod
			if before>0 and item:GetModSpawnWeight(mod)==0 then legacy[id]=true end
		end
	end
	return legacy
end
return M
