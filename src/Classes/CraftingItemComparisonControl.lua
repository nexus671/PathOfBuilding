local ui=require("Modules.PlanningUI")
local sim=require("Modules.CraftingSimulator")
local art=require("Modules.CraftingWorkbench")
local M={}
function M.Open(left,right)
	local c={};local w,h=math.min(1080,main.screenW-40),math.min(720,main.screenH-60);local width=math.floor((w-48)/2)
	for i,entry in ipairs({left,right}) do
		local x=16+(i-1)*(width+16);ui.label(c,"title"..i,x,28,ui.fit(entry.title,width,16),16)
		local model=sim.model(entry.baseItem);local refresh=art.item(c,"item"..i,x,64,width,h-148,model,function() return entry.state end,nil,{header=180,artSize=84});refresh();c["item"..i].enabled=false
	end
	ui.label(c,"hint",16,h-68,"Saved and working simulations. Neither item is equipped by this comparison.",13)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-42,140,28},"Close",function() main:ClosePopup() end)
	ui.style(c,nil,{item1=true,item2=true});for _,control in pairs(c) do control.layoutAudit="crafting-item-comparison" end;main:OpenPopup(w,h,"Saved item versus working item",c,nil,nil,"close");return c
end
return M
