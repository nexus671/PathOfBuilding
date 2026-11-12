-- Shared native planning styles and pixel-measured text wrapping.
local M={anchor={"TOPLEFT",nil,"TOPLEFT"}}
local conditionLabels
local function displayLine(line)
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
	local rows={};size=size or 16
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
	controls[key]=new("LabelControl"):LabelControl(M.anchor,{x,y,0,size or 16},"^7"..label)
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
		SetDrawColor(0.94,0.83,0.57);DrawString(cx+12,cy+31,"LEFT",24,"VAR",type(value)=="function" and value() or value)
		SetDrawColor(0.8,0.82,0.86);DrawString(cx+12,cy+67,"LEFT",14,"VAR",detail or "")
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
		DrawString(x+w/2,y+math.floor((h-16)/2),"CENTER_X",16,"VAR",self:GetProperty("label"))
		if hover and not noTooltip then SetDrawLayer(nil,100);self:DrawTooltip(x,y,w,h,viewport);SetDrawLayer(nil,0) end
	end
	return control
end
function M.style(controls,primary,skip)
	for key,control in pairs(controls) do
		if control.buf~=nil or control.selIndex then
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
		if event.key=="TAB" then
			if host.selControl and host.selControl.dropped then host.selControl.dropped=false end
			local order={};for key,control in pairs(host.controls) do if control.planningFocusable and control:IsShown() and control:IsEnabled() then order[#order+1]={key=key,control=control} end end
			table.sort(order,function(a,b) local ax,ay=a.control:GetPos();local bx,by=b.control:GetPos();if ay~=by then return ay<by elseif ax~=bx then return ax<bx else return a.key<b.key end end)
			local index=IsKeyDown("SHIFT") and 1 or 0;for n,entry in ipairs(order) do if entry.control==host.selControl then index=n end end
			if #order>0 then host:SelectControl(order[(index+(IsKeyDown("SHIFT") and -1 or 1)-1)%#order+1].control) end
			event.type="PlanningHandled"
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
