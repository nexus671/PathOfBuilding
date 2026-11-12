-- Crafting plans stay in the build; external simulation stays in Craft of Exile.
local projects = require("Modules.CraftingProjects")
local json = require("dkjson")
local ui=require("Modules.PlanningUI")
local Panel = { }
local function safely(callback)
	local ok,err=pcall(callback)
	if not ok then main:OpenMessagePopup("Crafting project",tostring(err):match("^[^\n]+")) end
end
local function button(x,y,w,label,callback)
	return new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function() safely(callback) end)
end
local function rows(lines,width)
	width=width or 820
	local result={ }
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=StripEscapes(part)
			while DrawStringWidth(18,"VAR",part) > width do
				local low,high=1,#part
				while low < high do local middle=math.ceil((low+high)/2);if DrawStringWidth(18,"VAR",part:sub(1,middle)) <= width then low=middle else high=middle-1 end end
				local space=part:sub(1,low):match("^.*()%s")
				local cut=space and space > 1 and space-1 or low
				result[#result+1]={height=18,colorCodes.NORMAL..part:sub(1,cut)};part=part:sub(cut+1):gsub("^%s+","")
			end
			result[#result+1]={height=18,colorCodes.NORMAL..part}
		end
	end
	return result
end
local function editor(controls,key,x,y,w,h,value,prompt,limit)
	controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",nil,h>24 and "^%C\t\n" or nil,limit,nil,h > 24 and 16 or nil)
	return controls[key]
end
local function label(controls,key,x,y,text)
	controls[key]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},colorCodes.NORMAL..text)
end
local function textDialog(title,initial,callback)
	local controls={ }
	editor(controls,"text",16,32,828,420,initial,"Paste text here",128000)
	controls.accept=button(16,470,140,"Use this text",function() local value=controls.text.buf; main:ClosePopup(); callback(value) end)
	controls.close=button(728,470,116,"Cancel",function() main:ClosePopup() end)
	main:OpenPopup(860,520,title,controls,nil,"text","close")
end
local function showLines(title,lines)
	local height=math.min(680,main.screenH-60)
	local controls={ }
	controls.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,26,848,height-90},nil,rows(lines))
	controls.close=button(748,height-48,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(880,height,title,controls,nil,nil,"close")
end

function Panel.Preview(build,project)
	assert(project.targetItem and project.targetItem:match("%S"),"Paste a target item before previewing")
	local bridge=require("Modules.DesktopBuildBridge")
	assert(not bridge.prepared,"Review or reject the pending build proposal first")
	local prepared=bridge.prepare(build,{mode="edit",title="Crafting target: "..project.title:sub(1,100),baseRevision=bridge.revision(build),quote=project.estimate,
		operations={{type="set_crafting_project",project=project},{type="equip_item",slot=project.slot,text=project.targetItem}}})
	prepared.id="craft-"..require("sha1")(tostring({})..os.time()):sub(1,16)
	bridge.remember(prepared); bridge.prepared=prepared
	bridge.status=bridge.summary(prepared); bridge.status.status="review"
	if bridge.enabled then bridge.publishState() end
	require("Classes.BuildProposalControl").Review()
end

function Panel.Edit(build,source,initialItem,initialSlot,layout)
 require("Classes.CraftingProjectWizard").Open(build,source,initialItem,initialSlot,layout,function(project) Panel.Preview(build,project) end,function(project)
  if layout then layout.selectedProject=project.id end
  Panel.Open(build,nil,nil,layout)
 end)
end

function Panel.Open(build,displayItem,displaySlot,layout)
	if layout then layout.snapshot=nil;layout.viewState=nil;layout.workbench=nil end
	local controls,list={},{ }
	local store=build.savers.CraftingProjects
	for index,project in ipairs(store.projects) do list[#list+1]={label=project.title,val=index} end
	local height=layout and layout.height or math.min(720,main.screenH-60)
	local width=layout and layout.width or 880
	local function selected() return (assert(store.projects[controls.projects:GetSelValueByKey("val")],"Create or select a project first")) end
	local function refresh()
		local lines={"Crafting plans, targets and estimates are kept with this build. Save the build explicitly.","Native crafting runs locally. External Craft of Exile results remain separate supplied evidence."}
		if store.warning then lines[#lines+1]=store.warning end
		if #list > 0 then
			for _,line in ipairs(projects.lines(selected())) do lines[#lines+1]=line end
			for _,warning in ipairs(projects.handoff(selected().startingItem).warnings) do lines[#lines+1]=warning end
		else lines[#lines+1]="Create a project from the selected item, or paste starting-item text and write a plan. AI can propose one through MCP." end
		controls.details.list=rows(lines,width-60)
	end
	controls.projects=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,650,24},list,function() if layout then layout.selectedProject=selected().id;Panel.Open(build,nil,nil,layout) else refresh() end end)
	if layout and layout.selectedProject then for index,entry in ipairs(store.projects) do if entry.id==layout.selectedProject then controls.projects:SelByValue(index,"val") end end end
	controls.edit=button(682,28,182,"Edit selected project",function() Panel.Edit(build,selected(),nil,nil,layout) end)
	controls.edit.enabled=#list > 0
	controls.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,68,848,height-224},nil,{})
	refresh()
	controls.new=button(16,height-138,160,"New project",function() Panel.Edit(build,nil,displayItem and displayItem.raw,displaySlot,layout) end)
	controls.copy=button(192,height-138,160,"Copy plan",function() Copy(json.encode(selected(),{indent=true})) end)
	controls.import=button(368,height-138,160,"Paste plan",function()
		local project=assert(json.decode(Paste()),"Clipboard needs a crafting project JSON object")
		store:Upsert(project); main.popups={}; Panel.Open(build,nil,nil,layout)
	end)
	controls.native=button(544,height-138,160,"Native crafting",function() if layout then layout.openWorkbench(selected()) else require("Classes.CraftingSimulatorControl").Open(build,selected()) end end)
	controls.coe=button(16,height-48,220,"Craft of Exile (optional)",function() OpenURL(projects.handoff(selected().startingItem).url) end)
	controls.preview=button(720,height-138,144,"Preview target",function() Panel.Preview(build,selected()) end)
	controls.inspect=button(16,height-94,160,"Find modifiers",function()
		textDialog("Search native crafting modifiers","",function(query)
			local result=projects.inspect(selected().startingItem,query,100)
			local lines={"Native item-editor matches: "..result.total}
			for _,entry in ipairs(result.matches) do lines[#lines+1]=string.format("%s | level %s | %s | %s",entry.id,tostring(entry.level),entry.type or "unknown",entry.text) end
			for _,line in ipairs(result.limitations) do lines[#lines+1]=line end
			showLines("Native modifier reference",lines)
		end)
	end)
	controls.attach=button(192,height-94,160,"Attach CoE export",function() textDialog("Attach simulator export",selected().simulatorExport,function(value)
		local project=copyTable(selected()); project.simulatorExport=value; store:Upsert(project); refresh()
	end) end)
	controls.copyExport=button(368,height-94,160,"Copy CoE export",function() Copy(selected().simulatorExport or "") end)
	controls.done=button(544,height-94,160,"Complete next step",function()
		local project=copyTable(selected())
		for _,step in ipairs(project.steps) do if not step.done then step.done=true; break end end
		store:Upsert(project); refresh()
	end)
	controls.undoStep=button(720,height-94,144,"Undo step",function()
		local project=copyTable(selected())
		for i=#project.steps,1,-1 do if project.steps[i].done then project.steps[i].done=false; break end end
		store:Upsert(project); refresh()
	end)
	for _,name in ipairs({"copy","coe","native","preview","inspect","attach","copyExport","done","undoStep"}) do controls[name].enabled=#list > 0 end
	controls.close=button(748,height-48,116,"Close",function() main:ClosePopup() end)
	if layout then
		ui.label(controls,"heading",16,18,"Crafting projects",24)
		controls.projects.x=16;controls.projects.y=60;controls.projects.width=width-336
		controls.new.x=width-304;controls.new.y=60;controls.new.width=136
		controls.edit.x=width-156;controls.edit.y=60;controls.edit.width=140;controls.edit.label="Edit project"
		controls.libraryPage=new("DropDownControl"):DropDownControl(ui.anchor,{16,102,360,28},{"Item","Plan","Sharing"})
		ui.tabs(controls,controls.libraryPage,{{"tab_item","Item","Item"},{"tab_plan","Plan","Plan"},{"tab_sharing","Sharing","Sharing & tools"}},16,102,440)
		controls.details.x=16;controls.details.y=148;controls.details.width=width-32;controls.details.height=height-224
		controls.details.shown=function() return controls.libraryPage:GetSelValue()=="Plan" end
		controls.native.x=16;controls.native.y=404;controls.native.width=260;controls.native.height=32;controls.native.label="Open workbench"
		controls.preview.x=16;controls.preview.y=448;controls.preview.width=260;controls.preview.height=32;controls.preview.label="Compare target with build"
		for _,key in ipairs({"native","preview"}) do controls[key].shown=function() return controls.libraryPage:GetSelValue()=="Item" end end
		controls.preview.enabled=function() return #list>0 and selected().targetItem and selected().targetItem:match("%S")~=nil end
		for index,key in ipairs({"done","undoStep"}) do
			controls[key].x=16+(index-1)*224;controls[key].y=height-56;controls[key].width=212
			controls[key].shown=function() return controls.libraryPage:GetSelValue()=="Plan" end
		end
		for index,key in ipairs({"copy","import","inspect","attach","copyExport","coe"}) do
			controls[key].x=16+(index-1)%3*math.floor((width-32)/3);controls[key].y=164+math.floor((index-1)/3)*62;controls[key].width=math.floor((width-64)/3);controls[key].height=32
			controls[key].shown=function() return controls.libraryPage:GetSelValue()=="Sharing" end
		end
		controls.coe.label="Craft of Exile"
		local summary={"Create a project to start crafting.","Paste an item, set your targets, then open the workbench."}
		if #list>0 then
			local project=selected();summary={project.slot,"", "Targets"}
			for _,goal in ipairs(project.goals or {}) do summary[#summary+1]=goal end
			summary[#summary+1]="";summary[#summary+1]=#project.steps.." planned steps"
			local ok,model=pcall(require("Modules.CraftingSimulator").model,project.targetItem and project.targetItem:match("%S") and project.targetItem or project.startingItem)
			if ok then
				local refreshItem=require("Modules.CraftingWorkbench").item(controls,"projectItem",304+math.floor((width-320-math.min(540,width-336))/2),148,math.min(540,width-336),height-188,model,function() return model.initial end,nil,{header=212,artSize=112})
				refreshItem()
				controls.projectItem.shown=function() return controls.libraryPage:GetSelValue()=="Item" end
				controls.projectItemMods.shown=controls.projectItem.shown
			else summary[#summary+1]="Edit the starting item to open a native preview." end
		end
		controls.summary=new("TextListControl"):TextListControl(ui.anchor,{16,148,260,math.min(240,height-276)},nil,ui.rows(summary,230))
		controls.summary.shown=function() return controls.libraryPage:GetSelValue()=="Item" end
		controls.close.shown=false
		ui.style(controls,{native=true},{projectItem=true})
		if #list>0 then layout.selectedProject=selected().id end
		layout.mount(width,height,"Crafting projects",controls)
	else ui.style(controls,{native=true});main:OpenPopup(880,height,"Crafting projects",controls,nil,nil,"close") end
	return controls
end
return Panel
