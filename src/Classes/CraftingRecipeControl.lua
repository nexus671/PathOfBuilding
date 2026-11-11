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
function Panel.Open(recipe,currentAction,onKeep)
	local draft=copyTable(recipe or {steps={},targets={}})
	local controls={};local selected=1
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Capture actions in the emulator, then connect success and failure routes here.")
	controls.graph=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,62,828,264},nil,{})
	controls.step=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,350,828,24},{})
	controls.attempts=edit(16,400,180,"1","Attempts per visit",3)
	controls.condition=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{212,400,632,24},{"After a successful action","Until all final target groups match","Keep custom conditions"})
	controls.success=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,456,404,24},{})
	controls.failure=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{440,456,404,24},{})
	controls.routeLabel=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,436,0,14},"Success route                                                   Failure / exhausted attempts route")
	local function loadStep()
		local step=draft.steps[selected];if not step then return end
		controls.attempts:SetText(tostring(step.maxAttempts or 1))
		controls.condition:SelByValue(step.untilTargets and "Keep custom conditions" or "After a successful action")
		controls.success:SelByValue(step.onSuccess or 0,"val");controls.failure:SelByValue(step.onFailure or 0,"val")
	end
	local function refresh()
		local list,routes,lines={ },{{label="Next step",val=0}},{}
		for i,step in ipairs(draft.steps) do
			list[#list+1]={label=i..". "..(sim.labels[step.method] or step.method),val=i}
			routes[#routes+1]={label="Step "..i,val=i}
			lines[#lines+1]={height=24,string.format("[%d] %s | up to %d attempt(s)",i,sim.labels[step.method] or step.method,step.maxAttempts or 1)}
			lines[#lines+1]={height=22,string.format("      Success -> %s    Failure -> %s",step.onSuccess or i+1,step.onFailure or i+1)}
			if step.untilTargets then lines[#lines+1]={height=20,"      Stop repeating when the selected target conditions match."} end
		end
		routes[#routes+1]={label="End recipe",val=#draft.steps+1}
		controls.graph.list=lines;controls.step:SetList(list);controls.step:SelByValue(selected,"val")
		controls.success:SetList(routes);controls.failure:SetList(copyTable(routes));loadStep()
	end
	controls.step.selFunc=function(_,entry) selected=entry.val;loadStep() end
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
		if condition == "Until all final target groups match" then assert(#draft.targets > 0,"Choose target groups in the emulator first");step.untilTargets=copyTable(draft.targets);step.untilRequirements=nil
		elseif condition == "After a successful action" then step.untilTargets=nil;step.untilRequirements=nil end
		local success,failure=controls.success:GetSelValueByKey("val"),controls.failure:GetSelValueByKey("val")
		step.onSuccess=success ~= 0 and success or nil;step.onFailure=failure ~= 0 and failure or nil
		sim.validateRecipe(draft);refresh()
	end)
	controls.note=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,604,0,14},"Loops stop at the simulation action budget. Keeping a recipe does not craft or equip an item.")
	button(controls,"keep",16,642,256,"Keep recipe",function() onKeep(sim.validateRecipe(draft));main:ClosePopup() end)
	button(controls,"close",728,642,116,"Close",function() main:ClosePopup() end)
	local height=math.max(520,math.min(690,main.screenH-60));local offset=690-height
	controls.graph.height=264-offset
	for key,control in pairs(controls) do if key ~= "graph" and control.y >= 350 then control.y=control.y-offset end end
	refresh();main:OpenPopup(860,height,"Crafting recipe routes",controls,nil,nil,"close")
	return controls
end
return Panel
