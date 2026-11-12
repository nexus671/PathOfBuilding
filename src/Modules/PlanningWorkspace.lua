-- A persistent build tab for AI planning, Atlas strategies and crafting projects.
local M={}
local pages={ai="AI builds",atlas="Atlas",crafting="Crafting"}
function M.new(build)
	local self=setmetatable({build=build,page="ai",cache={},drafts={},controls={},viewport={x=312,y=32,width=968,height=688}},{__index=M})
	self.nav=new("ControlHost"):ControlHost()
	local anchor=new("Control"):Control(nil,{0,0,0,0})
	anchor.x=function() return self.viewport.x end;anchor.y=function() return self.viewport.y end
	for index,page in ipairs({"ai","atlas","crafting"}) do
		local control=new("ButtonControl"):ButtonControl({"TOPLEFT",anchor,"TOPLEFT"},{16+(index-1)*142,10,134,28},pages[page],function() self:Show(page) end)
		control.locked=function() return self.page==page end
		self.nav.controls["nav_"..page]=control
	end
	return self
end
function M:Show(page,source)
	assert(pages[page],"Unknown planning page")
	self.page=page
	local cached=self.cache[page]
	local saved=self.drafts[page]
	source=source or saved and saved.plan
	if not cached then
		local layout={restore=saved and saved.view,width=self.viewport.width,height=self.viewport.height-52,navigate=function(target) self:Show(target) end}
		layout.mount=function(width,height,title,controls)
			local body=new("PopupDialog"):PopupDialog(width,height,title,controls)
			body.x=function() return self.viewport.x end;body.y=function() return self.viewport.y+52 end
			self.cache[page]={body=body,layout=layout};self.body=body
			self:UpdateControls()
		end
		if page=="atlas" then require("Classes.AtlasPlannerControl").Open(self.build,source,layout)
		elseif page=="crafting" then require("Classes.CraftingProjectControl").Open(self.build,nil,nil,layout)
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
	self:ProcessControlsInput(events or {},viewport)
	SetDrawColor(0.065,0.075,0.09);DrawImage(nil,viewport.x,viewport.y,viewport.width,viewport.height)
	SetDrawColor(0.15,0.17,0.2);DrawImage(nil,viewport.x,viewport.y+48,viewport.width,2)
	self.nav:DrawControls(viewport)
	self.body:DrawControls(viewport)
end
return M
