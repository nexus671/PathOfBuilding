local ui=require("Modules.PlanningUI")
local collections=require("Modules.LootFilterCollections")
local visual=require("Modules.LootFilterVisuals")
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local M={}
local serial=0
function M.Open(profile,kind,sources,onAccept)
	assert(kind=="sampleSets" or kind=="palettes","Unknown filter library")
	local samples=kind=="sampleSets";local draft=copyTable(profile);draft[kind]=draft[kind] or {};local selected;local c={}
	local w,h=math.min(940,main.screenW-40),math.min(660,main.screenH-60);local left=math.floor((w-48)*0.43);local right=left+32;local detailW=w-right-16
	local example,preview;local previewParsed=samples and parser.parse(filters.compile(profile))
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	ui.description(c,"help",16,28,w-32,44,{samples and "Keep exact example properties to test this filter again. Missing properties stay unknown. Named sets travel with the build." or "Keep named appearance snapshots. Using one restores its whole-filter and category settings and the theme for new build targets. Pickup conditions stay unchanged."},14)
	c.name=new("EditControl"):EditControl(ui.anchor,{16,84,left,28},samples and "My example set" or "My palette","Collection name",nil,120)
	if samples then local choices={};for i,source in ipairs(sources) do choices[#choices+1]={label=source.title.." ("..#source.samples..")",val=i} end
		c.source=new("DropDownControl"):DropDownControl(ui.anchor,{right,84,detailW,28},choices)
		c.source.tooltipText="Capture source for Save new or Replace selected. Selecting a saved set previews that saved snapshot."
	else ui.label(c,"captureLabel",right,90,"Save new captures the current appearance.",13) end
	c.entries=new("TextListControl"):TextListControl(ui.anchor,{16,128,left,h-270},nil,{})
	c.preview=new("Control"):Control(ui.anchor,{right,128,detailW,104})
	function c.preview:Draw() local x,y=self:GetPos();visual.floor(x,y,detailW,104);if example then visual.chip(x+8,y+8,detailW-16,88,example,preview) end end
	c.details=new("TextListControl"):TextListControl(ui.anchor,{right,248,detailW,h-390},nil,{})
	local function show(entry)
		selected=entry;local lines={entry and entry.title or "No saved entries"}
		if samples then
			local source=sources[c.source:GetSelValueByKey("val")];example=entry and entry.samples[1] or source.samples[1];preview=example and parser.simulate(previewParsed,example)
			lines[#lines+1]=entry and #entry.samples..(#entry.samples==1 and " exact example item; original levels are retained." or " exact example items; original levels are retained.") or "Choose a source above, name it, then Save new."
			if preview then lines[#lines+1]="Preview: "..preview.action;for _,reason in ipairs(preview.reasons or {}) do lines[#lines+1]=reason end end
			for _,sample in ipairs(entry and entry.samples or {}) do lines[#lines+1]=(sample.BaseType or "Unknown base").." | item level "..tostring(sample.ItemLevel or "unknown").." | area "..tostring(sample.AreaLevel or "unknown") end
		else
			example={BaseType="Crafting base"};local p=copyTable(draft);if entry then p.appearance=entry.appearance;p.theme=entry.theme;if entry.categoryStyles~=nil then p.categoryStyles=entry.categoryStyles end end
			local raw=require("Modules.LootFilterCategoryStyles").apply(filters.rule("example","Example",{},nil,p.theme).text,p.categoryStyles,"Build targets")
			raw=require("Modules.LootFilterDecorators").apply(raw,p.appearance)
			preview={action="Show",styles=parser.parse(raw).rules[1].styles};lines[#lines+1]=entry and "Use selected restores this snapshot. Further edits do not change the saved palette." or "Tune Whole-filter appearance on the Style page before saving a new palette."
			lines[#lines+1]=entry and entry.categoryStyles~=nil and "Restores "..#entry.categoryStyles.." saved category styles." or "Category settings stay as currently configured."
			lines[#lines+1]="Snapshot preview; undeclared styles in imported filters still inherit normally."
		end
		c.details.list=ui.rows(lines,detailW-28,14);c.details.controls.scrollBar.offset=0
		c.entries.selectedKey=entry and entry.id;for _,row in ipairs(c.entries.list) do row.selected=entry and row.entry==entry end
	end
	if samples then c.source.selFunc=function() show(selected) end end
	local function refresh(id)
		local rows,keep={},nil;for _,entry in ipairs(draft[kind]) do rows[#rows+1]={height=56,textSize=14,"^7"..ui.fit(entry.title,left-28,14),subtitle=samples and #entry.samples..(#entry.samples==1 and " item" or " items") or "Appearance snapshot",entry=entry};if entry.id==id then keep=entry end end
		c.entries.list=#rows>0 and rows or ui.rows({"Your saved "..(samples and "example sets" or "palettes").." appear here."},left-28,14);show(keep or draft[kind][1])
	end
	ui.selectable(c.entries,function(row) return row.entry and row.entry.id end,function(row) show(row.entry);if row.entry then c.name:SetText(row.entry.title) end end)
	local function capture(id)
		local entry={id=id,title=c.name.buf}
		if samples then entry.samples=copyTable(sources[c.source:GetSelValueByKey("val")].samples)
		else entry.appearance=copyTable(profile.appearance or {});entry.theme=profile.theme;entry.categoryStyles=copyTable(profile.categoryStyles or {}) end
		draft=collections.install(draft,kind,entry);refresh(id)
	end
	local bw=math.floor((w-56)/4)
	button("saveNew",16,h-126,bw,"Save new",function()
		local used={};for _,entry in ipairs(draft[kind]) do used[entry.id]=true end
		local id;repeat serial=serial+1;id="saved-"..os.time().."-"..serial until not used[id];capture(id)
	end)
	c.saveNew.enabled=function() return not samples or #sources[c.source:GetSelValueByKey("val")].samples>0 end
	button("replace",24+bw,h-126,bw,"Replace selected",function() assert(selected,"Choose an entry");capture(selected.id) end);c.replace.enabled=function() return selected~=nil and c.saveNew.enabled() end
	button("rename",32+2*bw,h-126,bw,"Rename",function() assert(selected,"Choose an entry");local entry=copyTable(selected);entry.title=c.name.buf;draft=collections.install(draft,kind,entry);refresh(entry.id) end);c.rename.enabled=function() return selected~=nil end
	button("remove",40+3*bw,h-126,bw,"Remove",function() assert(selected,"Choose an entry");for i,entry in ipairs(draft[kind]) do if entry.id==selected.id then table.remove(draft[kind],i);break end end;refresh() end);c.remove.enabled=c.rename.enabled
	ui.label(c,"staged",16,h-84,"Edits are staged here. Cancel discards them; Keep in build and Save persist them.",12)
	button("use",16,h-46,220,"Use selected",function() assert(selected,"Choose an entry");local next=samples and draft or collections.palette(draft,selected.id);onAccept(next,samples and selected or nil);main:ClosePopup() end);c.use.enabled=c.rename.enabled
	button("keep",252,h-46,180,"Keep library",function() onAccept(draft);main:ClosePopup() end)
	button("close",w-156,h-46,140,"Cancel",function() main:ClosePopup() end)
	ui.style(c,{use=true},{preview=true});for _,control in pairs(c) do control.layoutAudit="filter-library" end;refresh();main:OpenPopup(w,h,samples and "Saved example sets" or "Saved palettes",c,nil,"name","close");return c
end
return M
