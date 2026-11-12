local ui=require("Modules.PlanningUI")
local M={}
M.labels={route="Continue to failure route",stop="Stop and inspect",restart="Restart from starting item",salvage="Set aside for salvage"}
M.help={route="Continue with the failure route shown on the recipe card.",stop="End this trial with the current item. Inspect it before choosing another route.",restart="Discard this hypothetical item, acquire the starting item again and return to step 1. Each restart adds the supplied starting-item cost. The action budget still limits loops.",salvage="End this trial and set the item aside. No resale proceeds are assumed or deducted from spending. Decide its value separately."}
function M.Open(step,keep)
	local c={};local w,h=math.min(820,main.screenW-40),math.min(480,main.screenH-48)
	ui.label(c,"heading",16,30,"When the step fails or exhausts its attempts",18)
	local choices={};for _,key in ipairs({"route","stop","restart","salvage"}) do choices[#choices+1]={label=M.labels[key],val=key} end
	c.action=new("DropDownControl"):DropDownControl(ui.anchor,{16,70,w-32,28},choices);c.action:SelByValue(step.onFailureAction or "route","val")
	local function refresh() c.explanation.list=ui.rows({M.help[c.action:GetSelValueByKey("val")],"For unwanted rolls, choose target/property conditions on the step. A successful currency use alone does not mean the final item is ready."},w-32,16) end
	ui.description(c,"explanation",16,116,w-32,110,{},16);c.action.selFunc=refresh
	ui.label(c,"notesTitle",16,242,"Recovery instructions / stop conditions")
	c.notes=new("EditControl"):EditControl(ui.anchor,{16,270,w-32,h-340},step.recoveryNotes or "",nil,"^%C\t\n",1000,nil,16)
	c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,h-48,200,28},"Keep recovery branch",function() local replacement=copyTable(step);replacement.onFailureAction=c.action:GetSelValueByKey("val");replacement.recoveryNotes=c.notes.buf;keep(replacement);main:ClosePopup() end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-48,140,28},"Cancel",function() main:ClosePopup() end)
	refresh();ui.style(c,{keep=true});main:OpenPopup(w,h,"Crafting recovery branch",c,nil,nil,"close")
end
return M
