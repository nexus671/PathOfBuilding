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
	return new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",prompt,h>24 and "^%C\t\n" or nil,limit,nil,h > 24 and 16 or nil)
end
local ui=require("Modules.PlanningUI")
local rows=ui.rows
local Canvas=newClass("AtlasTreeCanvas","Control","TooltipHost")
function Canvas:AtlasTreeCanvas(rect,tree,selected,onSelect)
	self:Control({"TOPLEFT",nil,"TOPLEFT"},rect)
	self:TooltipHost();self.art=require("Modules.AtlasArt").load(tree.version)
	self.tree,self.selected,self.onSelect=tree,selected,onSelect
	self:Fit();self:StartView()
	return self
end
function Canvas:Fit()
	local lowX,highX,lowY,highY=math.huge,-math.huge,math.huge,-math.huge
	for _,node in pairs(self.tree.nodes) do lowX=math.min(lowX,node.x); highX=math.max(highX,node.x); lowY=math.min(lowY,node.y); highY=math.max(highY,node.y) end
	self.centerX,self.centerY=(lowX+highX)/2,(lowY+highY)/2
	self.scale=math.min((self.width-30)/(highX-lowX),(self.height-30)/(highY-lowY))
end
function Canvas:StartView()
	local start=self.tree.nodes[self.tree.start]
	self.scale=0.16;self.centerX=start.x;self.centerY=start.y-self.height/self.scale*0.28
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
	local bounds=self.tree.bounds
	if bounds then
		local centerX,centerY=self:Position({x=(bounds[1]+bounds[3])/2,y=(bounds[2]+bounds[4])/2})
		SetDrawColor(0.8,0.8,0.8)
		local sheet=self.art.sprites.atlasBackground;local rect=sheet.coords.AtlasPassiveBackground
		self.art:draw("atlasBackground","AtlasPassiveBackground",centerX,centerY,(bounds[3]-bounds[1])*self.scale/rect.w)
	end
	for _,group in ipairs(self.tree.groups or {}) do
		local a,b=self:Position(group)
		local rect=self.art.sprites.groupBackground.coords[group.background]
		if rect and a+rect.w*self.scale>=0 and b+rect.h*self.scale>=0 and a-rect.w*self.scale<=self.width and b-rect.h*self.scale<=self.height then
			SetDrawColor(0.8,0.8,0.8);self.art:draw("groupBackground",group.background,a,b,self.scale*2)
		end
	end
	for _,node in ipairs(self.tree.decorations or {}) do
		local a,b=self:Position(node);SetDrawColor(0.85,0.85,0.85);self.art:draw("mastery",node.icon,a,b,self.scale*2)
	end
	local allocated={[self.tree.start]=true}
	local avoided={}; for _,id in ipairs(self.avoided and self.avoided() or {}) do avoided[id]=true end
	for _,id in ipairs(self.selected().nodes) do allocated[id]=true end
	local planned=copyTable(allocated);for id in pairs(self.preview or {}) do planned[id]=true end
	for id,node in pairs(self.tree.nodes) do
		local a,b=self:Position(node)
		for _,other in ipairs(node.links) do if id < other then
			local c,d=self:Position(self.tree.nodes[other])
			if allocated[id] and allocated[other] then SetDrawColor(0.75,0.61,0.25) elseif planned[id] and planned[other] then SetDrawColor(0.25,0.8,0.75) else SetDrawColor(0.18,0.22,0.29) end
			local dx,dy=c-a,d-b; local length=math.max(1,math.sqrt(dx*dx+dy*dy)); local ox,oy=-dy/length,dx/length
			if math.max(a,c)>=0 and math.min(a,c)<=self.width and math.max(b,d)>=0 and math.min(b,d)<=self.height then
				DrawImageQuad(nil,a+ox,b+oy,c+ox,d+oy,c-ox,d-oy,a-ox,b-oy)
			end
		end end
	end
	self.hover=nil; local distance=math.huge
	local margin=160*self.scale+4
	for id,node in pairs(self.tree.nodes) do
		local a,b=self:Position(node)
		local r=node.kind == "keystone" and 5 or node.kind == "notable" and 4 or 2
		if avoided[id] then SetDrawColor(1,0.25,0.25) elseif allocated[id] then SetDrawColor(1,0.78,0.3) elseif node.kind == "keystone" then SetDrawColor(0.65,0.44,0.9) else SetDrawColor(0.45,0.56,0.7) end
		if self.focus == id then SetDrawColor(0.3,1,0.85); r=r+2 end
		if a > -margin and b > -margin and a < self.width+margin and b < self.height+margin then
			local kind=node.kind == "gateway" and "wormhole" or node.kind == "small" and "normal" or node.kind
			local frame=node.kind == "gateway" and "WormholeFrame" or node.kind == "keystone" and "KeystoneFrame" or node.kind == "notable" and "NotableFrame" or "PSSkillFrame"
			local active=allocated[id]
			SetDrawColor(1,1,1);self.art:draw(kind..(active and "Active" or "Inactive"),node.icon or "Wormhole",a,b,self.scale*2)
			if node.kind == "small" then frame=active and "PSSkillFrameActive" or "PSSkillFrame" else frame=frame..(active and "Allocated" or "Unallocated") end
			SetDrawColor(avoided[id] and 1 or 0.9,avoided[id] and 0.25 or 0.9,avoided[id] and 0.25 or 0.9)
			local highlight=node.kind=="keystone" and "KeystoneFrameCanAllocate" or node.kind=="notable" and "NotableFrameCanAllocate" or node.kind=="gateway" and "WormholeFrameHighlight" or "PSSkillFrameHighlighted"
			self.art:draw("frame",(self.focus == id or self.preview and self.preview[id] or self.matches and self.matches[id]) and highlight or frame,a,b,self.scale*2)
			if id==self.tree.start then self.art:draw("startNode","AtlasPassiveSkillScreenStart",a,b,self.scale*2) end
		end
		local dist=(cursorX-x-a)^2+(cursorY-y-b)^2
		local radius=math.max(8,(node.kind=="keystone" and 68 or node.kind=="gateway" and 86 or node.kind=="notable" and 49 or 34)*self.scale)
		if self:IsMouseOver() and dist<=radius*radius and dist < distance then self.hover=id; distance=dist end
	end
	SetViewport()
	if self.hover then
		local node=self.tree.nodes[self.hover];self.tooltip:Clear();self.tooltip:AddLine(18,node.name)
		for _,stat in ipairs(node.stats) do self.tooltip:AddLine(14,stat) end
		self.tooltip:AddLine(14,"Double click to connect this node")
		SetDrawLayer(nil,100);self.tooltip:Draw(cursorX,cursorY,1,1,main.viewPort);SetDrawLayer(nil,0)
	end
end
function Canvas:OnKeyDown(key,doubleClick)
	if not self:IsMouseOver() then return end
	if key == "LEFTBUTTON" and self.hover then self.focus=self.hover; self.onSelect(self.hover);if doubleClick and self.onActivate then self.onActivate(self.hover) end
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

function Panel.Open(build,source,layout)
	local store=build.savers.AtlasPlans
	local version=(build.spec.treeVersion or ""):match("3_27") and "3.27.0" or "3.29.1"
	local draft=copyTable(source or store.plans[1] or {id="atlas-"..require("sha1")(tostring({})..os.time()):sub(1,12),title="New Atlas plan",version=version,budget=atlas.tree(version).maxPoints,nodes={},notes=""})
	local width=layout and layout.width or math.min(1180,main.screenW-40); local height=layout and layout.height or math.min(820,main.screenH-50)
	local graphWidth=width-308; local graphHeight=height-206; local side=graphWidth+32
	local controls,undo,avoided={},{},{}
	local pointUsage,routeAvailable
	local function current()
		local result=copyTable(draft); result.title=controls.title.buf; result.budget=assert(tonumber(controls.budget.buf),"Enter a point budget"); result.notes=controls.notes.buf
		return atlas.validate(result)
	end
	local function refresh(id)
		if controls.canvas.tree.version ~= draft.version then
			controls.canvas.tree=atlas.tree(draft.version);controls.canvas.art=require("Modules.AtlasArt").load(draft.version); controls.canvas:Fit(); avoided={}
			controls.results:SetList({}); controls.matchCount.label="Search names and modifiers"
			controls.avoid.label="Avoid selected"
		end
		if not controls.canvas.tree.nodes[controls.canvas.focus] then controls.canvas.focus=nil end
		controls.version:SelByValue(draft.version)
		local report=atlas.report(draft)
		local budget=tonumber(controls.budget.buf)
		if budget and budget==math.floor(budget) and budget>=0 and budget<=controls.canvas.tree.maxPoints then
			report.budget=budget;report.remaining=budget+report.bonus-report.used;pointUsage=report
			controls.status.label=string.format("%s%d / %d points%s | %s",report.remaining<0 and "^xE58F8F" or "^7",report.used,report.budget,report.bonus>0 and " + "..report.bonus.." granted" or "",report.remaining<0 and (-report.remaining).." over budget" or report.remaining.." left")
		else pointUsage=nil;controls.status.label="^xE58F8FEnter a budget from 0 to "..controls.canvas.tree.maxPoints end
		local node=atlas.tree(draft.version).nodes[id or controls.canvas.focus]
		local lines={node and node.name or "Select a node on the tree or search.",node and node.kind:gsub("^%l",string.upper) or "Search a mechanic, or select a node."}
		controls.canvas.preview={};routeAvailable=false
		if node then
			for _,stat in ipairs(node.stats) do lines[#lines+1]=stat end
			local allocated={[controls.canvas.tree.start]=true};for _,other in ipairs(draft.nodes) do allocated[other]=true end
			if not allocated[node.id] then
				local ok,plan=pcall(function() return atlas.connect(current(),{node.id},avoided) end)
				if ok then
					local cost=0;for _,other in ipairs(plan.nodes) do if not allocated[other] then controls.canvas.preview[other]=true;cost=cost+1 end end
					routeAvailable=true;controls.allocate.label="Connect +"..cost
					lines[#lines+1]="";lines[#lines+1]=cost.." new points to connect this node."
				else controls.allocate.label="No route";lines[#lines+1]="";lines[#lines+1]="No route within the point budget and avoided nodes." end
			else controls.allocate.label="Allocated" end
		else controls.allocate.label="Connect path" end
		controls.details.list=rows(lines,230)
	end
	controls.title=edit(16,30,graphWidth-130,24,draft.title,nil,120)
	ui.label(controls,"planLabel",16,10,"Plan name",13)
	ui.label(controls,"budgetLabel",graphWidth-100,10,"Point budget",13)
	controls.budget=edit(graphWidth-100,30,116,24,tostring(draft.budget),nil,3)
	controls.version=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{side,30,260,24},atlas.versions,function(_,value)
		if value ~= draft.version then
			controls.version:SelByValue(draft.version)
			local replacement={id=draft.id,title=controls.title.buf,version=value,budget=atlas.tree(value).maxPoints,nodes={},notes=controls.notes.buf}
			main:OpenConfirmPopup("Change Atlas version","Changing versions starts an empty draft. Saved plans are kept.","Change",function() if not layout then main:ClosePopup() end;Panel.Open(build,replacement,layout) end)
		end
	end)
	controls.version:SelByValue(draft.version)
	controls.canvas=new("AtlasTreeCanvas"):AtlasTreeCanvas({16,96,graphWidth,graphHeight},atlas.tree(draft.version),function() return draft end,function(id) refresh(id) end)
	controls.canvas.avoided=function() return avoided end
	controls.status=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,70,0,14},"")
	controls.search=edit(side,96,180,24,"",nil,160)
	controls.search.placeholder="Search nodes"
	local function findNodes(recenter)
		local result=atlas.search(draft.version,controls.search.buf,100);local list={};controls.canvas.matches={}
		for _,node in ipairs(result.matches) do list[#list+1]={label=node.name,val=node.id};if controls.search.buf~="" then controls.canvas.matches[node.id]=true end end
		controls.results:SetList(list);controls.results.selIndex=1
		if not recenter and controls.search.buf~="" and not controls.canvas.matches[controls.canvas.focus] then controls.canvas.focus=nil;refresh() end
		if recenter and list[1] then controls.results.selFunc(1,list[1]) end
		controls.matchCount.label="^7"..result.total..(result.total==1 and " match" or " matches")
	end
	controls.find=button(side+188,96,72,"Go",function() findNodes(true) end)
	controls.search.changeFunc=function() findNodes(false) end
	controls.search.enterFunc=function() findNodes(true) end
	controls.search.disableCol="^x8797A8"
	controls.results=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{side,130,260,24},{},function(_,value)
		controls.canvas.focus=value.val; local node=atlas.tree(draft.version).nodes[value.val]
		controls.canvas.centerX,controls.canvas.centerY=node.x,node.y
		controls.canvas.scale=math.max(controls.canvas.scale,0.12); refresh(value.val)
	end)
	controls.matchCount=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{side,164,0,14},"Search names and modifiers")
	controls.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{side,190,260,height-390},nil,{})
	local function syncEditors()
		controls.title:SetText(draft.title); controls.budget:SetText(tostring(draft.budget)); controls.notes:SetText(draft.notes)
	end
	local function change(nextPlan) undo[#undo+1]=copyTable(draft); if #undo > 40 then table.remove(undo,1) end; draft=nextPlan; syncEditors(); refresh() end
	controls.allocate=button(side,height-188,124,"Connect path",function() assert(controls.canvas.focus,"Select a node first"); change(atlas.connect(current(),{controls.canvas.focus},avoided)) end)
	controls.remove=button(side+136,height-188,124,"Remove branch",function() assert(controls.canvas.focus,"Select a node first"); change(atlas.remove(current(),controls.canvas.focus)) end)
	controls.undo=button(16,height-86,90,"Undo",function() assert(#undo > 0,"No changes to undo"); draft=table.remove(undo); syncEditors(); refresh() end)
	controls.fit=button(118,height-86,90,"Fit tree",function() controls.canvas:Fit() end)
	controls.help=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,height-106,0,14},"^7Wheel: zoom | Drag: pan | Double click: connect")
	controls.avoid=button(side,height-156,124,"Avoid selected",function()
		local id=assert(controls.canvas.focus,"Select a node first"); local tree=atlas.tree(draft.version)
		assert(id ~= tree.start,"Cannot avoid the start")
		for _,allocated in ipairs(draft.nodes) do assert(id ~= allocated,"Remove this node before avoiding it") end
		for _,other in ipairs(avoided) do if id == other then return end end
		avoided[#avoided+1]=id; controls.avoid.label="Avoid ("..#avoided..")";refresh()
	end)
	controls.clearAvoid=button(side+136,height-156,124,"Clear avoided",function() avoided={}; controls.avoid.label="Avoid selected";refresh() end)
	controls.notes=edit(16,110,width-32,height-250,draft.notes,nil,8000)
	controls.stats=button(side,height-124,260,"Allocated stats",function()
		local report=atlas.report(current()); local lines={string.format("%d allocated | %d small | %d notables | %d keystones | %d gateways",report.used,report.counts.small,report.counts.notable,report.counts.keystone,report.counts.gateway),"Repeated lines are counts, not effective combined values."}
		lines[#lines+1]="Keystones: "..(#report.keystones > 0 and table.concat(report.keystones,", ") or "none")
		lines[#lines+1]="Notables: "..(#report.notables > 0 and table.concat(report.notables,", ") or "none")
		for _,entry in ipairs(report.stats) do lines[#lines+1]=entry.count.."x "..entry.text end
		for _,line in ipairs(report.limitations) do lines[#lines+1]=line end
		local panel={details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,30,828,480},nil,rows(lines,798))}
		panel.close=button(728,524,116,"Close",function() main:ClosePopup() end); main:OpenPopup(860,568,"Atlas stat summary",panel,nil,nil,"close")
	end)
	controls.copy=button(16,height-104,120,"Copy plan",function() Copy(atlas.export(current())) end)
	controls.import=button(148,height-104,120,"Paste plan",function() change(atlas.import(Paste(),draft.version,draft.id,controls.title.buf,tonumber(controls.budget.buf))); avoided={}; controls.avoid.label="Avoid selected"; controls.budget:SetText(tostring(draft.budget)); controls.version:SelByValue(draft.version); controls.canvas.tree=atlas.tree(draft.version);controls.canvas.art=require("Modules.AtlasArt").load(draft.version); controls.canvas:Fit() end)
	controls.url=button(280,height-104,120,"Official link",function() Copy(atlas.url(current())); main:OpenMessagePopup("Atlas link copied","Official URLs do not carry patch versions. Use Copy plan to preserve the exact version.") end)
	controls.keep=button(16,height-42,160,"Keep plan",function() store:Upsert(current());if layout then controls.status.label="^7Plan kept. Save the build to persist it." else main:ClosePopup() end end)
	controls.library=button(188,height-42,120,"Saved plans",function() Panel.Library(build,layout) end)
	controls.new=button(320,height-42,120,"New plan",function() if not layout then main:ClosePopup() end;Panel.Open(build,{id="atlas-"..require("sha1")(tostring({})..os.time()):sub(1,12),title="New Atlas plan",version=draft.version,budget=atlas.tree(draft.version).maxPoints,nodes={},notes=""},layout) end)
	controls.close=button(width-132,height-42,116,"Close",function() main:ClosePopup() end)
	controls.page=new("DropDownControl"):DropDownControl(ui.anchor,{side,64,260,24},{"Tree","Notes & sharing"})
	ui.label(controls,"notesLabel",16,88,"Farming goals, maps, scarabs and strategy notes")
	for _,key in ipairs({"canvas","search","find","results","matchCount","details","allocate","remove","undo","fit","help","avoid","clearAvoid","stats"}) do
		controls[key].shown=function() return controls.page:GetSelValue()=="Tree" end
	end
	for _,key in ipairs({"notes","notesLabel","copy","import","url"}) do controls[key].shown=function() return controls.page:GetSelValue()=="Notes & sharing" end end
	controls.canvas.onActivate=function() if controls.remove:IsEnabled() then controls.remove:Click() else controls.allocate:Click() end end
	controls.undo.enabled=function() return #undo>0 end
	local function allocatedFocus()
		for _,id in ipairs(draft.nodes) do if id==controls.canvas.focus then return true end end
		return false
	end
	controls.allocate.enabled=function() return routeAvailable end
	controls.remove.enabled=allocatedFocus
	controls.avoid.enabled=function() return controls.canvas.focus~=nil and controls.canvas.focus~=controls.canvas.tree.start and not allocatedFocus() end
	controls.clearAvoid.enabled=function() return #avoided>0 end
	if layout then
		controls.close.shown=false
		layout.viewState=function() return {centerX=controls.canvas.centerX,centerY=controls.canvas.centerY,scale=controls.canvas.scale,focus=controls.canvas.focus,page=controls.page:GetSelValue(),avoided=copyTable(avoided),undo=copyTable(undo)} end
		layout.snapshot=function() local result=copyTable(draft);result.title=controls.title.buf;result.notes=controls.notes.buf;result.budget=tonumber(controls.budget.buf) or draft.budget;return result end
	end
	if layout and layout.restore then
		local view=layout.restore;layout.restore=nil
		controls.canvas.centerX,controls.canvas.centerY,controls.canvas.scale,controls.canvas.focus=view.centerX,view.centerY,view.scale,view.focus
		controls.page:SelByValue(view.page);avoided=view.avoided;undo=view.undo
	end
	controls.pointBar=new("Control"):Control(ui.anchor,{16,85,graphWidth,3})
	function controls.pointBar:Draw()
		local x,y=self:GetPos();SetDrawColor("^x263343");DrawImage(nil,x,y,graphWidth,3)
		if pointUsage and pointUsage.used>0 then SetDrawColor("^xC8A569");DrawImage(nil,x,y,graphWidth*math.min(1,pointUsage.used/math.max(1,pointUsage.budget+pointUsage.bonus)),3) end
	end
	ui.tabs(controls,controls.page,{{"tab_tree","Tree","Tree"},{"tab_notes","Notes & sharing","Plan & notes"}},side,64,260)
	controls.budget.changeFunc=function() refresh() end
	ui.style(controls,{allocate=true,keep=true})
	for _,control in pairs(controls) do control.layoutAudit="atlas" end
	refresh()
	if layout then layout.mount(width,height,"Atlas planner",controls) else main:OpenPopup(width,height,"Atlas planner",controls,nil,nil,"close") end
	return controls
end
function Panel.Library(build,layout)
	local store=build.savers.AtlasPlans; local controls,list={},{}
	for _,plan in ipairs(store.plans) do list[#list+1]={label=plan.title.." ["..plan.version.."]",val=plan.id} end
	controls.plans=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,32,568,24},list)
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,76,0,14},"^7"..(store.warning or "Keep up to eight farming strategies in this build."))
	local function selected() local choice=controls.plans:GetSelValue(); for _,plan in ipairs(store.plans) do if choice and plan.id == choice.val then return plan end end; error("Choose a saved plan") end
	controls.open=button(16,112,160,"Open plan",function() local plan=selected(); main:ClosePopup(); Panel.Open(build,plan,layout) end)
	controls.delete=button(188,112,160,"Delete plan",function() local plan=selected(); store:Remove(plan.id); main:ClosePopup(); Panel.Library(build,layout) end)
	controls.open.enabled=#list>0;controls.delete.enabled=#list>0
	controls.close=button(468,160,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(600,204,"Saved Atlas plans",controls,nil,nil,"close")
end
return Panel
