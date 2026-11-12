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
return M
