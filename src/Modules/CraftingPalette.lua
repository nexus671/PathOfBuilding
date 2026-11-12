-- An inline action picker: the working item stays visible while browsing.
local ui=require("Modules.PlanningUI")
local sim=require("Modules.CraftingSimulator")
local workbench=require("Modules.CraftingWorkbench")
local inspect=require("Modules.CraftingInspection")
local M={}
function M.new(controls,width,height,options)
	local own={};local selected=options.current();local entries={};local categories={"All actions","Favorites"};local seen={};local images={}
	for _,method in ipairs(sim.methods) do
		local category=inspect.category(method);entries[#entries+1]={method=method,label=sim.labels[method] or method,category=category}
		if not seen[category] then seen[category]=true;categories[#categories+1]=category end
		local path=workbench.icon(method);if path then local image=NewImageHandle();image:Load(path);images[method]=image end
	end
	table.sort(entries,function(a,b) return a.label<b.label end)
	own.paletteSearch=new("EditControl"):EditControl(ui.anchor,{16,94,width,26},"","Search",nil,160)
	own.paletteCategory=new("DropDownControl"):DropDownControl(ui.anchor,{16,132,width,26},categories)
	own.paletteResults=new("TextListControl"):TextListControl(ui.anchor,{16,170,width,height-328},nil,{})
	own.paletteHint=ui.description(own,"paletteHint",16,height-150,width,46,{})
	local function refresh()
		local matches={};local category=own.paletteCategory:GetSelValue();local query=own.paletteSearch.buf:lower();local kept
		for _,entry in ipairs(entries) do
			if (category=="All actions" or category==entry.category or category=="Favorites" and options.favorites[entry.method]) and (entry.label.." "..entry.category):lower():find(query,1,true) then matches[#matches+1]=entry;if selected==entry.method then kept=entry end end
		end
		selected=kept and kept.method or matches[1] and matches[1].method
		local rows={}
		for _,entry in ipairs(matches) do
			local method=entry.method;local active=selected==method;local allowed=options.available(method)
			local color=active and "^xF3D89D" or allowed and "^xD5DEE8" or "^x8D9DB0"
			local label=(options.favorites[method] and "* " or "")..entry.label
			local lines=ui.rows({label},width-78,16)
			for i,line in ipairs(lines) do line.x=48;line[1]=color..StripEscapes(line[1]);line.method=method;if i==1 then line.icon=images[method] end;rows[#rows+1]=line end
			rows[#rows+1]={height=24,textSize=12,x=48,"^x8D9DB0"..entry.category,method=method}
		end
		if #matches==0 then rows=ui.rows({"No actions found. Try a shorter search or another category."},width-30) end
		own.paletteResults.list=rows
		own.paletteHint.list=ui.rows({selected and options.hint(selected) or "Your working item stays unchanged while you browse."},width-30,14)
		return matches
	end
	local draw=own.paletteResults.Draw
	function own.paletteResults:Draw(viewport)
		draw(self,viewport);local x,y=self:GetPos();local w,h=self:GetSize();SetViewport(x+2,y+2,w-20,h-4)
		local top=-self.controls.scrollBar.offset
		for _,row in ipairs(self.list) do if row.icon and top+36>=0 and top<h-4 then SetDrawColor(1,1,1);DrawImage(row.icon,5,top+2,32,32) end;top=top+row.height end
		SetViewport()
	end
	own.paletteResults.onClick=function(row) if row and row.line.method then selected=row.line.method;refresh() end end
	own.paletteSearch.changeFunc=function() own.paletteResults.controls.scrollBar.offset=0;refresh() end
	own.paletteCategory.selFunc=function() own.paletteResults.controls.scrollBar.offset=0;refresh() end
	own.paletteBack=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-98,math.floor((width-12)/2),28},"< Currency tray",options.close)
	own.paletteUse=new("ButtonControl"):ButtonControl(ui.anchor,{28+math.floor((width-12)/2),height-98,math.floor((width-12)/2),28},"Select action",function() if selected then options.choose(selected) end end)
	own.paletteUse.enabled=function() return selected and options.available(selected) end
	own.paletteFavorite=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-186,width,26},"Favorite selected action",function() if selected then options.favorites[selected]=not options.favorites[selected] or nil;refresh() end end)
	own.paletteFavorite.label=function() return selected and options.favorites[selected] and "Remove from favorites" or "Add to favorites" end
	own.paletteFavorite.enabled=function() return selected~=nil end
	-- Leave space between the result list, favorite toggle and explanation.
	own.paletteResults.height=height-372
	for key,control in pairs(own) do control.shown=options.shown;controls[key]=control end
	ui.style(own,{paletteUse=true})
	local original=own.paletteSearch.OnKeyDown
	function own.paletteSearch:OnKeyDown(key,...)
		if key=="UP" or key=="DOWN" then
			local matches=refresh();local index=1;for i,entry in ipairs(matches) do if entry.method==selected then index=i end end
			local nextEntry=matches[math.max(1,math.min(#matches,index+(key=="DOWN" and 1 or -1)))];selected=nextEntry and nextEntry.method
			refresh();local offset=0;for _,row in ipairs(own.paletteResults.list) do if row.method==selected then break end;offset=offset+row.height end
			local scroll=own.paletteResults.controls.scrollBar;local _,h=own.paletteResults:GetSize();if offset<scroll.offset or offset>scroll.offset+h-50 then scroll:SetOffset(math.max(0,offset-20)) end
			return self
		end
		return original(self,key,...)
	end
	own.paletteSearch.enterFunc=function() own.paletteUse:Click() end
	local restored=options.restore
	if restored then own.paletteSearch:SetText(restored.query or "");own.paletteCategory:SelByValue(restored.category or "All actions");selected=restored.method or selected end
	refresh()
	return {refresh=refresh,snapshot=function() return {query=own.paletteSearch.buf,category=own.paletteCategory:GetSelValue(),method=selected} end}
end
return M
