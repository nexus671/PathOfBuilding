-- Export-time appearance changes. Conditions, actions and source files stay intact.
local parser=require("Modules.LootFilterParser")
local M={}
function M.apply(raw,settings)
	if not settings or not next(settings) then return raw end
	local output={};local block=false
	for line in (raw.."\n"):gmatch("([^\n]*)\n") do
		local ok,tokens=pcall(parser.tokens,line);local key=ok and tokens[1]
		if key=="Show" or key=="Hide" or key=="Minimal" or key=="Import" then
			block=key~="Import"
		elseif block and key=="SetFontSize" and settings.minimumFontSize and #tokens==2 and tonumber(tokens[2]) and tonumber(tokens[2])>=1 and tonumber(tokens[2])<=45 and tonumber(tokens[2])==math.floor(tonumber(tokens[2])) then
			-- Do not inject a size into blocks that inherit styling through Continue.
			line="    SetFontSize "..math.max(tonumber(tokens[2]),settings.minimumFontSize)
		elseif block and settings.alertVolume~=nil and (key=="PlayAlertSound" or key=="PlayAlertSoundPositional" or key=="CustomAlertSound" or key=="CustomAlertSoundOptional") and tokens[2] then
			local sound=key:find("Custom",1,true) and '"'..tokens[2]..'"' or tokens[2]
			line="    "..key.." "..sound.." "..settings.alertVolume
		elseif block and settings.disableEffects and key=="PlayEffect" then line="    PlayEffect None" end
		output[#output+1]=line
	end
	return table.concat(output,"\n")
end
return M
