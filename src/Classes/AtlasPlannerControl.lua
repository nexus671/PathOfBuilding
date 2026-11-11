-- Atlas planning is separate from the character tree and its calculations.
local atlas=require("Modules.AtlasPlanner")
local Panel={}
local function safely(callback)
	local ok,err=pcall(callback)
	if not ok then main:OpenMessagePopup("Atlas planner",tostring(err):match("^[^\n]+")) end
end
local function button(x,y,w,label,callback)
	return new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function() safely(callback) end)
end
local function edit(x,y,w,h,value,prompt,limit)
	return new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",prompt,nil,limit,nil,h > 24 and 16 or nil)
end
local function rows(lines,width)
	local result={}
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=StripEscapes(part)
			while #part > width do result[#result+1]={height=18,part:sub(1,width)}; part=part:sub(width+1) end
			result[#result+1]={height=18,part}
		end
	end
	return result
end
local Canvas=newClass("AtlasTreeCanvas","Control")
function Canvas:AtlasTreeCanvas(rect,tree,selected,onSelect)
	self:Control({"TOPLEFT",nil,"TOPLEFT"},rect)
	self.tree,self.selected,self.onSelect=tree,selected,onSelect
	self:Fit()
	return self
end
function Canvas:Fit()
	local lowX,highX,lowY,highY=math.huge,-math.huge,math.huge,-math.huge
	for _,node in pairs(self.tree.nodes) do lowX=math.min(lowX,node.x); highX=math.max(highX,node.x); lowY=math.min(lowY,node.y); highY=math.max(highY,node.y) end
	self.centerX,self.centerY=(lowX+highX)/2,(lowY+highY)/2
	self.scale=math.min((self.width-30)/(highX-lowX),(self.height-30)/(highY-lowY))
end
function Canvas:Position(node)
	return self.width/2+(node.x-self.centerX)*self.scale,self.height/2+(node.y-self.centerY)*self.scale
end
function Canvas:IsMouseOver() return self:IsShown() and self:IsMouseInBounds() end
function Canvas:Draw()
	local x,y=self:GetPos()
	local cursorX,cursorY=GetCursorPos()
	if self.drag then
		self.centerX=self.drag.centerX-(cursorX-self.drag.x)/self.scale
		self.centerY=self.drag.centerY-(cursorY-self.drag.y)/self.scale
	end
	SetViewport(x,y,self.width,self.height)
	SetDrawColor(0.035,0.045,0.065); DrawImage(nil,0,0,self.width,self.height)
	local allocated={[self.tree.start]=true}
	local avoided={}; for _,id in ipairs(self.avoided and self.avoided() or {}) do avoided[id]=true end
	for _,id in ipairs(self.selected().nodes) do allocated[id]=true end
	for id,node in pairs(self.tree.nodes) do
		local a,b=self:Position(node)
		for _,other in ipairs(node.links) do if id < other then
			local c,d=self:Position(self.tree.nodes[other])
			if allocated[id] and allocated[other] then SetDrawColor(0.75,0.61,0.25) else SetDrawColor(0.18,0.22,0.29) end
			local dx,dy=c-a,d-b; local length=math.max(1,math.sqrt(dx*dx+dy*dy)); local ox,oy=-dy/length,dx/length
			DrawImageQuad(nil,a+ox,b+oy,c+ox,d+oy,c-ox,d-oy,a-ox,b-oy)
		end end
	end
	self.hover=nil; local distance=81
	for id,node in pairs(self.tree.nodes) do
		local a,b=self:Position(node)
		local r=node.kind == "keystone" and 5 or node.kind == "notable" and 4 or 2
		if avoided[id] then SetDrawColor(1,0.25,0.25) elseif allocated[id] then SetDrawColor(1,0.78,0.3) elseif node.kind == "keystone" then SetDrawColor(0.65,0.44,0.9) else SetDrawColor(0.45,0.56,0.7) end
		if self.focus == id then SetDrawColor(0.3,1,0.85); r=r+2 end
		DrawImage(nil,a-r,b-r,r*2,r*2)
		local dist=(cursorX-x-a)^2+(cursorY-y-b)^2
		if self:IsMouseOver() and dist < distance then self.hover=id; distance=dist end
	end
	SetViewport()
end
function Canvas:OnKeyDown(key)
	if not self:IsMouseOver() then return end
	if key == "LEFTBUTTON" and self.hover then self.focus=self.hover; self.onSelect(self.hover)
	elseif key == "LEFTBUTTON" or key == "RIGHTBUTTON" then
		local x,y=GetCursorPos(); self.drag={x=x,y=y,centerX=self.centerX,centerY=self.centerY}; return self
	end
end
function Canvas:OnKeyUp(key)
	if key == "WHEELUP" or key == "WHEELDOWN" then
		local old=self.scale
		self.scale=key == "WHEELUP" and math.min(0.8,old*1.25) or math.max(0.008,old/1.25)
		local x,y=self:GetPos(); local cursorX,cursorY=GetCursorPos()
		self.centerX=self.centerX+(cursorX-x-self.width/2)*(1/old-1/self.scale)
		self.centerY=self.centerY+(cursorY-y-self.height/2)*(1/old-1/self.scale)
	else self.drag=nil end
end
function Canvas:OnFocusLost() self.drag=nil end

function Panel.Open(build,source)
	local store=build.savers.AtlasPlans
	local version=(build.spec.treeVersion or ""):match("3_27") and "3.27.0" or "3.29.1"
	local draft=copyTable(source or store.plans[1] or {id="atlas-"..require("sha1")(tostring({})..os.time()):sub(1,12),title="New Atlas plan",version=version,budget=atlas.tree(version).maxPoints,nodes={},notes=""})
	local width=math.min(1040,main.screenW-40); local height=math.min(760,main.screenH-50)
	local graphWidth=width-342; local graphHeight=height-260; local side=graphWidth+30
	local controls,undo,avoided={},{},{}
	local function current()
		local result=copyTable(draft); result.title=controls.title.buf; result.budget=assert(tonumber(controls.budget.buf),"Enter a point budget"); result.notes=controls.notes.buf
		return atlas.validate(result)
	end
	local function refresh(id)
		if controls.canvas.tree.version ~= draft.version then
			controls.canvas.tree=atlas.tree(draft.version); controls.canvas:Fit(); avoided={}
			controls.results:SetList({}); controls.matchCount.label="Search matches names and stat text"
			controls.avoid.label="Avoid selected"
		end
		if not controls.canvas.tree.nodes[controls.canvas.focus] then controls.canvas.focus=nil end
		controls.version:SelByValue(draft.version)
		local report=atlas.report(draft)
		controls.status.label=string.format("%s Standard | %d / %d points%s | %d remaining",draft.version,report.used,report.budget,report.bonus > 0 and " + "..report.bonus.." granted" or "",report.remaining)
		local node=atlas.tree(draft.version).nodes[id or controls.canvas.focus]
		local lines={node and node.name or "Select a node on the tree or search.",node and "#"..node.id.." | "..node.kind or "Gold: allocated | Purple: keystone"}
		if node then for _,stat in ipairs(node.stats) do lines[#lines+1]=stat end end
		controls.details.list=rows(lines,35)
	end
	controls.title=edit(16,30,graphWidth-130,24,draft.title,"Plan name",120)
	controls.budget=edit(graphWidth-100,30,116,24,tostring(draft.budget),"Point budget",3)
	controls.version=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{side,30,294,24},atlas.versions,function(_,value)
		if value ~= draft.version then
			controls.version:SelByValue(draft.version)
			local replacement={id=draft.id,title=controls.title.buf,version=value,budget=atlas.tree(value).maxPoints,nodes={},notes=controls.notes.buf}
			main:OpenConfirmPopup("Change Atlas version","Changing versions starts an empty draft. Saved plans are kept.","Change",function() main:ClosePopup(); Panel.Open(build,replacement) end)
		end
	end)
	controls.version:SelByValue(draft.version)
	controls.canvas=new("AtlasTreeCanvas"):AtlasTreeCanvas({16,100,graphWidth,graphHeight},atlas.tree(draft.version),function() return draft end,function(id) refresh(id) end)
	controls.canvas.avoided=function() return avoided end
	controls.status=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,70,0,14},"")
	controls.search=edit(side,100,214,24,"","Search nodes or stats",160)
	controls.find=button(side+222,100,72,"Find",function()
		local result=atlas.search(draft.version,controls.search.buf,100); local list={}
		for _,node in ipairs(result.matches) do list[#list+1]={label=node.name.." (#"..node.id..")",val=node.id} end
		controls.results:SetList(list); controls.results.selIndex=1
		if list[1] then controls.results.selFunc(1,list[1]) end
		controls.matchCount.label=tostring(result.total).." matches; showing up to 100"
	end)
	controls.results=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{side,136,294,24},{},function(_,value)
		controls.canvas.focus=value.val; local node=atlas.tree(draft.version).nodes[value.val]
		controls.canvas.centerX,controls.canvas.centerY=node.x,node.y
		controls.canvas.scale=math.max(controls.canvas.scale,0.12); refresh(value.val)
	end)
	controls.matchCount=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{side,172,0,14},"Search matches names and stat text")
	controls.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{side,200,294,math.max(100,graphHeight-160)},nil,{})
	local function syncEditors()
		controls.title:SetText(draft.title); controls.budget:SetText(tostring(draft.budget)); controls.notes:SetText(draft.notes)
	end
	local function change(nextPlan) undo[#undo+1]=copyTable(draft); if #undo > 40 then table.remove(undo,1) end; draft=nextPlan; syncEditors(); refresh() end
	controls.allocate=button(side,height-208,140,"Connect selected",function() assert(controls.canvas.focus,"Select a node first"); change(atlas.connect(current(),{controls.canvas.focus},avoided)) end)
	controls.remove=button(side+154,height-208,140,"Remove branch",function() assert(controls.canvas.focus,"Select a node first"); change(atlas.remove(current(),controls.canvas.focus)) end)
	controls.undo=button(16,height-148,90,"Undo",function() assert(#undo > 0,"No changes to undo"); draft=table.remove(undo); syncEditors(); refresh() end)
	controls.fit=button(118,height-148,90,"Fit tree",function() controls.canvas:Fit() end)
	controls.help=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,height-184,0,14},"Wheel: zoom | Drag: pan | Remove prunes disconnected nodes")
	controls.avoid=button(side,height-176,140,"Avoid selected",function()
		local id=assert(controls.canvas.focus,"Select a node first"); local tree=atlas.tree(draft.version)
		assert(id ~= tree.start,"Cannot avoid the start")
		for _,allocated in ipairs(draft.nodes) do assert(id ~= allocated,"Remove this node before avoiding it") end
		for _,other in ipairs(avoided) do if id == other then return end end
		avoided[#avoided+1]=id; controls.avoid.label="Avoid selected ("..#avoided..")"
	end)
	controls.clearAvoid=button(side+154,height-176,140,"Clear avoided",function() avoided={}; controls.avoid.label="Avoid selected" end)
	controls.notes=edit(16,height-110,width-32,48,draft.notes,"Farming goals, maps, scarabs and strategy notes",8000)
	controls.stats=button(220,height-148,120,"Stats",function()
		local report=atlas.report(current()); local lines={string.format("%d allocated | %d small | %d notables | %d keystones | %d gateways",report.used,report.counts.small,report.counts.notable,report.counts.keystone,report.counts.gateway),"Repeated lines are counts, not effective combined values."}
		lines[#lines+1]="Keystones: "..(#report.keystones > 0 and table.concat(report.keystones,", ") or "none")
		lines[#lines+1]="Notables: "..(#report.notables > 0 and table.concat(report.notables,", ") or "none")
		for _,entry in ipairs(report.stats) do lines[#lines+1]=entry.count.."x "..entry.text end
		for _,line in ipairs(report.limitations) do lines[#lines+1]=line end
		local panel={details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,30,828,480},nil,rows(lines,95))}
		panel.close=button(728,524,116,"Close",function() main:ClosePopup() end); main:OpenPopup(860,568,"Atlas stat summary",panel,nil,nil,"close")
	end)
	controls.copy=button(352,height-148,120,"Copy plan",function() Copy(atlas.export(current())) end)
	controls.import=button(484,height-148,120,"Paste plan",function() change(atlas.import(Paste(),draft.version,draft.id,controls.title.buf,tonumber(controls.budget.buf))); avoided={}; controls.avoid.label="Avoid selected"; controls.budget:SetText(tostring(draft.budget)); controls.version:SelByValue(draft.version); controls.canvas.tree=atlas.tree(draft.version); controls.canvas:Fit() end)
	controls.url=button(616,height-148,120,"Official link",function() Copy(atlas.url(current())); main:OpenMessagePopup("Atlas link copied","Official URLs do not carry patch versions. Use Copy plan to preserve the exact version.") end)
	controls.keep=button(16,height-42,160,"Keep plan in build",function() store:Upsert(current()); main:ClosePopup() end)
	controls.library=button(188,height-42,120,"Saved plans",function() Panel.Library(build) end)
	controls.new=button(320,height-42,120,"New plan",function() Panel.Open(build,{id="atlas-"..require("sha1")(tostring({})..os.time()):sub(1,12),title="New Atlas plan",version=draft.version,budget=atlas.tree(draft.version).maxPoints,nodes={},notes=""}) end)
	controls.close=button(width-132,height-42,116,"Close",function() main:ClosePopup() end)
	refresh(); main:OpenPopup(width,height,"Atlas planner - Keep plan, then Save the build to persist",controls,nil,nil,"close")
	return controls
end
function Panel.Library(build)
	local store=build.savers.AtlasPlans; local controls,list={},{}
	for _,plan in ipairs(store.plans) do list[#list+1]={label=plan.title.." ["..plan.version.."]",val=plan.id} end
	controls.plans=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,32,568,24},list)
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,76,0,14},store.warning or "Up to eight plans per build. Use New plan for a separate strategy.")
	local function selected() local choice=controls.plans:GetSelValue(); for _,plan in ipairs(store.plans) do if choice and plan.id == choice.val then return plan end end; error("Choose a saved plan") end
	controls.open=button(16,112,160,"Open plan",function() local plan=selected(); main:ClosePopup(); Panel.Open(build,plan) end)
	controls.delete=button(188,112,160,"Delete plan",function() local plan=selected(); store:Remove(plan.id); main:ClosePopup(); Panel.Library(build) end)
	controls.close=button(468,160,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(600,204,"Saved Atlas plans",controls,nil,nil,"close")
end
return Panel
