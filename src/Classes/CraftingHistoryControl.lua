local ui=require("Modules.PlanningUI")
local workbench=require("Modules.CraftingWorkbench")
local inspect=require("Modules.CraftingInspection")
local M={}
function M.Open(model,current,history,actions,restore)
	local width=math.min(960,main.screenW-40);local height=math.min(700,main.screenH-60);local controls={};local states={};local choices={}
	for i,state in ipairs(history) do states[i]=state;choices[i]={label="Before "..(#actions-#history+i)..": "..(require("Modules.CraftingSimulator").labels[(actions[#actions-#history+i] or {}).method] or "craft"),val=i} end
	states[#states+1]=current;choices[#choices+1]={label="Current item",val=#states}
	controls.state=new("DropDownControl"):DropDownControl(ui.anchor,{16,28,width-32,26},choices)
	controls.state:SelByValue(#states,"val")
	local function selected() return states[controls.state:GetSelValueByKey("val")] end
	local refresh=workbench.item(controls,"item",16,76,math.floor(width*0.52)-24,height-144,model,selected)
	controls.changes=new("TextListControl"):TextListControl(ui.anchor,{math.floor(width*0.52)+8,76,math.ceil(width*0.48)-24,height-144},nil,{})
	local function update()
		refresh();local index=controls.state:GetSelValueByKey("val");local before=states[math.max(1,index-1)]
		local lines={index==1 and "Earliest retained item" or "Changes from preceding retained state",inspect.slots(model,selected())}
		for _,line in ipairs(inspect.diff(model,before,selected())) do lines[#lines+1]=line end
		controls.changes.list=ui.rows(lines,math.ceil(width*0.48)-54)
	end
	controls.state.selFunc=update
	controls.restore=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-48,190,28},"Restore selected item",function() local index=controls.state:GetSelValueByKey("val");restore(copyTable(states[index]),#states-index);main:ClosePopup() end)
	controls.restore.enabled=function() return controls.state:GetSelValueByKey("val")<#states end
	controls.close=new("ButtonControl"):ButtonControl(ui.anchor,{width-132,height-48,116,28},"Close",function() main:ClosePopup() end)
	ui.style(controls,{restore=true},{item=true});for _,control in pairs(controls) do control.layoutAudit="crafting-history" end;update();main:OpenPopup(width,height,"Crafting item history",controls,nil,nil,"close")
	return controls
end
return M
