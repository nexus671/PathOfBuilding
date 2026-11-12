-- Native recipe routing editor. Actions are captured from the emulator.
local sim=require("Modules.CraftingSimulator")
local Panel={}
local function button(controls,key,x,y,w,label,callback)
	controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function()
		local ok,message=pcall(callback);if not ok then main:OpenMessagePopup("Crafting recipe",tostring(message):match("^[^\n]+")) end
	end)
end
local function edit(x,y,w,value,prompt,limit)
	return new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},tostring(value or ""),prompt,nil,limit)
end
function Panel.Open(recipe,currentAction,onKeep,model)
	local draft=copyTable(recipe or {steps={},targets={}})
	local controls={};local selected=1
	local ui=require("Modules.PlanningUI")
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Select a step card, or connect routes in the flow graph.")
	controls.graph=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,62,828,264},nil,{})
	controls.step=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,350,828,24},{})
	controls.attempts=edit(16,400,180,"1","Attempts per visit",3)
	controls.condition=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{212,400,632,24},{"After a successful action","Until final targets and properties match","Keep custom conditions"})
	controls.success=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,456,404,24},{})
	controls.failure=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{440,456,404,24},{})
	controls.routeLabel=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,436,0,14},"Success route                                                   Failure / exhausted attempts route")
	local function loadStep()
		local step=draft.steps[selected];if not step then return end
		for _,row in ipairs(controls.graph.list) do row.selected=row.step==selected end
		controls.attempts:SetText(tostring(step.maxAttempts or 1))
		controls.condition:SelByValue((step.untilTargets or step.untilRequirements) and "Keep custom conditions" or "After a successful action")
		controls.success:SelByValue(step.onSuccess or 0,"val");controls.failure:SelByValue(step.onFailure or 0,"val")
	end
	local function refresh()
		local list,routes,lines={ },{{label="Next step",val=0}},{}
		for i,step in ipairs(draft.steps) do
			list[#list+1]={label=i..". "..(sim.labels[step.method] or step.method),val=i}
			routes[#routes+1]={label="Step "..i,val=i}
			local function route(target) return target>#draft.steps and "Finish" or "Step "..target end
			lines[#lines+1]={height=92,textSize=16,x=44,card=true,step=i,selected=i==selected,iconPath=require("Modules.CraftingWorkbench").icon(step.method),
				subtitle=string.format("Success -> %s | Failure -> %s",route(step.onSuccess or i+1),step.onFailureAction and step.onFailureAction~="route" and require("Classes.CraftingRecoveryControl").labels[step.onFailureAction] or route(step.onFailure or i+1)),
				detail=(step.untilTargets or step.untilRequirements) and "Repeat until target conditions match" or "Continue after one successful action",
				"^7"..string.format("%d. %s | up to %d attempts",i,sim.labels[step.method] or step.method,step.maxAttempts or 1)}
		end
		routes[#routes+1]={label="End recipe",val=#draft.steps+1}
		controls.graph.list=lines;controls.step:SetList(list);controls.step:SelByValue(selected,"val")
		controls.success:SetList(routes);controls.failure:SetList(copyTable(routes));loadStep()
	end
	controls.step.selFunc=function(_,entry) selected=entry.val;loadStep() end
	button(controls,"flowGraph",664,24,180,"Flow graph",function()
		require("Classes.CraftingRecipeGraphControl").Open(draft,{model=model,change=function(next) draft=next;refresh() end,edit=function(index) selected=index;refresh();main:ClosePopup();main.popups[1]:SelectControl(controls.attempts) end})
	end)
	ui.selectable(controls.graph,function(row) return row.step end,function(row) selected=row.step;controls.step:SelByValue(selected,"val");loadStep() end)
	button(controls,"add",16,514,256,"Append current emulator action",function()
		assert(#draft.steps < 20,"Use up to twenty steps")
		draft.steps[#draft.steps+1]=copyTable(currentAction);selected=#draft.steps;refresh()
	end)
	button(controls,"replace",288,514,272,"Replace selected with emulator action",function() assert(draft.steps[selected],"Select a step");draft.steps[selected]=copyTable(currentAction);refresh() end)
	button(controls,"delete",576,514,268,"Delete selected step",function()
		assert(draft.steps[selected],"Select a step");table.remove(draft.steps,selected)
		for _,step in ipairs(draft.steps) do for _,key in ipairs({"onSuccess","onFailure"}) do if step[key] and step[key] > selected then step[key]=step[key]-1 end end end
		selected=math.min(selected,math.max(1,#draft.steps));refresh()
	end)
	button(controls,"update",16,558,256,"Update selected routes",function()
		local step=assert(draft.steps[selected],"Select a step")
		step.maxAttempts=assert(tonumber(controls.attempts.buf),"Enter an attempt count")
		local condition=controls.condition:GetSelValue()
		if condition == "Until final targets and properties match" then assert(#draft.targets > 0 or draft.requirements,"Choose targets or properties in the emulator first");step.untilTargets=#draft.targets > 0 and copyTable(draft.targets) or nil;step.untilRequirements=draft.requirements and copyTable(draft.requirements) or nil
		elseif condition == "After a successful action" then step.untilTargets=nil;step.untilRequirements=nil end
		local success,failure=controls.success:GetSelValueByKey("val"),controls.failure:GetSelValueByKey("val")
		step.onSuccess=success ~= 0 and success or nil;step.onFailure=failure ~= 0 and failure or nil
		sim.validateRecipe(draft);refresh()
	end)
	controls.note=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,604,0,14},"Loops stop at the simulation action budget. Keeping a recipe does not craft or equip an item.")
	button(controls,"recovery",288,558,272,"Failure recovery",function()
		local step=assert(draft.steps[selected],"Select a recipe step")
		require("Classes.CraftingRecoveryControl").Open(step,function(replacement) draft.steps[selected]=replacement;sim.validateRecipe(draft);refresh() end)
	end)
	button(controls,"keep",16,642,256,"Keep recipe",function() onKeep(sim.validateRecipe(draft));main:ClosePopup() end)
	button(controls,"close",728,642,116,"Close",function() main:ClosePopup() end)
	local height=math.max(520,math.min(690,main.screenH-60));local offset=690-height
	controls.graph.height=264-offset
	for key,control in pairs(controls) do if key ~= "graph" and control.y >= 350 then control.y=control.y-offset end end
	refresh();ui.style(controls,{keep=true});for _,control in pairs(controls) do control.layoutAudit="recipe-editor" end;main:OpenPopup(860,height,"Crafting recipe routes",controls,nil,nil,"close")
	return controls
end
return Panel
