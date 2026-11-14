-- Export-time appearance changes. Conditions, actions and source files stay intact.
local parser=require("Modules.LootFilterParser")
local M={}
function M.apply(raw,settings)
	if not settings or not next(settings) then return raw end
	settings=require("Modules.LootFilterAppearanceSettings").validate(settings)
	local output={};local block=false
	for line in (raw.."\n"):gmatch("([^\n]*)\n") do
		local ok,tokens=pcall(parser.tokens,line);local key=ok and tokens[1]
		if key=="Show" or key=="Hide" or key=="Minimal" or key=="Import" then
			block=key~="Import"
		elseif block and key=="SetFontSize" and settings.minimumFontSize and #tokens==2 and tonumber(tokens[2]) and tonumber(tokens[2])>=1 and tonumber(tokens[2])<=45 and tonumber(tokens[2])==math.floor(tonumber(tokens[2])) then
			-- Do not inject a size into blocks that inherit styling through Continue.
			line="    SetFontSize "..math.max(tonumber(tokens[2]),settings.minimumFontSize)
		elseif block and (settings.alertVolume~=nil or settings.alertId) and (key=="PlayAlertSound" or key=="PlayAlertSoundPositional" or key=="CustomAlertSound" or key=="CustomAlertSoundOptional") and tokens[2] then
			if tokens[2]~="None" then
				local custom=key:find("Custom",1,true);local sound=custom and '"'..tokens[2]..'"' or tokens[2]
				local target=settings.alertId and (key=="PlayAlertSoundPositional" and key or "PlayAlertSound") or key
				local volume=settings.alertVolume~=nil and settings.alertVolume or tokens[3]
				if volume==nil and custom and target~=key then volume=100 end
				line="    "..target.." "..(settings.alertId or sound)..(volume~=nil and " "..volume or "")
			end
		elseif block and key=="PlayEffect" then
			if settings.disableEffects then line="    PlayEffect None" elseif settings.effectColor and tokens[2] and tokens[2]~="None" then line="    PlayEffect "..settings.effectColor..(tokens[3]=="Temp" and " Temp" or "") end
		elseif block and key=="MinimapIcon" and settings.disableIcons then line="    MinimapIcon -1"
		elseif block then
			local color=({SetTextColor=settings.textColor,SetBorderColor=settings.borderColor,SetBackgroundColor=settings.backgroundColor})[key]
			if color then line="    "..key.." "..table.concat(color," ") end
		end
		output[#output+1]=line
	end
	return table.concat(output,"\n")
end
return M
