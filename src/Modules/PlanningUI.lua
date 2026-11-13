-- Shared native planning styles and pixel-measured text wrapping.
local M={anchor={"TOPLEFT",nil,"TOPLEFT"}}
local states=setmetatable({},{__mode="k"})
function M.size(size) return math.floor(math.max(14,size or 16)*(main and main.planningTextLarge and 1.125 or 1)) end
function M.fit(text,width,size)
	text=tostring(text);if DrawStringWidth(size or 15,"VAR",text)<=width then return text end
	while #text>0 and DrawStringWidth(size or 15,"VAR",text.."...")>width do text=text:sub(1,-2) end;return text.."..."
end
function M.errorText(value)
	local fallback="Unable to complete this action."
	if value==nil then return fallback end
	local line=tostring(value):match("^[^\r\n]+")
	if not line or not line:match("%S") then return fallback end
	while true do
		local before=line
		line=line:gsub("^%[string \".-\"%]:%d+:%s*","",1)
		local path=line:match("^(.-%.lua):%d+:%s*")
		if path and (path:match("^/") or path:match("^%a:[/\\]") or path:match("^[@%w_.%-]+[/\\]") or path:match("^[@%w_.%-]+%.lua$")) then
			line=line:gsub("^.-%.lua:%d+:%s*","",1)
		end
		if line==before then break end
	end
	return line:match("%S") and line or fallback
end
function M.draft(build,kind) states[build]=states[build] or {drafts={}};states[build].drafts[kind]=true end
function M.kept(build,kind) states[build]=states[build] or {drafts={}};states[build].drafts[kind]=nil;states[build].kept=true end
function M.discard(build,kind) if states[build] then states[build].drafts[kind]=nil end end
function M.saved(build) states[build]=states[build] or {drafts={}};states[build].saved=true;states[build].kept=nil end
function M.saveStatus(build)
	local state=states[build]
	if state and next(state.drafts) then return "Working draft | Keep to include in build" end
	if build.modFlag or build.unsaved then return state and state.kept and "Kept in build | Save needed" or "Build changes | Save needed" end
	return state and state.saved and "Build saved" or "No pending build changes"
end
function M.capture(controls)
	local result={scrolls={}}
	for key,control in pairs(controls) do if control.controls and control.controls.scrollBar then result.scrolls[key]=control.controls.scrollBar.offset end;if control.hasFocus then result.focus=key end end
	return result
end
function M.restore(host,state)
	if not state then return end
	for key,offset in pairs(state.scrolls or {}) do local control=host.controls[key];if control and control.controls and control.controls.scrollBar then control.controls.scrollBar.offset=offset end end
	local focus=host.controls[state.focus];if focus and focus:IsShown() and focus:IsEnabled() then host:SelectControl(focus) end
end
function M.selectable(control,keyOf,choose,activate)
	control.planningFocusable=true
	local function select(row,activateNow)
		local key=row and keyOf(row);if key==nil then return end
		control.selectedKey=key
		for _,line in ipairs(control.list) do line.selected=keyOf(line)==key end
		choose(row)
		if activateNow and activate then activate(row) end
	end
	control.onClick=function(hit) if hit then select(hit.line,true) end end
	if activate then control.planningActivate=function() for _,row in ipairs(control.list) do if keyOf(row)==control.selectedKey then activate(row);return end end end end
	control.planningMove=function(delta)
		local rows,seen={},{};local index=0
		for _,row in ipairs(control.list) do local key=keyOf(row);if key~=nil and not seen[key] then seen[key]=true;rows[#rows+1]=row;if key==control.selectedKey then index=#rows end end end
		local row=rows[math.max(1,math.min(#rows,index+delta))];if not row then return end
		select(row)
		local y=0;for _,line in ipairs(control.list) do if keyOf(line)==keyOf(row) then break end;y=y+line.height end
		local _,height=control:GetSize();local scroll=control.controls.scrollBar
		if y<scroll.offset or y>scroll.offset+height-row.height-4 then scroll.offset=math.max(0,y-20) end
	end
	control.planningSelect=select
end
local conditionLabels
local function displayLine(line)
	for key,label in pairs(require("Modules.BuildInsights").labels) do line=line:gsub("%f[%w_]"..key.."%f[^%w_]",function() return label end) end
	local key=line:match("^Enabled condition: ([%w_]+)%.")
	if not key then return line end
	if not conditionLabels then
		conditionLabels={}
		for _,option in ipairs(require("Modules.ConfigOptions")) do
			if option.var and type(option.label)=="string" then conditionLabels[option.var]=StripEscapes(option.label) end
		end
	end
	local label=conditionLabels[key] or key:gsub("^condition",""):gsub("(%l)(%u)","%1 %2")
	return "Enabled setting: "..label.." Verify its source and uptime."
end
function M.rows(lines,width,size)
	local rows={};size=M.size(size or 16)
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=displayLine(StripEscapes(part))
			while DrawStringWidth(size,"VAR",part)>width do
				local low,high=1,#part
				while low<high do local mid=math.ceil((low+high)/2);if DrawStringWidth(size,"VAR",part:sub(1,mid))<=width then low=mid else high=mid-1 end end
				local cut=part:sub(1,low):match("^.*()%s") or low
				rows[#rows+1]={height=size+3,textSize=size,colorCodes.NORMAL..part:sub(1,cut)};part=part:sub(cut+1):gsub("^%s+","")
			end
			rows[#rows+1]={height=size+3,textSize=size,colorCodes.NORMAL..part}
		end
		if line=="" then rows[#rows+1]={height=10,""} end
	end
	return rows
end
function M.label(controls,key,x,y,label,size)
	size=M.size(size or 16);controls[key]=new("LabelControl"):LabelControl(M.anchor,{x,y,0,size},"^7"..label)
	return controls[key]
end
function M.description(controls,key,x,y,width,height,lines,size)
	local control=new("Control"):Control(M.anchor,{x,y,width,height});controls[key]=control
	control.list=M.rows(lines or {},width,size or 14)
	function control:Draw()
		local cx,cy=self:GetPos();local w,h=self:GetSize();SetViewport(cx,cy,w,h)
		local top=0;for _,row in ipairs(self.list) do if top+(row.textSize or 14)<=h then DrawString(0,top,"LEFT",row.textSize or 14,"VAR",row[1]) end;top=top+row.height end
		SetViewport()
	end
	return control
end
function M.card(controls,key,x,y,w,title,value,detail)
	local control=new("Control"):Control(M.anchor,{x,y,w,94});controls[key]=control
	function control:Draw()
		local cx,cy=self:GetPos()
		SetDrawColor(0.24,0.27,0.31);DrawImage(nil,cx,cy,w,94)
		SetDrawColor(0.075,0.085,0.1);DrawImage(nil,cx+1,cy+1,w-2,92)
		SetDrawColor(0.68,0.73,0.8);DrawString(cx+12,cy+10,"LEFT",14,"VAR",title)
		local text=tostring(type(value)=="function" and value() or value);local size=24;while size>14 and DrawStringWidth(size,"VAR",text)>w-24 do size=size-1 end
		SetDrawColor(0.94,0.83,0.57);DrawString(cx+12,cy+31,"LEFT",size,"VAR",text)
		local caption=detail or "";while #caption>0 and DrawStringWidth(14,"VAR",caption)>w-24 do caption=caption:sub(1,-2) end
		SetDrawColor(0.8,0.82,0.86);DrawString(cx+12,cy+67,"LEFT",14,"VAR",caption)
	end
	return control
end
function M.styleButton(control,kind)
	control.planningFocusable=true
	if not control.planningGuarded then
		local run=control.onClick
		control.onClick=function(...)
			local ok,result=pcall(run,...)
			if not ok then main:OpenMessagePopup("Planning tool",tostring(result):match("[^\n]+")) else return result end
		end
		control.planningGuarded=true
	end
	function control:Draw(viewport,noTooltip)
		local x,y=self:GetPos();local w,h=self:GetSize()
		local enabled=self:IsEnabled();local hover=self:IsMouseOver();local active=self:GetProperty("locked")
		local accent=kind=="primary" or active
		SetDrawColor(self.hasFocus and "^x83C8EF" or accent and "^xBAA06B" or hover and "^x647C96" or "^x344253");DrawImage(nil,x,y,w,h)
		SetDrawColor(accent and "^x302B20" or hover and "^x233142" or "^x151E29");DrawImage(nil,x+1,y+1,w-2,h-2)
		SetDrawColor(not enabled and "^x7C8792" or accent and "^xF3D89D" or "^xD5DEE8")
		local size=M.size(16);local label=self:GetProperty("label")
		while size>14 and DrawStringWidth(size,"VAR",label)>w-10 do size=size-1 end
		DrawString(x+w/2,y+math.floor((h-size)/2),"CENTER_X",size,"VAR",label)
		if hover and not noTooltip then SetDrawLayer(nil,100);self:DrawTooltip(x,y,w,h,viewport);SetDrawLayer(nil,0) end
	end
	return control
end
function M.style(controls,primary,skip)
	for key,control in pairs(controls) do
		if control.buf~=nil or control.selIndex then control.planningTextSize=M.size(16) end
		if control.label and not control.Click and not control.planningLabelDraw then
			local draw=control.Draw;function control:Draw(...) SetDrawColor("^xC2CDD9");draw(self,...) end;control.planningLabelDraw=true
		end
		if control.buf~=nil or control.selIndex or control.planningFocusable then
			control.planningFocusable=true
			if not control.planningFocusDraw then
				local draw=control.Draw
				function control:Draw(...)
					draw(self,...)
					if self.hasFocus then local x,y=self:GetPos();local w,h=self:GetSize();SetDrawColor("^x83C8EF");DrawImage(nil,x,y,w,1);DrawImage(nil,x,y,1,h);DrawImage(nil,x+w-1,y,1,h);DrawImage(nil,x,y+h-1,w,1) end
				end
				control.planningFocusDraw=true
			end
		end
		if control.Click and control.onClick and not (skip and skip[key]) then M.styleButton(control,primary and primary[key] and "primary") end
		if control.columns and control.list then control.borderColor="^x344253";control.backgroundColor="^x111923" end
	end
end
-- Opt-in keyboard handling, so stock PoB controls keep their existing behavior.
function M.keyboard(host,events)
	local enabled=false;for _,control in pairs(host.controls) do if control.planningFocusable then enabled=true;break end end
	if not enabled then return end
	if host.selControl and not host.selControl:IsShown() then host:SelectControl(nil) end
	for i,event in pairs(events) do if event.type=="KeyDown" then
		if (event.key=="UP" or event.key=="DOWN") and host.selControl and host.selControl.planningMove then
			host.selControl.planningMove(event.key=="UP" and -1 or 1);event.type="PlanningHandled"
		elseif event.key=="TAB" then
			if host.selControl and host.selControl.dropped then host.selControl.dropped=false end
			local order={};for key,control in pairs(host.controls) do if control.planningFocusable and control:IsShown() and control:IsEnabled() then order[#order+1]={key=key,control=control} end end
			table.sort(order,function(a,b) local ax,ay=a.control:GetPos();local bx,by=b.control:GetPos();if ay~=by then return ay<by elseif ax~=bx then return ax<bx else return a.key<b.key end end)
			local index=IsKeyDown("SHIFT") and 1 or 0;for n,entry in ipairs(order) do if entry.control==host.selControl then index=n end end
			if #order>0 then host:SelectControl(order[(index+(IsKeyDown("SHIFT") and -1 or 1)-1)%#order+1].control) end
			event.type="PlanningHandled"
		elseif (event.key=="SPACE" or event.key=="RETURN") and host.selControl and host.selControl.planningActivate then host.selControl.planningActivate();event.type="PlanningHandled"
		elseif event.key=="RETURN" and host.selControl and host.selControl.planningFocusable and host.selControl.Click then
			host.selControl:Click();event.type="PlanningHandled"
		elseif event.key=="RETURN" and host.selControl and host.selControl.planningFocusable and host.selControl.selIndex then
			host.selControl.dropped=not host.selControl.dropped;event.type="PlanningHandled"
		elseif event.key=="ESCAPE" then
			if host.selControl then host.selControl.dropped=false;host:SelectControl(nil);event.type="PlanningHandled"
			else for _,key in ipairs({"paletteBack","affixBack"}) do local back=host.controls[key];if back and back:IsShown() then back:Click();event.type="PlanningHandled";break end end end
		end
	elseif event.type=="KeyUp" and (event.key=="TAB" or event.key=="RETURN") then event.type="PlanningHandled" end end
end
function M.splitter(controls,key,x,y,height,resize)
	local control=new("Control"):Control(M.anchor,{x,y,10,height});controls[key]=control
	function control:IsMouseOver() return self:IsShown() and self:IsMouseInBounds() end
	function control:Draw()
		local cx,cy=self:GetPos();SetDrawColor(self.drag and "^x83C8EF" or "^x344253");DrawImage(nil,cx+4,cy,2,self.height)
		SetDrawColor("^x9BA9BA");for i=0,2 do DrawImage(nil,cx+2,cy+self.height/2+i*6,6,2) end
	end
	function control:OnKeyDown(key) if key=="LEFTBUTTON" then self.drag=select(1,GetCursorPos());return self end end
	function control:OnKeyUp(key)
		if key=="LEFTBUTTON" and self.drag then local cursor=GetCursorPos();local delta=cursor-self.drag;self.drag=nil;resize(delta) end
	end
	function control:OnFocusLost() self.drag=nil end
	return control
end
function M.rowSplitter(controls,key,x,y,width,resize)
	local control=new("Control"):Control(M.anchor,{x,y,width,10});controls[key]=control
	function control:IsMouseOver() return self:IsShown() and self:IsMouseInBounds() end
	function control:Draw() local cx,cy=self:GetPos();SetDrawColor(self.drag and "^x83C8EF" or "^x344253");DrawImage(nil,cx,cy+4,self.width,2);SetDrawColor("^x9BA9BA");for i=-1,1 do DrawImage(nil,cx+self.width/2+i*8,cy+2,3,6) end end
	function control:OnKeyDown(key) if key=="LEFTBUTTON" then self.drag=select(2,GetCursorPos());return self end end
	function control:OnKeyUp(key) if key=="LEFTBUTTON" and self.drag then local delta=select(2,GetCursorPos())-self.drag;self.drag=nil;resize(delta) end end
	function control:OnFocusLost() self.drag=nil end
	return control
end
function M.tabs(controls,selector,entries,x,y,width)
	selector.shown=false;selector.tabKeys={}
	local gap=6;local w=math.floor((width-gap*(#entries-1))/#entries)
	for i,entry in ipairs(entries) do
		local key,value,label=unpack(entry)
		local control=new("ButtonControl"):ButtonControl(M.anchor,{x+(i-1)*(w+gap),y,w,28},label,function() selector:SelByValue(value);if selector.selFunc then selector.selFunc() end end)
		control.locked=function() return selector:GetSelValue()==value end
		controls[key]=M.styleButton(control);selector.tabKeys[value]=key
	end
end
return M
