local ui=require("Modules.PlanningUI")
local modifiers=require("Modules.CraftingModifiers")
local M={}
function M.Open(model,state,options)
	local c={};local w,h=math.min(1080,main.screenW-40),math.min(680,main.screenH-60);local tableW=math.floor((w-48)*0.64);local detailX=tableW+32;local detailW=w-detailX-16
	local result=modifiers.inspect(model,state);local selected;local rows
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	c.search=new("EditControl"):EditControl(ui.anchor,{16,28,tableW,28},"","Find a modifier, group or tag",nil,160)
	c.kind=new("DropDownControl"):DropDownControl(ui.anchor,{16,68,tableW/2-6,28},{"All affixes","Prefix","Suffix","Corrupted","Exarch","Eater"})
	c.source=new("DropDownControl"):DropDownControl(ui.anchor,{28+tableW/2-6,68,tableW/2-6,28},{"All sources","Natural","Influence","Bench","Essence","Special"})
	c.availability=new("DropDownControl"):DropDownControl(ui.anchor,{detailX,28,detailW,28},{"All modifiers","Eligible draw","Blocked / special"})
	c.sort=new("DropDownControl"):DropDownControl(ui.anchor,{detailX,68,detailW,28},{"Eligible first","Chance","Tier","Item level","Name"})
	local col={8,math.floor(tableW*0.48),math.floor(tableW*0.57),math.floor(tableW*0.67),math.floor(tableW*0.81)}
	for i,title in ipairs({"Modifier","Tier","iLvl","Weight","Draw %"}) do ui.label(c,"column"..i,16+col[i],112,title,12) end
	local columns={};for _,x in ipairs(col) do columns[#columns+1]={x=x} end
	c.modifiers=new("TextListControl"):TextListControl(ui.anchor,{16,138,tableW,h-230},columns,{})
	c.details=new("TextListControl"):TextListControl(ui.anchor,{detailX,112,detailW,h-204},nil,{})
	local function show(row)
		selected=row;local lines={row and row.text or "Choose a modifier",result.note}
		if row then
			lines={row.text,row.type.." | "..row.source,"Required item level: "..row.level,row.tier and "Group tier: "..row.tier or "Special modifier: no natural tier rank","Groups: "..table.concat(row.groups,", "),"Tags: "..table.concat(row.tags,", "),"Current draw weight: "..row.weight,"Total draw weight: "..result.totalWeight,row.chance and string.format("Conditional draw chance: %.6f%%",row.chance) or "No ordinary affix draw is available"}
			for _,reason in ipairs(row.reasons) do lines[#lines+1]=reason end;lines[#lines+1]=result.note
		end
		c.details.list=ui.rows(lines,detailW-28,14)
	end
	local function refresh()
		rows=modifiers.filter(result,c.search.buf,c.kind:GetSelValue(),c.source:GetSelValue(),c.availability:GetSelValue(),c.sort:GetSelValue());local list={};local keep
		for i=1,math.min(#rows,400) do local row=rows[i];if selected and selected.id==row.id then keep=row end
			local color=row.eligible and "^xD5DEE8" or "^x95A4B7"
			list[#list+1]={height=46,textSize=14,color..ui.fit(row.text,col[2]-20,14),"^7"..(row.tier and "T"..row.tier or "-"),"^7"..row.level,"^7"..row.weight,"^7"..(row.chance and string.format("%.3f",row.chance) or "-"),subtitle=ui.fit(row.type.." | "..row.source.." | "..(row.eligible and "Eligible draw" or row.reasons[1] or "Blocked"),tableW-36,13),entry=row}
		end
		c.modifiers.list=#list>0 and list or ui.rows({"No modifiers match. Clear a filter or shorten the search."},tableW-28,14);show(keep or rows[1]);c.count.label="^7"..#rows..(#rows>400 and " matches / first 400 shown" or " matching modifiers")
	end
	ui.selectable(c.modifiers,function(row) return row.entry and row.entry.id end,function(row) show(row.entry) end)
	for _,key in ipairs({"kind","source","availability","sort"}) do c[key].selFunc=refresh end;c.search.changeFunc=refresh
	ui.label(c,"count",16,h-72,"",12)
	button("choose",16,h-42,200,options.action or "Require modifier",function() if selected then options.choose(selected.id);main:ClosePopup() end end)
	c.choose.enabled=function() return selected~=nil end
	if options.alternative then button("alternative",228,h-42,200,"Add alternative",function() if selected then options.alternative(selected.id);main:ClosePopup() end end);c.alternative.enabled=function() return selected and (not options.canAlternative or options.canAlternative()) end end
	if options.present then button("present",440,h-42,200,"Set as present",function() if selected then options.present(selected.id);main:ClosePopup() end end);c.present.enabled=function() return selected and selected.eligible and not state.destroyed and not state.veil end;c.present.tooltipText="Stage this modifier on a hypothetical rare item. This sets a new recipe start and clears the working action sequence." end
	button("close",w-156,h-42,140,"Close",function() main:ClosePopup() end)
	ui.style(c,{choose=true});refresh();main:OpenPopup(w,h,"Modifier tiers and weights",c,nil,"search","close")
end
return M
