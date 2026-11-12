-- Search and toggle prerequisites by name; exclude descendants that would form cycles.
local ui=require("Modules.PlanningUI")
local M={}
function M.Open(data,id,selected,keep)
	local blocked=require("Modules.BuildJourney").dependents(data,id)
	local chosen={};for _,dep in ipairs(selected) do chosen[dep]=true end
	local c={};local w,h=math.min(780,main.screenW-40),math.min(560,main.screenH-64)
	c.search=new("EditControl"):EditControl(ui.anchor,{16,28,w-32,28},nil,"Search milestones",nil,160)
	c.entries=new("TextListControl"):TextListControl(ui.anchor,{16,70,w-32,h-206},nil,{})
	local function refresh()
		local rows={};local count=0
		for _,entry in ipairs(data.milestones) do if not blocked[entry.id] and entry.title:lower():find(c.search.buf:lower(),1,true) then
			for _,row in ipairs(ui.rows({(chosen[entry.id] and "[x] " or "[ ] ")..entry.title..(entry.done and " (completed)" or "")},w-64)) do row.id=entry.id;rows[#rows+1]=row end
		end;if chosen[entry.id] then count=count+1 end end
		c.entries.list=rows;c.count.label="^7"..count.." prerequisites selected | Click a milestone to toggle"
	end
	c.entries.onClick=function(row) if row and row.line then local key=row.line.id;chosen[key]=not chosen[key] or nil;refresh() end end
	c.search.changeFunc=refresh
	ui.label(c,"count",16,h-90,"",14)
	ui.description(c,"hint",16,h-124,w-32,28,{"This milestone and its dependent milestones are excluded to prevent cycles."},14)
	c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,h-48,140,28},"Keep selection",function() local result={};for _,entry in ipairs(data.milestones) do if chosen[entry.id] then result[#result+1]=entry.id end end;keep(result);main:ClosePopup() end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-48,140,28},"Cancel",function() main:ClosePopup() end)
	for _,control in pairs(c) do control.layoutAudit="journey-prerequisites" end
	refresh();ui.style(c,{keep=true});main:OpenPopup(w,h,"Prerequisites",c,nil,"search","close")
end
return M
