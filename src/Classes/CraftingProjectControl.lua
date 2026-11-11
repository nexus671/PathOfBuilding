-- Crafting plans stay in the build; external simulation stays in Craft of Exile.
local projects = require("Modules.CraftingProjects")
local json = require("dkjson")
local Panel = { }
local function safely(callback)
	local ok,err=pcall(callback)
	if not ok then main:OpenMessagePopup("Crafting project",tostring(err):match("^[^\n]+")) end
end
local function button(x,y,w,label,callback)
	return new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function() safely(callback) end)
end
local function rows(lines)
	local result={ }
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=StripEscapes(part)
			while #part > 100 do result[#result+1]={height=18,part:sub(1,100)}; part=part:sub(101) end
			result[#result+1]={height=18,part}
		end
	end
	return result
end
local function editor(controls,key,x,y,w,h,value,prompt,limit)
	controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",prompt,nil,limit,nil,h > 24 and 16 or nil)
	return controls[key]
end
local function label(controls,key,x,y,text)
	controls[key]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},text)
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

function Panel.Edit(build,source,initialItem,initialSlot)
	local draft=source and copyTable(source) or {id="craft-"..require("sha1")(tostring({})..os.time()):sub(1,16),title="New crafting plan",slot=initialSlot or "Helmet",startingItem=initialItem or "",targetItem="",goals={},steps={}}
	local controls,slots={},{ }
	for name in pairs(build.itemsTab.slots) do slots[#slots+1]=name end
	table.sort(slots)
	local stepLines={ }
	for _,step in ipairs(draft.steps) do stepLines[#stepLines+1]=step.action end
	local originalSteps=table.concat(stepLines,"\n")
	label(controls,"titleLabel",16,18,"Project name")
	editor(controls,"title",16,38,580,24,draft.title,"Project name",120)
	controls.slot=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{612,38,252,24},slots)
	controls.slot:SelByValue(draft.slot)
	label(controls,"startingLabel",16,82,"Starting item (paste PoB or advanced in-game text)")
	label(controls,"targetLabel",448,82,"Target item (hypothetical or copied from the simulator)")
	editor(controls,"starting",16,102,416,132,draft.startingItem,"Starting item",24000)
	editor(controls,"target",448,102,416,132,draft.targetItem,"Target item (optional)",24000)
	label(controls,"goalsLabel",16,252,"Target modifiers (one per line)")
	label(controls,"stepsLabel",448,252,"Crafting steps (one per line)")
	editor(controls,"goals",16,272,416,90,table.concat(draft.goals,"\n"),"Targets",4000)
	editor(controls,"steps",448,272,416,130,originalSteps,"Crafting steps",40000)
	label(controls,"notesLabel",16,382,"Notes / stop and failure conditions")
	editor(controls,"notes",16,402,848,70,draft.notes,"Planning notes",8000)
	label(controls,"costLabel",16,492,"Estimated total / currency / source (optional, supplied estimate)")
	editor(controls,"cost",16,512,130,24,draft.estimate and draft.estimate.amount or "","Cost",20)
	editor(controls,"currency",162,512,130,24,draft.estimate and draft.estimate.currency or "chaos","Currency",24)
	editor(controls,"priceSource",308,512,556,24,draft.estimate and draft.estimate.source or "","Price source",240)
	label(controls,"explanation",16,558,"Planning steps are notes. Edit executable actions through Native crafting or AI. Build Save persists changes.")
	local function readDraft()
		draft.title,draft.slot,draft.startingItem,draft.targetItem,draft.notes=controls.title.buf,controls.slot:GetSelValue(),controls.starting.buf,controls.target.buf,controls.notes.buf
		draft.goals={ }
		for line in controls.goals.buf:gmatch("[^\r\n]+") do if line:match("%S") then draft.goals[#draft.goals+1]=line end end
		if controls.steps.buf ~= originalSteps then
			draft.steps={ }
			for line in controls.steps.buf:gmatch("[^\r\n]+") do if line:match("%S") then draft.steps[#draft.steps+1]={action=line} end end
		end
		if controls.cost.buf ~= "" then
			local old=draft.estimate
			local amount=assert(tonumber(controls.cost.buf),"Enter a numeric cost")
			draft.estimate={amount=amount,currency=controls.currency.buf,source=controls.priceSource.buf,
				quotedAt=old and amount == old.amount and controls.currency.buf == old.currency and controls.priceSource.buf == old.source and old.quotedAt or os.time()}
		else draft.estimate=nil end
		return projects.validate(draft)
	end
	controls.save=button(16,596,180,"Keep project in build",function() build.savers.CraftingProjects:Upsert(readDraft()); main.popups={}; Panel.Open(build) end)
	controls.preview=button(212,596,180,"Preview target stats",function() Panel.Preview(build,readDraft()) end)
	controls.close=button(748,596,116,"Cancel",function() main:ClosePopup() end)
	main:OpenPopup(880,644,"Edit crafting project",controls,nil,"title","close")
end

function Panel.Open(build,displayItem,displaySlot)
	local controls,list={},{ }
	local store=build.savers.CraftingProjects
	for index,project in ipairs(store.projects) do list[#list+1]={label=project.title,val=index} end
	local height=math.min(720,main.screenH-60)
	local function selected() return assert(store.projects[controls.projects:GetSelValueByKey("val")],"Create or select a project first") end
	local function refresh()
		local lines={"Crafting plans, targets and estimates are kept with this build. Save the build explicitly.","Native crafting runs locally. External Craft of Exile results remain separate supplied evidence."}
		if store.warning then lines[#lines+1]=store.warning end
		if #list > 0 then
			for _,line in ipairs(projects.lines(selected())) do lines[#lines+1]=line end
			for _,warning in ipairs(projects.handoff(selected().startingItem).warnings) do lines[#lines+1]=warning end
		else lines[#lines+1]="Create a project from the selected item, or paste starting-item text and write a plan. AI can propose one through MCP." end
		controls.details.list=rows(lines)
	end
	controls.projects=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,650,24},list,function() refresh() end)
	controls.edit=button(682,28,182,"Edit selected project",function() Panel.Edit(build,selected()) end)
	controls.edit.enabled=#list > 0
	controls.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,68,848,height-224},nil,{})
	refresh()
	controls.new=button(16,height-138,160,"New project",function() Panel.Edit(build,nil,displayItem and displayItem.raw,displaySlot) end)
	controls.copy=button(192,height-138,160,"Copy plan",function() Copy(json.encode(selected(),{indent=true})) end)
	controls.import=button(368,height-138,160,"Paste plan",function()
		local project=assert(json.decode(Paste()),"Clipboard needs a crafting project JSON object")
		store:Upsert(project); main.popups={}; Panel.Open(build)
	end)
	controls.native=button(544,height-138,160,"Native crafting",function() require("Classes.CraftingSimulatorControl").Open(build,selected()) end)
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
	main:OpenPopup(880,height,"Crafting projects",controls,nil,nil,"close")
end
return Panel
