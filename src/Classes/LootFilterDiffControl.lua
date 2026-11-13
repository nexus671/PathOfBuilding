local ui=require("Modules.PlanningUI")
local filters=require("Modules.LootFilters")
local diff=require("Modules.LootFilterDiff")
local M={}
function M.Open(before,after)
	local c={};local w,h=math.min(1080,main.screenW-40),math.min(720,main.screenH-60)
	local previous,current,review,problems
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	c.content=new("DropDownControl"):DropDownControl(ui.anchor,{16,28,240,28},{"Compiled filter","Original base text"})
	c.view=new("DropDownControl"):DropDownControl(ui.anchor,{272,28,180,28},{"Changes","All lines","Before text","After text"})
	c.search=new("EditControl"):EditControl(ui.anchor,{468,28,w-484,28},"","Find text",nil,160)
	ui.label(c,"summary",16,76,"",14)
	ui.description(c,"help",16,100,w-32,36,{(before and "Before is kept in this build; after is the working draft." or "No kept profile: before is empty; after is the working draft.").." Line endings are normalized for review. Long lines are abbreviated here; copied sources and reports retain full text."},13)
	c.lines=new("TextListControl"):TextListControl(ui.anchor,{16,152,w-32,h-262},nil,{})
	ui.label(c,"status",16,h-90,"",13)
	local function refresh()
		local rows={};local mode=c.view:GetSelValue();local query=c.search.buf:lower();local shown=0
		local function add(row)
			if not row.heading and not row.text:lower():find(query,1,true) then return end
			local label=row.text;if #label>1000 then label=label:sub(1,1000).." ... [full line available in Copy]" end
			if not row.heading then label=string.format("%s | %s | %s %s",row.oldLine or "-",row.newLine or "-",row.kind,label);shown=shown+1 end
			local colour=row.heading and "^xE6C588" or row.kind=="+" and "^xA7D8A7" or row.kind=="-" and "^xEDABA7" or "^xC9D4D9"
			for _,line in ipairs(ui.rows({label},w-60,13)) do line[1]=colour..StripEscapes(line[1]);rows[#rows+1]=line end
		end
		if not review then rows=ui.rows(problems or {"Choose a comparison."},w-60,14)
		elseif mode=="Changes" then for _,row in ipairs(diff.visible(review,3,query)) do add(row) end
		elseif mode=="All lines" then for _,row in ipairs(review.rows) do add(row) end
		else local raw=mode=="Before text" and previous or current;local number=0
			for line in ((raw or ""):gsub("\r\n","\n").."\n"):gmatch("([^\n]*)\n") do number=number+1;add({kind=" ",text=line,oldLine=mode=="Before text" and number or nil,newLine=mode=="After text" and number or nil}) end
		end
		if #rows==0 then rows=ui.rows({query~="" and "No matching lines. Clear Find text to restore the review." or review and review.equal and "No source changes." or "No changed content lines. Check final newlines or choose Before / After text."},w-60,14) end
		c.lines.list=rows;c.lines.controls.scrollBar.offset=0
		c.summary.label="^7"..(review and review.added.." added / "..review.removed.." removed lines | "..shown.." lines shown" or "Detailed comparison unavailable")
		c.status.label="^7"..(review and (review.grouped and "Repeated or large chunks are grouped. Review full source before replacing a filter." or "Old line | New line | Change. Copy before / after preserves original text.") or "Full available sources can still be copied below.")
	end
	local function rebuild()
		problems={};local function source(profile,label)
			if not profile then return "" end
			local ok,raw=pcall(c.content:GetSelValue()=="Original base text" and filters.base or filters.compile,profile)
			if ok then return raw end;problems[#problems+1]=label.." unavailable: "..tostring(raw):gsub("^.-:%d+:%s*","");return nil
		end
		previous,current=source(before,"Before"),source(after,"After");review=nil
		if previous and current then local ok,value=pcall(diff.compare,previous,current);if ok then review=value else problems[#problems+1]=tostring(value):gsub("^.-:%d+:%s*","") end end
		if #problems==0 then problems=nil end;refresh()
	end
	c.content.selFunc=rebuild;c.view.selFunc=refresh;c.search.changeFunc=refresh
	c.view.enabled=function() return review~=nil end;c.search.enabled=c.view.enabled
	button("copyReview",16,h-46,180,"Copy review",function() Copy(diff.report(review)) end);c.copyReview.enabled=function() return review~=nil end
	button("copyBefore",212,h-46,180,"Copy before",function() Copy(previous) end);c.copyBefore.enabled=function() return previous~=nil end
	button("copyAfter",408,h-46,180,"Copy after",function() Copy(current) end);c.copyAfter.enabled=function() return current~=nil end
	button("close",w-156,h-46,140,"Close",function() main:ClosePopup() end)
	ui.style(c);for _,control in pairs(c) do control.layoutAudit="filter-source-diff" end;rebuild();main:OpenPopup(w,h,"Filter file changes",c,nil,"search","close");return c
end
return M
