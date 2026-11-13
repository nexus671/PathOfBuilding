local ui=require("Modules.PlanningUI")
local inventory=require("Modules.CraftingInventory")
local projects=require("Modules.CraftingProjects")
local sim=require("Modules.CraftingSimulator")
local art=require("Modules.CraftingWorkbench")
local visual=require("Modules.LootFilterVisuals")
local M={}
function M.Open(build,options)
	options=options or {};local store=build.savers.CraftingProjects;local c={};local w,h=math.min(1080,main.screenW-40),math.min(720,main.screenH-60)
	local left=math.floor((w-48)*0.46);local right=left+32;local selected,entries,removed;local thumbs={}
	local function button(key,x,y,width,label,run)
		c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,function() local ok,err=pcall(run);if not ok then main:OpenMessagePopup("Crafting inventory",require("Modules.PlanningUI").errorText(err)) end end)
	end
	local function save(project)
		local kept=store:Upsert(project);if options.change then options.change(kept) end;return kept
	end
	local function owner()
		assert(selected,"Select an item first")
		for _,project in ipairs(store.projects) do if project.id==selected.project.id then return copyTable(project) end end
		error("The owning project is no longer available")
	end
	c.search=new("EditControl"):EditControl(ui.anchor,{16,28,left,28},"","Search items, slots and projects",nil,160)
	c.itemTitle=new("EditControl"):EditControl(ui.anchor,{right,28,w-right-16,28},"","Snapshot name",nil,120)
	local grid=new("Control"):Control(ui.anchor,{16,76,left,h-188});c.items=grid;grid.scroll=0;grid.planningFocusable=true
	function grid:IsMouseOver() return self:IsShown() and self:IsMouseInBounds() end
	local function choose(entry)
		selected=entry;c.itemTitle:SetText(entry and entry.item.title or "")
		c.savedItem=nil;c.savedItemMods=nil
		if entry then
			local model=sim.model(entry.item.baseItem)
			local refresh=art.item(c,"savedItem",right,76,w-right-16,h-188,model,function() return entry.item.state end,nil,{header=180,artSize=88});refresh()
			for _,key in ipairs({"savedItem","savedItemMods"}) do c[key].anchor.other=c.search.anchor.other end
			c.savedItem.enabled=false;c.savedItem.layoutAudit="crafting-inventory";c.savedItemMods.layoutAudit="crafting-inventory"
		end
	end
	local function refresh()
		local old=selected;entries=inventory.entries(store.projects,c.search.buf);grid.scroll=0;local keep
		for _,entry in ipairs(entries) do if old and entry.item.id==old.item.id and entry.project.id==old.project.id then keep=entry end end
		choose(keep or entries[1])
	end
	local function dimensions() local cols=math.max(1,math.floor(grid.width/126));return cols,(grid.width-12-(cols-1)*8)/cols end
	local function move(delta)
		local at=1;for i,entry in ipairs(entries) do if entry==selected then at=i end end
		at=math.max(1,math.min(#entries,at+delta));choose(entries[at]);local cols=dimensions();local top=6+math.floor((at-1)/cols)*128
		if top<grid.scroll then grid.scroll=math.max(0,top-6) elseif top+120>grid.scroll+grid.height then grid.scroll=top+126-grid.height end
	end
	grid.planningMove=function(delta) local cols=dimensions();move(delta*cols) end
	function grid:OnKeyDown(key)
		if key=="LEFTBUTTON" and self:IsMouseOver() then return self end
		if key=="LEFT" or key=="RIGHT" then move(key=="LEFT" and -1 or 1);return self end
	end
	function grid:Draw()
		local x,y=self:GetPos();local cols,tile=dimensions();SetViewport(x,y,self.width,self.height);visual.box(0,0,self.width,self.height,"^x101822")
		for i,entry in ipairs(entries) do local tx,ty=6+(i-1)%cols*(tile+8),6+math.floor((i-1)/cols)*128-self.scroll
			if ty+120>0 and ty<self.height then
				local active=selected and selected.project.id==entry.project.id and selected.item.id==entry.item.id
				local color=entry.item.state.destroyed and "^xE07070" or entry.item.state.rarity=="RARE" and "^xD4BC72" or entry.item.state.rarity=="MAGIC" and "^x929BE0" or "^x8D9DB0"
				visual.box(tx,ty,tile,120,active and "^xE1C586" or "^x3F566F");visual.box(tx+1,ty+1,tile-2,118,active and "^x293447" or "^x182331")
				local key=entry.project.id.."/"..entry.item.id;local thumb=thumbs[key]
				if not thumb then local item=projects.item(entry.item.state.baseItem or entry.item.baseItem);local path,iw,ih=art.itemArt(item);thumb={handle=visual.image(path),w=iw,h=ih};thumbs[key]=thumb end
				local scale=64/math.max(thumb.w,thumb.h);SetDrawColor(1,1,1);DrawImage(thumb.handle,tx+(tile-thumb.w*scale)/2,ty+8,thumb.w*scale,thumb.h*scale)
				visual.text(tx+6,ty+78,13,entry.item.title,color,tile-12);visual.text(tx+6,ty+100,12,entry.item.slot,"^xA6B3C6",tile-12)
			end
		end
		if #entries==0 then visual.text(12,16,14,"No saved items match.","^xD5DEE8",self.width-24);visual.text(12,44,13,"Use Keep item in the workbench.","^xA6B3C6",self.width-24) end
		SetViewport()
	end
	function grid:OnKeyUp(key)
		if not self:IsMouseOver() then return end;local cols,tile=dimensions()
		if key=="WHEELUP" or key=="WHEELDOWN" then self.scroll=math.max(0,math.min(math.max(0,12+math.ceil(#entries/cols)*128-self.height),self.scroll+(key=="WHEELUP" and -128 or 128)));return self
		elseif key=="LEFTBUTTON" then local x,y=self:GetPos();local px,py=GetCursorPos();px,py=px-x,py-y+self.scroll
			local col=math.floor((px-6)/(tile+8));local row=math.floor((py-6)/128);local entry=col>=0 and col<cols and row>=0 and entries[row*cols+col+1]
			if entry and (px-6)%(tile+8)<=tile and (py-6)%128<120 then choose(entry) end;return self
		end
	end
	button("rename",16,h-84,120,"Rename",function()
		assert(c.itemTitle.buf:match("%S"),"Enter an item name");local project=owner();for _,entry in ipairs(project.inventory) do if entry.id==selected.item.id then entry.title=c.itemTitle.buf end end;save(project);refresh()
	end)
	button("remove",148,h-84,120,"Remove",function()
		local project=owner();for i,entry in ipairs(project.inventory) do if entry.id==selected.item.id then removed={projectId=project.id,item=copyTable(entry)};table.remove(project.inventory,i);break end end;save(project);refresh()
	end)
	button("undoRemove",280,h-84,136,"Undo removal",function()
		assert(removed,"No removed item to restore");for _,project in ipairs(store.projects) do if project.id==removed.projectId then local copy=copyTable(project);copy.inventory=copy.inventory or {};copy.inventory[#copy.inventory+1]=removed.item;save(copy);removed=nil;refresh();return end end;error("The owning project is no longer available")
	end)
	c.undoRemove.enabled=function() return removed~=nil end
	for _,key in ipairs({"rename","remove","itemTitle"}) do c[key].enabled=function() return selected~=nil end end
	ui.label(c,"count",right,h-78,"",13);c.count.label=function() return "^7"..ui.fit(selected and selected.project.title or #entries.." saved items",w-right-16,13) end
	button("resume",16,h-42,260,"Resume as separate working craft",function()
		assert(selected,"Select an item first");local project=inventory.project(selected.item);main:ClosePopup();options.resume(project)
	end);c.resume.enabled=function() return selected~=nil and options.resume~=nil end
	button("compare",292,h-42,220,"Compare with working item",function() assert(selected and options.current,"Choose a saved item and open inventory from a working craft");require("Classes.CraftingItemComparisonControl").Open(selected.item,options.current) end)
	c.compare.enabled=function() return selected~=nil and options.current~=nil end;c.compare.tooltipText="Open the inventory from a working craft to compare its item with this saved snapshot."
	ui.label(c,"saveHint",528,h-36,"Use build Save.",12)
	button("close",w-156,h-42,140,"Close",function() main:ClosePopup() end)
	c.search.changeFunc=refresh;ui.style(c,{resume=true},{savedItem=true});for _,control in pairs(c) do control.layoutAudit="crafting-inventory" end;refresh()
	main:OpenPopup(w,h,"Crafting item inventory",c,nil,"search","close");return c
end
return M
