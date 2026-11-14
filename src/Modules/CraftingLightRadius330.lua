-- 3.30 client values for Light Radius / Accuracy modifiers. Keep the native
-- 3.29 descriptions for existing items while new rolls use these ranges.
local M={ranges={LightRadiusAndAccuracy1="10-15",LightRadiusAndAccuracy2="16-20",LightRadiusAndAccuracy3="21-30",
	LightRadiusAndAccuracyNew1="10-15",LightRadiusAndAccuracyNew2="16-20",
	LocalLightRadiusAndAccuracy1="10-15",LocalLightRadiusAndAccuracy2="16-20",LocalLightRadiusAndAccuracy3="10-15",
	LocalLightRadiusAndAccuracyNew1_="16-20",LocalLightRadiusAndAccuracyNew2="21-30"}}

function M.prepare(model)
	model.legacyLightRadius={}
	for id,range in pairs(M.ranges) do
		local old=model.byId[id]
		if old then
			local current=copyTable(old);local changed=0
			for index,line in ipairs(current) do
				local replacement,count=line:gsub("^%d+%% increased Light Radius$","("..range..")%% increased Light Radius")
				current[index]=replacement;changed=changed+count
			end
			assert(changed==1,"Unexpected Light Radius modifier data: "..id)
			if current.tradeHashes and current.tradeHashes[1263695895] then current.tradeHashes[1263695895]={"("..range..")% increased Light Radius"} end
			model.legacyLightRadius[id]=old;model.byId[id]=current
		end
	end
	for _,entry in ipairs(model.mods) do if model.legacyLightRadius[entry.id] then entry.mod=model.byId[entry.id] end end
end
return M
