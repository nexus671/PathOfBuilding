local ui=require("Modules.PlanningUI")
local structure=require("Modules.LootFilterStructure")
local M={}
function M.Open(profile,edit)
	local outline=structure.outline(profile);local c={};local w,h=math.min(1080,main.screenW-40),math.min(720,main.screenH-60)
	local left=200;local middle=math.floor((w-left-64)*0.48);local listX=left+32;local detailX=listX+middle+16;local detailW=w-detailX-16
	local selected,section,category;local collapsed={};for _,entry in ipairs(outline.sections) do collapsed[entry.id]=true end
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	c.search=new("EditControl"):EditControl(ui.anchor,{16,28,w-276,28},"","Search names, properties or source text",nil,160)
	c.mode=new("DropDownControl"):DropDownControl(ui.anchor,{w-244,28,228,28},{"All blocks","Priority conflicts","Warnings / errors","Continue blocks","Hidden blocks"})
	ui.description(c,"help",16,72,w-32,36,{"Browse active blocks by section and family. The first matching block stops unless it uses Continue. Editing a preset, policy, tier or module block creates a personal override."},14)
	ui.label(c,"sectionsLabel",16,118,"Sections",14);ui.label(c,"blocksLabel",listX,118,"Matching blocks",14);ui.label(c,"detailsLabel",detailX,118,"Compiled block and diagnostics",14)
	c.sections=new("TextListControl"):TextListControl(ui.anchor,{16,142,left,h-250},nil,{})
	c.blocks=new("TextListControl"):TextListControl(ui.anchor,{listX,142,middle,h-250},nil,{})
	c.details=new("TextListControl"):TextListControl(ui.anchor,{detailX,142,detailW,h-250},nil,{})
	local function show(entry)
		selected=entry;local lines={entry and entry.title or "No matching blocks"}
		if entry then
			lines[#lines+1]=entry.sectionTitle.." / "..entry.category;lines[#lines+1]="Compiled line "..entry.line.." | "..entry.block.action..(entry.block.continue and " + Continue" or " + stop")
			lines[#lines+1]=entry.editable and "Editing updates this personal rule." or "Editing creates a higher-priority personal override."
			for _,d in ipairs(structure.diagnostics(outline,entry)) do lines[#lines+1]=(d.error and "Error: "..d.error or "Warning: "..d.warning) end
			lines[#lines+1]="";lines[#lines+1]=entry.text
		else lines[#lines+1]="Clear a search, choose All blocks, or browse another section." end
		c.details.list=ui.rows(lines,detailW-28,13);c.details.controls.scrollBar.offset=0
		c.blocks.selectedKey=entry and entry.id;for _,row in ipairs(c.blocks.list) do row.selected=entry and row.entry==entry end
	end
	local function refreshBlocks()
		local entries=structure.filter(outline,c.search.buf,section,category,c.mode:GetSelValue());local rows={};local keep
		for i=1,#entries do local entry=entries[i];if selected and selected.id==entry.id then keep=entry end
			rows[#rows+1]={height=58,textSize=14,"^7"..ui.fit(entry.title,middle-28,14),subtitle=ui.fit(entry.block.action..(entry.block.continue and " + Continue" or "").." | line "..entry.line,middle-28,13),entry=entry}
		end
		c.blocks.list=#rows>0 and rows or ui.rows({"No matching blocks."},middle-28,14);show(keep or entries[1]);c.count.label="^7"..#entries.." matching blocks"
	end
	local function refreshSections()
		local rows={{height=32,textSize=14,"^7All sections ("..#outline.entries..")",id="all"}}
		for _,group in ipairs(outline.sections) do
			rows[#rows+1]={height=40,textSize=14,"^7"..ui.fit((collapsed[group.id] and "+ " or "- ")..group.title,left-28,14),subtitle=group.count.." blocks",id=group.id,section=group.id,branch=true}
			if not collapsed[group.id] then for name,count in pairsSortByKey(group.categories) do rows[#rows+1]={height=32,textSize=13,x=14,"^7"..ui.fit(name.." ("..count..")",left-42,13),id=group.id..":"..name,section=group.id,category=name} end end
		end;c.sections.selectedKey=c.sections.selectedKey or "all";for _,row in ipairs(rows) do row.selected=row.id==c.sections.selectedKey end;c.sections.list=rows
	end
	ui.selectable(c.sections,function(row) return row.id end,function(row) section=row.section;category=row.category;c.blocks.controls.scrollBar.offset=0;refreshBlocks() end,function(row) if row.branch then collapsed[row.section]=not collapsed[row.section];refreshSections() end end)
	ui.selectable(c.blocks,function(row) return row.entry and row.entry.id end,function(row) show(row.entry) end)
	ui.label(c,"count",16,h-90,"",13)
	ui.label(c,"imports",16,h-66,#outline.report.imports>0 and "External Import files are unresolved. The structure shows only this file's active blocks." or "Only active compiled blocks appear. Disabled personal rules remain in Customize.",12)
	button("edit",16,h-42,220,"Edit selected block",function() assert(selected,"Choose a block");local rule=selected.rule;main:ClosePopup();edit(rule) end);c.edit.enabled=function() return selected~=nil and edit~=nil end
	button("copyBlock",252,h-42,180,"Copy block",function() assert(selected,"Choose a block");Copy(selected.text) end);c.copyBlock.enabled=function() return selected~=nil end
	button("copyFilter",448,h-42,220,"Copy compiled filter",function() Copy(outline.raw) end)
	button("close",w-156,h-42,140,"Close",function() main:ClosePopup() end)
	local function changed() c.blocks.controls.scrollBar.offset=0;refreshBlocks() end
	c.search.changeFunc=changed;c.mode.selFunc=changed;refreshSections();refreshBlocks();ui.style(c,{edit=true});for _,control in pairs(c) do control.layoutAudit="filter-structure" end;main:OpenPopup(w,h,"Compiled filter structure",c,nil,"search","close");return c
end
return M
