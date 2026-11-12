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
	function control:Draw(viewport,noTooltip)
		local x,y=self:GetPos();local w,h=self:GetSize()
		local enabled=self:IsEnabled();local hover=self:IsMouseOver();local active=self:GetProperty("locked")
		local accent=kind=="primary" or active
		SetDrawColor(accent and "^xBAA06B" or hover and "^x647C96" or "^x344253");DrawImage(nil,x,y,w,h)
		SetDrawColor(accent and "^x302B20" or hover and "^x233142" or "^x151E29");DrawImage(nil,x+1,y+1,w-2,h-2)
		SetDrawColor(not enabled and "^x7C8792" or accent and "^xF3D89D" or "^xD5DEE8")
		DrawString(x+w/2,y+math.floor((h-16)/2),"CENTER_X",16,"VAR",self:GetProperty("label"))
		if hover and not noTooltip then SetDrawLayer(nil,100);self:DrawTooltip(x,y,w,h,viewport);SetDrawLayer(nil,0) end
	end
	return control
end
function M.style(controls,primary,skip)
	for key,control in pairs(controls) do
		if control.Click and control.onClick and not (skip and skip[key]) then M.styleButton(control,primary and primary[key] and "primary") end
		if control.columns and control.list then control.borderColor="^x344253";control.backgroundColor="^x111923" end
	end
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
