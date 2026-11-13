-- A persistent build tab for AI planning, Atlas strategies and crafting projects.
local M={}
local pages={ai="AI builds",atlas="Atlas",crafting="Crafting",journey="Journey",filters="Loot filter"}
function M.new(build)
	local self=setmetatable({build=build,page="ai",cache={},drafts={},selections={},craftDrafts=build.planningCraftDrafts or {},controls={},viewport={x=0,y=32,width=main.screenW,height=main.screenH-32}},{__index=M})
	build.planningCraftDrafts=nil
	self.nav=new("ControlHost"):ControlHost()
	local anchor=new("Control"):Control(nil,{0,0,0,0})
	anchor.x=function() return self.viewport.x end;anchor.y=function() return self.viewport.y end
	for index,page in ipairs({"ai","atlas","crafting","journey","filters"}) do
		local control=new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{112+(index-1)*110,10,102,28},pages[page],function() self:Show(page) end)
		control.locked=function() return self.page==page end
		control.tooltipText="Alt+"..index.." | Tab: move focus | Enter: activate"
		self.nav.controls["nav_"..page]=require("Modules.PlanningUI").styleButton(control)
	end
	self.nav.controls.nav_build=require("Modules.PlanningUI").styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{16,10,80,28},"< Build",function()
		build:SelectControl(nil);build.viewMode=build.plannerPreviousMode or "TREE"
	end))
	self.nav.controls.nav_text=require("Modules.PlanningUI").styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{664,10,54,28},"Aa",function()
		for page in pairs(self.cache) do self:Remember(page) end
		main.planningTextLarge=not main.planningTextLarge;self.cache={};self:Show(self.page)
	end))
	self.nav.controls.nav_text.tooltipText="Toggle normal / large planning text"
	self.nav.controls.nav_tools=require("Modules.PlanningUI").styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{726,10,80,28},"Tools",function() require("Classes.PlanningToolsControl").Open(build) end))
	self.nav.controls.nav_tools.label=function() return require("Modules.PlanningRecovery").hasPending(build) and "Tools *" or "Tools" end
	self.nav.controls.nav_tools.tooltipText="Planning tools and local draft recovery. * means an earlier session has a draft to review."
	-- Planning keeps file actions in the native header; character editing stays
	-- on the Build page so it cannot crowd file actions at smaller widths.
	for _,key in ipairs({"pointDisplay","levelScalingButton","characterLevel","classDrop","ascendDrop","secondaryAscendDrop","buildLoadouts","buildName"}) do
		local control=build.controls[key];local shown=control.shown
		control.shown=function(c)
			if build.viewMode=="PLANNER" then return false end
			if type(shown)=="function" then return shown(c) end
			return shown
		end
	end
	for _,key in ipairs({"back","save","saveAs"}) do build.controls[key].layoutAudit="planning-header" end
	local context=new("Control"):Control(nil,{224,0,function() return math.max(0,main.screenW-240) end,28})
	context.shown=function() return build.viewMode=="PLANNER" end
	context.layoutAudit="planning-header"
	function context:Draw()
		local x,y=self:GetPos();local w=self:GetSize();local title=build.buildName or "Untitled build"
		if w<DrawStringWidth(13,"VAR","...") then return end
		local ui=require("Modules.PlanningUI");local status=ui.saveStatus(build)
		title=ui.fit(title,w,13);status=ui.fit(status,w,12)
		SetDrawColor("^x9BA9BA");DrawString(x+w,y,"RIGHT_X",13,"VAR",title);DrawString(x+w,y+15,"RIGHT_X",12,"VAR",status)
	end
	build.controls.planningContext=context
	return self
end
function M:Remember(page)
	local entry=self.cache[page];if not entry then return end
	self.drafts[page]={plan=entry.layout.snapshot and entry.layout.snapshot(),view=entry.layout.viewState and entry.layout.viewState(),controls=require("Modules.PlanningUI").capture(entry.body.controls)}
	local plan=self.drafts[page].plan;if page=="crafting" and plan and plan.kind=="workbench" then self.craftDrafts[plan.project.id]=plan end
	if self.drafts[page].plan and (page=="filters" or page=="atlas" or page=="crafting" and self.drafts[page].plan.kind=="workbench") then require("Modules.PlanningRecovery").save(self.build,page,self.drafts[page]) end
end
function M:CraftingDraft(id)
	local draft=self.craftDrafts[id]
	local entry=self.cache.crafting
	if entry and entry.layout.snapshot then
		local current=entry.layout.snapshot()
		if current and current.kind=="workbench" and current.project.id==id then draft=current end
	end
	return draft and copyTable(draft)
end
function M:CopyCraftingDrafts(candidate)
	local originals={};for _,project in ipairs(self.build.savers.CraftingProjects.projects) do originals[project.id]=project end
	local copies={}
	for _,project in ipairs(candidate.savers.CraftingProjects.projects) do
		local old=originals[project.id]
		if old and old.startingItem==project.startingItem and old.slot==project.slot then
			local draft=self:CraftingDraft(project.id)
			if draft then
				draft.project=require("Modules.CraftingProjects").copy({project})[1]
				copies[project.id]=draft
				local job=require("Modules.CraftingTasks").job
				if job and job.build==self.build and job.analysis and job.analysis.projectId==project.id then draft.resultRows=require("Modules.PlanningUI").rows({"Calculation cancelled after the build edit. Rerun to refresh."},400) end
				if require("Modules.PlanningUI").hasDraft(self.build,"workingCraft",project.id) then require("Modules.PlanningUI").draft(candidate,"workingCraft",project.id) end
			end
		end
	end
	if candidate.planningWorkspace then candidate.planningWorkspace.craftDrafts=copies else candidate.planningCraftDrafts=copies end
end
function M:ForgetCraftingProject(id)
	local draft=self:CraftingDraft(id)
	local entry=self.cache.crafting
	if entry and entry.layout.snapshot then
		local current=entry.layout.snapshot()
		if current and current.kind=="workbench" and current.project.id==id then self.cache.crafting=nil;if self.page=="crafting" then self.body=nil end end
	end
	self.craftDrafts[id]=nil
	local saved=self.drafts.crafting
	if saved and saved.plan and saved.plan.project and saved.plan.project.id==id then self.drafts.crafting=nil end
	if self.selections.crafting==id then self.selections.crafting=nil end
	return draft
end
function M:Show(page,source)
	assert(pages[page],"Unknown planning page")
	if self.page~=page then self:Remember(self.page) end
	self.page=page
	if source or page=="journey" then self.cache[page]=nil end
	local cached=self.cache[page]
	local saved=self.drafts[page]
	source=source or saved and saved.plan
	if not cached then
		local layout={selectedProject=self.selections[page],restore=saved and saved.view,restorePage=saved and saved.plan and saved.plan.page,width=self.viewport.width,height=self.viewport.height-52,navigate=function(target,value) self:Show(target,value) end}
		layout.openProjects=function()
			local current=self.cache.crafting
			if current and current.layout.snapshot then
				local draft=current.layout.snapshot();if draft.kind=="workbench" then self.craftDrafts[draft.project.id]=draft end
			end
			self.cache.crafting=nil;self.drafts.crafting=nil;self:Show("crafting")
		end
		layout.openWorkbench=function(project)
			if page~="crafting" then
				local draft=self.craftDrafts[project.id];if draft and draft.project.startingItem~=project.startingItem then draft=nil end
				self:Show("crafting",draft or {kind="workbench",project=project});return
			end
			local current=self.cache.crafting
			if current and current.layout.snapshot then
				local working=current.layout.snapshot();if working.kind=="workbench" then self.craftDrafts[working.project.id]=working end
			end
			self.page="crafting";self.cache.crafting=nil
			local draft=self.craftDrafts[project.id]
			layout.workbench=nil
			if draft and draft.project.startingItem==project.startingItem then layout.workbench=draft end
			if page=="crafting" then require("Classes.CraftingSimulatorControl").Open(self.build,project,layout)
			else self:Show("crafting",draft or {kind="workbench",project=project}) end
		end
		layout.mount=function(width,height,title,controls)
			local body=new("PopupDialog"):PopupDialog(width,height,title,controls)
			body.x=function() return self.viewport.x end;body.y=function() return self.viewport.y+52 end
			self.cache[page]={body=body,layout=layout};self.body=body
			require("Modules.PlanningUI").restore(body,saved and saved.controls)
			self.selections[page]=layout.selectedProject
			self:UpdateControls()
		end
		if page=="filters" then require("Classes.LootFilterControl").Open(self.build,source,layout)
		elseif page=="journey" then require("Classes.BuildJourneyControl").Open(self.build,source,layout)
		elseif page=="atlas" then require("Classes.AtlasPlannerControl").Open(self.build,source,layout)
		elseif page=="crafting" then
			if source and source.kind=="workbench" then layout.workbench=source.state and source or nil;require("Classes.CraftingSimulatorControl").Open(self.build,source.project,layout)
			else require("Classes.CraftingProjectControl").Open(self.build,nil,nil,layout) end
		else require("Classes.BuildProposalControl").Open(self.build,layout) end
	else self.body=cached.body end
	local active=self.cache[page];if active and active.layout.onShow then active.layout.onShow() end
	self:UpdateControls()
end
function M:UpdateControls()
	self.controls={}
	for key,control in pairs(self.nav.controls) do self.controls[key]=control end
	for key,control in pairs(self.body and self.body.controls or {}) do self.controls[key]=control end
end
function M:ProcessControlsInput(events,viewport)
	if self.body then require("Modules.PlanningUI").keyboard(self.body,events) end
	for i,event in pairs(events) do if event.type=="KeyDown" and IsKeyDown("ALT") then
		local page=({["1"]="ai",["2"]="atlas",["3"]="crafting",["4"]="journey",["5"]="filters"})[event.key]
		if page then self:Show(page);event.type="PlanningHandled" end
	elseif event.type=="KeyDown" and IsKeyDown("CTRL") and self.body then
		local focused=self.body.selControl
		if event.key=="f" and self.body.controls.search then self.body:SelectControl(self.body.controls.search);event.type="PlanningHandled"
		elseif event.key=="z" and not (focused and focused.buf) then
			local action=self.body.controls[IsKeyDown("SHIFT") and "redo" or "undo"];if action then action:Click();event.type="PlanningHandled" end
		end
	end end
	self.nav:ProcessControlsInput(events,viewport)
	if self.body then self.body:ProcessControlsInput(events,viewport) end
end
function M:Draw(viewport,events)
	local resized=self.viewport.width~=viewport.width or self.viewport.height~=viewport.height
	self.viewport=viewport
	if resized then
		for page in pairs(self.cache) do self:Remember(page) end
		self.cache={};self.body=nil
		self:Show(self.page)
	elseif not self.body then self:Show(self.page) end
	local active=self.cache[self.page];if active and active.layout.tick then active.layout.tick() end
	if active and active.layout.snapshot and (self.page=="filters" or self.page=="atlas" or self.page=="crafting") then
		if not launch.headless and (not self.lastRecovery or GetTime()-self.lastRecovery>2000) then self.lastRecovery=GetTime();self:Remember(self.page) end
	end
	self:ProcessControlsInput(events or {},viewport)
	SetDrawColor(0.065,0.075,0.09);DrawImage(nil,viewport.x,viewport.y,viewport.width,viewport.height)
	SetDrawColor(0.15,0.17,0.2);DrawImage(nil,viewport.x,viewport.y+48,viewport.width,2)
	self.nav:DrawControls(viewport)
	self.body:DrawControls(viewport)
end
return M
