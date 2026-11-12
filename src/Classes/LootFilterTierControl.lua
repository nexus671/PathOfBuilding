-- Item lists are edited as exact-name rules, never by modifying the pinned files.
local ui=require("Modules.PlanningUI")
local edit=require("Modules.LootFilterEditing")
local library=require("Modules.LootFilterLibrary")
local parser=require("Modules.LootFilterParser")
local visual=require("Modules.LootFilterVisuals")
local M={}
function M.Mount(c,profile,w,h,view,options)
	view=view or {};local selected;local name;local entries={};local source=view.scope or "My tiers"
	local function button(key,x,y,width,title,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},title,run) end
	local function change(next,id) view.selected=id or view.selected;options.change(next) end
	local function chosen() assert(selected,"Choose a tier");return selected end
	local function custom() assert(chosen().custom,"Copy a preset tier before editing it");return selected end
	c.tierSearch=new("EditControl"):EditControl(ui.anchor,{16,120,300,26},view.query or "","Find a tier or item",nil,160)
	c.tierScope=new("DropDownControl"):DropDownControl(ui.anchor,{332,120,200,26},{"My tiers","Preset tiers"},function(_,value) source=value;view.scope=value;view.selected=nil;options.reopen() end);c.tierScope:SelByValue(source)
	ui.label(c,"tierPriority",548,128,"Personal pickups precede tiers",12)
	c.tiers=new("TextListControl"):TextListControl(ui.anchor,{16,164,300,h-318},nil,{})
	c.tierItems=new("TextListControl"):TextListControl(ui.anchor,{332,200,w-348,h-354},nil,{})
	ui.label(c,"tierTitle",332,166,"Choose a tier",18)
	local function show(entry)
		selected=entry;view.selected=entry and entry.id;name=nil;local rows={}
		if entry then for _,item in ipairs(entry.items) do rows[#rows+1]={height=48,textSize=15,"",name=item,block=parser.parse(entry.text).rules[1]} end end
		if #rows==0 then rows=ui.rows({entry and "Empty tier. Add an exact item name below." or "Create a tier or copy one from the preset."},w-380,14) end
		c.tierItems.list=rows;c.tierTitle.label="^7"..ui.fit(entry and entry.title or "Choose a tier",w-348,18)
	end
	local function refresh()
		entries={}
		if source=="My tiers" then for _,tier in ipairs(profile.tiers or {}) do local entry=copyTable(tier);entry.custom=true;entries[#entries+1]=entry end
		else for _,entry in ipairs(library.catalog(profile)) do local ok,items=pcall(edit.items,entry.rule.text);if ok then entries[#entries+1]={id=entry.rule.id,title=entry.rule.title,items=items,text=entry.rule.text,enabled=true} end end end
		local query=c.tierSearch.buf:lower();local rows={};local keep
		for _,entry in ipairs(entries) do if (entry.title.." "..table.concat(entry.items," ").." "..entry.text):lower():find(query,1,true) then
			rows[#rows+1]={height=48,textSize=14,"^7"..ui.fit(entry.title,270,14),subtitle=(entry.enabled==false and "Disabled | " or "")..#entry.items..(#entry.items==1 and " item" or " items"),entry=entry}
			if entry.id==view.selected then keep=entry end
		end end
		c.tiers.list=#rows>0 and rows or ui.rows({"No tiers found.","Create a tier, or browse the preset."},268,14);show(keep or rows[1] and rows[1].entry)
	end
	ui.selectable(c.tiers,function(row) return row.entry and row.entry.id end,function(row) show(row.entry) end)
	ui.selectable(c.tierItems,function(row) return row.name end,function(row) name=row.name end)
	local drawItems=c.tierItems.Draw
	function c.tierItems:Draw(viewport)
		drawItems(self,viewport);local x,y=self:GetPos();local width,height=self:GetSize();SetViewport(x+2,y+2,width-20,height-4);local top=-self.controls.scrollBar.offset
		for _,row in ipairs(self.list) do if row.name and top+row.height>0 and top<height then visual.chip(6,top+4,width-32,40,{BaseType=row.name},{action=row.block.action,styles=row.block.styles},name==row.name) end;top=top+row.height end
		SetViewport()
	end
	c.tierSearch.changeFunc=function(value) view.query=value;refresh() end
	local destinations={};for _,tier in ipairs(profile.tiers or {}) do destinations[#destinations+1]={label=tier.title,val=tier.id} end
	c.tierDestination=new("DropDownControl"):DropDownControl(ui.anchor,{332,h-94,w-500,28},destinations)
	button("tierMove",w-148,h-94,132,"Move item",function() assert(name,"Choose an item");local id=assert(c.tierDestination:GetSelValueByKey("val"),"Create a destination tier");change(edit.assign(profile,id,name,chosen().text),id) end)
	c.tierMove.enabled=function() return name~=nil and #destinations>0 and not edit.assignmentIssue(profile,c.tierDestination:GetSelValueByKey("val"),name,chosen().text) end
	c.tierMove.tooltipFunc=function(tooltip) tooltip:AddLine(14,name and (edit.assignmentIssue(profile,c.tierDestination:GetSelValueByKey("val"),name,chosen().text) or "Move this item to the selected tier; its class and stack conditions remain attached.") or "Choose an item and a destination tier.") end
	c.tierName=new("EditControl"):EditControl(ui.anchor,{332,h-136,w-500,28},"","Exact item name",nil,240)
	button("tierAddItem",w-148,h-136,132,"Add item",function() local entry=custom();change(edit.assign(profile,entry.id,c.tierName.buf)) end)
	c.tierAddItem.enabled=function() return selected and selected.custom end
	button("tierNew",16,h-136,92,"New tier",function() local next=copyTable(profile);next.tiers=next.tiers or {};local tier=edit.newTier(options.id(),"New tier");next.tiers[#next.tiers+1]=tier;view.scope="My tiers";change(next,tier.id) end)
	button("tierEdit",116,h-136,92,"Edit",function() local entry=custom();local rule={id=entry.id,title=entry.title,text=#entry.items>0 and edit.withItems(entry.text,entry.items) or entry.text,enabled=entry.enabled}
		options.edit(rule,function(rule) local next=copyTable(profile);for _,tier in ipairs(next.tiers) do if tier.id==entry.id then tier.title=rule.title;tier.text=rule.text;tier.enabled=rule.enabled;if #tier.items>0 then tier.items=edit.items(rule.text) end end end;change(next) end)
	end);c.tierEdit.enabled=function() return selected and selected.custom end
	button("tierDelete",216,h-136,100,"Delete",function() local entry=custom();local next=copyTable(profile);for i,tier in ipairs(next.tiers) do if tier.id==entry.id then table.remove(next.tiers,i);break end end;view.selected=nil;change(next) end);c.tierDelete.enabled=c.tierEdit.enabled
	local function move(delta) local entry=custom();local next=copyTable(profile);for i,tier in ipairs(next.tiers) do if tier.id==entry.id and next.tiers[i+delta] then next.tiers[i],next.tiers[i+delta]=next.tiers[i+delta],next.tiers[i];break end end;change(next) end
	button("tierUp",16,h-94,64,"Up",function() move(-1) end);c.tierUp.enabled=c.tierEdit.enabled
	button("tierDown",88,h-94,64,"Down",function() move(1) end);c.tierDown.enabled=c.tierEdit.enabled
	button("tierCopy",160,h-94,156,"Copy preset tier",function() local entry=chosen();local next=copyTable(profile);local tier=edit.newTier(options.id(),entry.title,entry.text);tier.items=copyTable(entry.items);next.tiers=next.tiers or {};next.tiers[#next.tiers+1]=tier;view.scope="My tiers";change(next,tier.id) end)
	c.tierCopy.enabled=function() return selected and not selected.custom end
	local originalDown,originalUp=c.tierItems.OnKeyDown,c.tierItems.OnKeyUp
	function c.tierItems:OnKeyDown(key,...) local result=originalDown(self,key,...);if key=="LEFTBUTTON" and self.hoveredLine and self.hoveredLine.line.name then self.dragName=self.hoveredLine.line.name end;return result end
	function c.tierItems:OnKeyUp(key,...)
		if key=="LEFTBUTTON" and self.dragName then local moving=self.dragName;self.dragName=nil
			local row=c.tiers.hoveredLine;if c.tiers:IsMouseOver() and row and row.line.entry and row.line.entry.custom then
				local issue=edit.assignmentIssue(profile,row.line.entry.id,moving,chosen().text)
				if issue then main:OpenMessagePopup("Tier item classes",issue) else change(edit.assign(profile,row.line.entry.id,moving,chosen().text),row.line.entry.id) end;return self
			end
		end
		return originalUp(self,key,...)
	end
	ui.description(c,"tierHelp",16,h-60,w-208,22,{"Drag an item onto a custom tier, or use Move item. Class and stack conditions are retained; preset files stay intact."},12)
	refresh();return {snapshot=function() return view end}
end
return M
