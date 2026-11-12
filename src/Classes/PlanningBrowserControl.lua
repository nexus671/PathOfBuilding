-- Searchable native picker shared by planning tools. Selection never mutates a build.
local ui=require("Modules.PlanningUI")
local M={}
function M.Open(title,entries,options)
	options=options or {}
	local width=math.min(940,main.screenW-40);local height=math.min(660,main.screenH-60)
	local left=math.floor((width-48)*0.46);local controls={};local filtered={};local selected;local detailCache={}
	for _,entry in ipairs(entries) do entry.searchText=(entry.label.." "..(entry.search or "")):lower() end
	local function button(key,x,y,w,label,run)
		controls[key]=ui.styleButton(new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run))
	end
	controls.search=new("EditControl"):EditControl(ui.anchor,{16,28,left,26},"","Search",nil,160)
	local categories={"All"};local seen={}
	for _,entry in ipairs(entries) do if entry.category and not seen[entry.category] then seen[entry.category]=true;categories[#categories+1]=entry.category end end
	table.sort(categories,function(a,b) if a==b then return false elseif a=="All" then return true elseif b=="All" then return false else return a<b end end)
	if options.favorites then categories[#categories+1]="Favorites" end
	controls.category=new("DropDownControl"):DropDownControl(ui.anchor,{16,64,left,26},categories)
	controls.results=new("TextListControl"):TextListControl(ui.anchor,{16,102,left,height-200},nil,{})
	local icons={}
	for _,entry in ipairs(entries) do if entry.icon and not icons[entry.icon] then local handle=NewImageHandle();handle:Load(entry.icon);icons[entry.icon]=handle end end
	local drawResults=controls.results.Draw
	function controls.results:Draw(viewport)
		drawResults(self,viewport)
		local x,y=self:GetPos();local w,h=self:GetSize();SetViewport(x+2,y+2,w-20,h-4)
		local top=-self.controls.scrollBar.offset
		for _,row in ipairs(self.list) do if row.icon and top+row.height>=0 and top<h-4 then SetDrawColor(1,1,1);DrawImage(icons[row.icon],2,top+2,34,34) end;top=top+row.height end
		SetViewport()
	end
	controls.details=new("TextListControl"):TextListControl(ui.anchor,{left+32,28,width-left-48,height-126},nil,{})
	ui.label(controls,"count",16,height-86,"",14)
	local function show(entry)
		selected=entry
		local lines=entry and detailCache[entry] or nil
		if not lines then lines=entry and (type(entry.details)=="function" and entry.details() or entry.details or {entry.label}) or {"No matches. Try a shorter search or another category."};if entry then detailCache[entry]=lines end end
		controls.details.list=ui.rows(lines,width-left-78)
		controls.details.controls.scrollBar.offset=0
	end
	local function refresh()
		local query=controls.search.buf:lower();local category=controls.category:GetSelValue();filtered={};local list={}
		for _,entry in ipairs(entries) do
			if (category=="All" or entry.category==category or category=="Favorites" and options.favorites[entry.id]) and entry.searchText:find(query,1,true) then
				filtered[#filtered+1]=entry
			end
		end
		local keep;for _,entry in ipairs(filtered) do if entry==selected then keep=entry end end;show(keep or filtered[1])
		for i=1,math.min(150,#filtered) do
				local entry=filtered[i]
				local color=entry==selected and "^xF3D89D" or "^xD5DEE8"
				local label=(options.favorites and options.favorites[entry.id] and "* " or "")..entry.label
				local lines=ui.rows({label},left-(entry.icon and 74 or 30))
				if entry.icon then for _,line in ipairs(lines) do line.x=44 end;lines[1].height=math.max(42,lines[1].height);lines[1].icon=entry.icon end
				for _,line in ipairs(lines) do line[1]=color..StripEscapes(line[1]);line.entry=entry;list[#list+1]=line end
				list[#list+1]={height=8,"",entry=entry}
		end
		controls.results.list=list;controls.count.label="^7"..#filtered..(#filtered>150 and " matches; first 150 shown. Refine search." or " results | Arrow keys: browse")
	end
	controls.results.onClick=function(row) if row then show(row.line.entry);refresh() end end
	controls.search.changeFunc=refresh;controls.category.selFunc=function() selected=nil;refresh() end
	local function choose() if selected and options.choose then options.choose(selected);if options.closeOnChoose~=false then main:ClosePopup() end end end
	button("choose",16,height-48,180,options.action or "Select",choose)
	controls.choose.shown=options.choose~=nil;controls.choose.enabled=function() return selected~=nil end
	if options.favorites then
		button("favorite",208,height-48,180,"Toggle favorite",function() if selected then options.favorites[selected.id]=not options.favorites[selected.id] or nil;refresh() end end)
		controls.favorite.enabled=function() return selected~=nil end
	end
	button("close",width-132,height-48,116,"Close",function() main:ClosePopup() end)
	controls.search.enterFunc=choose
	local original=controls.search.OnKeyDown
	function controls.search:OnKeyDown(key,...)
		if key=="DOWN" or key=="UP" then
			local index=1;for i,entry in ipairs(filtered) do if entry==selected then index=i end end
			show(filtered[math.max(1,math.min(math.min(150,#filtered),index+(key=="DOWN" and 1 or -1)))]);refresh()
			local offset=0;for _,line in ipairs(controls.results.list) do if line.entry==selected then break end;offset=offset+line.height end
			local scroll=controls.results.controls.scrollBar;local _,h=controls.results:GetSize();if offset<scroll.offset or offset>scroll.offset+h-50 then scroll:SetOffset(math.max(0,offset-30)) end
			return self
		end
		return original(self,key,...)
	end
	ui.style(controls,{choose=true});for _,control in pairs(controls) do control.layoutAudit="planning-browser" end;refresh()
	main:OpenPopup(width,height,title,controls,nil,"search","close")
	return controls
end
return M
