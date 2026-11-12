-- A persistent build tab for AI planning, Atlas strategies and crafting projects.
local M={}
local pages={ai="AI builds",atlas="Atlas",crafting="Crafting",journey="Journey"}
function M.new(build)
	local self=setmetatable({build=build,page="ai",cache={},drafts={},selections={},craftDrafts={},controls={},viewport={x=0,y=32,width=main.screenW,height=main.screenH-32}},{__index=M})
	self.nav=new("ControlHost"):ControlHost()
	local anchor=new("Control"):Control(nil,{0,0,0,0})
	anchor.x=function() return self.viewport.x end;anchor.y=function() return self.viewport.y end
	for index,page in ipairs({"ai","atlas","crafting","journey"}) do
		local control=new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{112+(index-1)*142,10,134,28},pages[page],function() self:Show(page) end)
		control.locked=function() return self.page==page end
		control.tooltipText="Alt+"..index.." | Tab: move focus | Enter: activate"
		self.nav.controls["nav_"..page]=require("Modules.PlanningUI").styleButton(control)
	end
	self.nav.controls.nav_build=require("Modules.PlanningUI").styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{16,10,80,28},"< Build",function()
		build:SelectControl(nil);build.viewMode=build.plannerPreviousMode or "TREE"
	end))
	local context=new("Control"):Control({"TOPLEFT",anchor,"TOPLEFT"},{702,10,function() return math.max(0,self.viewport.width-718) end,28})
	function context:Draw()
		local x,y=self:GetPos();local w=self:GetSize();local title=build.buildName or "Untitled build"
		local suffix=build.unsaved and " | Unsaved" or ""
		while #title>0 and DrawStringWidth(13,"VAR",title..suffix)>w do title=title:sub(1,-2) end
		SetDrawColor("^x9BA9BA");DrawString(x+w,y+7,"RIGHT_X",13,"VAR",title..suffix)
	end
	self.nav.controls.nav_context=context
	return self
end
function M:Show(page,source)
	assert(pages[page],"Unknown planning page")
	self.page=page
	if source or page=="journey" then self.cache[page]=nil end
	local cached=self.cache[page]
	local saved=self.drafts[page]
	source=source or saved and saved.plan
	if not cached then
		local layout={selectedProject=self.selections[page],restore=saved and saved.view,width=self.viewport.width,height=self.viewport.height-52,navigate=function(target,value) self:Show(target,value) end}
		layout.openProjects=function()
			local current=self.cache.crafting
			if current and current.layout.snapshot then
				local draft=current.layout.snapshot();if draft.kind=="workbench" then self.craftDrafts[draft.project.id]=draft end
			end
			self.cache.crafting=nil;self.drafts.crafting=nil;self:Show("crafting")
		end
		layout.openWorkbench=function(project)
			self.page="crafting";self.cache.crafting=nil
			local draft=self.craftDrafts[project.id]
			if draft and draft.project.startingItem==project.startingItem then layout.workbench=draft end
			if page=="crafting" then require("Classes.CraftingSimulatorControl").Open(self.build,project,layout)
			else self:Show("crafting",draft or {kind="workbench",project=project}) end
		end
		layout.mount=function(width,height,title,controls)
			local body=new("PopupDialog"):PopupDialog(width,height,title,controls)
			body.x=function() return self.viewport.x end;body.y=function() return self.viewport.y+52 end
			self.cache[page]={body=body,layout=layout};self.body=body
			self.selections[page]=layout.selectedProject
			self:UpdateControls()
		end
		if page=="journey" then require("Classes.BuildJourneyControl").Open(self.build,source,layout)
		elseif page=="atlas" then require("Classes.AtlasPlannerControl").Open(self.build,source,layout)
		elseif page=="crafting" then
			if source and source.kind=="workbench" then layout.workbench=source.state and source or nil;require("Classes.CraftingSimulatorControl").Open(self.build,source.project,layout)
			else require("Classes.CraftingProjectControl").Open(self.build,nil,nil,layout) end
		else require("Classes.BuildProposalControl").Open(self.build,layout) end
	else self.body=cached.body end
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
		local page=({["1"]="ai",["2"]="atlas",["3"]="crafting",["4"]="journey"})[event.key]
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
		for page,entry in pairs(self.cache) do if entry.layout.snapshot then self.drafts[page]={plan=entry.layout.snapshot(),view=entry.layout.viewState and entry.layout.viewState()} end end
		self.cache={};self.body=nil
		self:Show(self.page)
	elseif not self.body then self:Show(self.page) end
	local active=self.cache[self.page];if active and active.layout.tick then active.layout.tick() end
	self:ProcessControlsInput(events or {},viewport)
	SetDrawColor(0.065,0.075,0.09);DrawImage(nil,viewport.x,viewport.y,viewport.width,viewport.height)
	SetDrawColor(0.15,0.17,0.2);DrawImage(nil,viewport.x,viewport.y+48,viewport.width,2)
	self.nav:DrawControls(viewport)
	self.body:DrawControls(viewport)
end
return M
