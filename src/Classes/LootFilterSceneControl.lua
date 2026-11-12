local ui=require("Modules.PlanningUI")
local M={}
function M.Open(settings,save)
	local c={};ui.description(c,"help",16,28,508,52,{"Apply shared levels to generated example drops. Scenes illustrate filter matching and appearance; they do not predict drop rates."},14)
	for i,key in ipairs({"areaLevel","itemLevel"}) do ui.label(c,key.."Label",16,100+(i-1)*48,key=="areaLevel" and "Area level" or "Item level",14)
		c[key]=new("EditControl"):EditControl(ui.anchor,{280,94+(i-1)*48,244,28},tostring(settings[key]),nil,nil,3)
	end
	ui.label(c,"backgroundLabel",16,196,"Preview ground",14)
	c.background=new("DropDownControl"):DropDownControl(ui.anchor,{280,190,244,28},{"Stone","Dark","Light"});c.background:SelByValue(settings.background)
	c.keepScene=new("ButtonControl"):ButtonControl(ui.anchor,{16,254,220,28},"Use scene settings",function()
		local next={background=c.background:GetSelValue()};for _,key in ipairs({"areaLevel","itemLevel"}) do local value=tonumber(c[key].buf);assert(value and value==math.floor(value) and value>=1 and value<=100,"Levels must be between 1 and 100");next[key]=value end
		save(next);main:ClosePopup()
	end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{368,254,156,28},"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keepScene=true});main:OpenPopup(540,302,"Loot scene settings",c,nil,"areaLevel","close")
end
return M
