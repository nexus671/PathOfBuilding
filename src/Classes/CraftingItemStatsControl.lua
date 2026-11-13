local stats=require("Modules.CraftingItemStats")
local Panel={}
function Panel.Open(goals,onKeep)
	local controls={};local anchor={"TOPLEFT",nil,"TOPLEFT"}
	controls.info=new("LabelControl"):LabelControl(anchor,{16,24,0,14},"Minimum native item values. Blank fields impose no condition.")
	controls.scope=new("LabelControl"):LabelControl(anchor,{16,46,0,14},"Local weapon/defence stats, before character bonuses.")
	for i,field in ipairs(stats.fields) do
		local x=16+(i-1)%2*256;local y=82+math.floor((i-1)/2)*54
		controls[field[1].."Label"]=new("LabelControl"):LabelControl(anchor,{x,y,0,14},field[2])
		controls[field[1]]=new("EditControl"):EditControl(anchor,{x,y+18,232,26},tostring(goals and goals[field[1]] or ""),nil,nil,16)
	end
	controls.keep=new("ButtonControl"):ButtonControl(anchor,{16,372,232,26},"Keep minimum stats",function()
		local ok,message=pcall(function()
			local result={}
			for _,field in ipairs(stats.fields) do local value=controls[field[1]].buf;if value~="" then result[field[1]]=assert(tonumber(value),"Enter a number for "..field[2]:lower()) end end
			if next(result) then stats.validate(result) else result=nil end
			onKeep(result);main:ClosePopup()
		end)
		if not ok then main:OpenMessagePopup("Item stat goals",require("Modules.PlanningUI").errorText(message)) end
	end)
	controls.close=new("ButtonControl"):ButtonControl(anchor,{388,372,116,26},"Close",function() main:ClosePopup() end)
	require("Modules.PlanningUI").style(controls,{keep=true})
	main:OpenPopup(520,424,"Weapon and defence goals",controls,nil,nil,"close")
	return controls
end
return Panel
