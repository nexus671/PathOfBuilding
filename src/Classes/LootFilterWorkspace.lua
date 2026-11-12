-- A visual catalogue and loot scene, backed by the same native filter compiler.
local ui=require("Modules.PlanningUI")
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local library=require("Modules.LootFilterLibrary")
local visual=require("Modules.LootFilterVisuals")
local M={}
local function button(c,key,x,y,w,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run);return c[key] end
local function identifier() return "filter-"..os.time().."-"..tostring(GetTime()):gsub("%W","") end
function M.Open(build,source,layout,controller)
	local saver=build.savers.LootFilters;local c={};local custom={};local backgrounds={};local w,h=layout.width,layout.height
	local state=source or {};local data=state.data or copyTable(saver.data);local profile=filters.find(data,state.selected) or data.profiles[1]
	local page=state.page or "Overview";local category=state.category or "All items";local scope=state.scope or (profile and #profile.rules>0 and "My rules" or "Base filter");local query=state.query or "";local selected=state.rule
	local item=state.sample or library.sample();local dirty=state.dirty or false;local sceneKind=state.sceneKind or "Mixed drops";local seed=state.seed or 0;local showHidden=state.showHidden~=false
	local catalog,entries,parsed,raw,report,result={},{};local selectedEntry;local scene={}
	local function draft() dirty=true;ui.draft(build,"filters") end
	local function snapshot() return {data=data,selected=profile and profile.id,page=page,category=category,scope=scope,query=query,rule=selected,sample=item,dirty=dirty,seed=seed,sceneKind=sceneKind,showHidden=showHidden} end
	local function reopen() layout.navigate("filters",snapshot()) end
	local function compile()
		if not profile then return end
		local ok,value,details=pcall(filters.compile,profile)
		if not ok then raw=nil;report={error=value};result={action="Unknown",status="invalid",styles={},reasons={value}};return end
		raw,report=value,details;parsed=parser.parse(raw);result=parser.simulate(parsed,item)
		for _,d in ipairs(report.diagnostics) do if d.error then raw=nil;result={action="Unknown",status="invalid",styles={},reasons={d.error}} end end
	end
	local function selectedRule() return selectedEntry and selectedEntry.rule end
	local function keepRule(rule)
		local found=false;for i,r in ipairs(profile.rules) do if r.id==rule.id then profile.rules[i]=rule;found=true end end
		if not found then profile.rules[#profile.rules+1]=rule end
		selected=rule.id;scope="My rules";category="All items";query="";draft();reopen()
	end
	local function edit() if selectedRule() then controller.EditRule(selectedRule(),keepRule) end end
	local function updateSelection(entry)
		selectedEntry=entry;selected=entry and entry.rule.id;item=entry and copyTable(entry.sample) or item;if parsed then result=parser.simulate(parsed,item) end
		if c.detail then local lines={}
			if entry then
				lines={entry.rule.title,entry.category.." / "..entry.tier,(entry.rule.enabled==false and "Disabled. The base preset still applies." or entry.base and "Base preset. Editing creates a personal override." or entry.rule.origin and "Linked to "..entry.rule.origin or "Personal rule"),tostring(#entry.block.conditions).." matching conditions",result and result.action=="Unknown" and "Add missing sample properties to resolve this drop." or "Preview uses this profile's complete filter."}
			else lines={"Choose a rule or a drop to inspect it.","Personal rules take priority over the base preset."} end
			c.detail.list=ui.rows(lines,c.detail.width-28,14)
		end
	end
	local function card(key,x,y,width,title,value,caption,icon)
		local control=new("Control"):Control(ui.anchor,{x,y,width,74});c[key]=control
		function control:Draw() local px,py=self:GetPos();visual.box(px,py,width,74,"^x293B4B");visual.box(px+1,py+1,width-2,72,"^x152331");visual.text(px+14,py+10,12,title,"^x98ADC2",width-70);visual.text(px+14,py+28,24,type(value)=="function" and value() or value,"^xEED49C",width-70);visual.text(px+14,py+56,12,caption,"^xAEBECA",width-28);if icon then SetDrawColor(1,1,1);DrawImage(visual.image(icon),px+width-54,py+12,38,38) end end
	end
	local function sceneControl(key,x,y,width,height,drops,selectable)
		local canvas=new("Control"):Control(ui.anchor,{x,y,width,height});c[key]=canvas;backgrounds[key]=true
		local columns=width>700 and 4 or width>460 and 3 or 2;local rows=math.max(2,math.floor((height-46)/70));local count=math.min(#drops,columns*rows);local cells={};local visible=0
		for i=1,count do local drop=drops[i];local evaluated=parsed and parser.simulate(parsed,drop) or {action="Unknown",status="unknown",styles={}};if showHidden or evaluated.action~="Hide" then
			visible=visible+1;local cellW=(width-24)/columns;local cellH=(height-46)/rows;local cx=x+12+((visible-1)%columns)*cellW;local cy=y+12+math.floor((visible-1)/columns)*cellH
			cells[#cells+1]={x=cx,y=cy,w=cellW,h=cellH,item=drop,result=evaluated}
			if selectable then local control=new("ButtonControl"):ButtonControl(ui.anchor,{cx,cy,cellW,cellH},"",function() item=copyTable(drop);compile();if c.selection then c.selection.list=ui.rows({drop.BaseType,(result.action or "Unknown").." | "..(result.ruleTitle or "Preset rule"),table.concat(result.reasons or {}," ")},c.selection.width-28,14) end end)
				c["drop"..i]=control;custom["drop"..i]=true;control.Draw=function() end;control.planningFocusable=true;control.tooltipText=drop.BaseType.." | "..evaluated.action
			end
		end end
		function canvas:Draw() local px,py=self:GetPos();visual.floor(px,py,width,height)
			for _,cell in ipairs(cells) do visual.chip(px+cell.x-x,py+cell.y-y,cell.w,cell.h,cell.item,cell.result,item.BaseType==cell.item.BaseType) end
			visual.text(px+14,py+height-26,12,"EXAMPLE DROPS  /  "..visible.." displayed  /  click an item to inspect","^xAABBBE",width-28)
		end
	end
	compile()
	ui.label(c,"heading",16,14,"Loot filter",26)
	ui.label(c,"subtitle",16,48,"Customise pickups, preview loot, export to PoE.",14)
	local profiles={};for _,p in ipairs(data.profiles) do profiles[#profiles+1]={label=p.title,val=p.id} end;if #profiles==0 then profiles={{label="No saved profile",val=""}} end
	c.profile=new("DropDownControl"):DropDownControl(ui.anchor,{w-430,14,232,28},profiles,function(_,value) profile=filters.find(data,value.val);selected=nil;reopen() end);c.profile:SelByValue(profile and profile.id or "","val")
	button(c,"keep",w-182,14,166,"Keep in build",function() if profile then data.activeId=profile.id end;saver:Replace(data);dirty=false end)
	for i,name in ipairs({"Overview","Customize","Simulate","Style"}) do local control=button(c,"view"..name,16+(i-1)*126,76,118,name,function() page=name;reopen() end);control.locked=page==name end
	button(c,"manage",w-172,76,156,"Profile tools",function()
		local choices={
			{id="new",label="Create profile",details={"Start from a pinned NeverSink preset."}},
			{id="duplicate",label="Duplicate profile",details={"Keep a separate version for another character or stage."}},
			{id="import",label="Import .filter",details={"Preserve the original file and edit with personal overrides."}},
			{id="account",label="Account filters",details={"Import or review an explicit account publication."}},
			{id="audit",label="Audit and update",details={"Inspect patch migrations, diagnostics and base updates."}},
			{id="delete",label="Delete this profile",details={"This changes the working draft. Keep and Save to persist."}},
		}
		require("Classes.PlanningBrowserControl").Open("Filter profile tools",choices,{action="Open",choose=function(entry)
			main:ClosePopup()
			if entry.id=="new" then profile=filters.profile(identifier(),"My loot filter");data.profiles[#data.profiles+1]=profile;data.activeId=profile.id;page="Overview";selected=nil;draft();reopen()
			elseif entry.id=="duplicate" and profile then profile=copyTable(profile);profile.id=identifier();profile.title=profile.title.." copy";data.profiles[#data.profiles+1]=profile;draft();reopen()
			elseif entry.id=="import" then controller.Import(function(text) if not profile then profile=filters.profile(identifier(),"Imported filter");data.profiles[#data.profiles+1]=profile end;profile.template=text;draft();reopen() end)
			elseif entry.id=="account" and profile then controller.Account(profile,function(text) profile.template=text;draft();reopen() end)
			elseif entry.id=="audit" and profile then controller.Audit(profile,report,function(next) for i,p in ipairs(data.profiles) do if p.id==next.id then data.profiles[i]=next end end;profile=next;draft();reopen() end)
			elseif entry.id=="delete" and profile then for i,p in ipairs(data.profiles) do if p.id==profile.id then table.remove(data.profiles,i);break end end;profile=data.profiles[1];data.activeId=profile and profile.id or "";draft();reopen() end
		end,closeOnChoose=false})
	end)
	if not profile then
		local cw=math.floor((w-64)/3)
		for i,entry in ipairs({{"Campaign","Start a new journey","campaign","Assets/Crafting/transmute.png"},{"Early maps","Build a useful pickup list","early_maps","Assets/Crafting/chaos.png"},{"Endgame","Keep the drops that matter","endgame","Assets/Crafting/exalt.png"}}) do
			local x=16+(i-1)*(cw+16);local key="create"..i;local control=button(c,key,x,164,cw,entry[1],function() profile=filters.profile(identifier(),entry[1].." loot",entry[3]);data.profiles[#data.profiles+1]=profile;data.activeId=profile.id;draft();reopen() end);control.height=220;custom[key]=true;control.planningFocusable=true
			function control:Draw() local px,py=self:GetPos();visual.box(px,py,cw,220,self:IsMouseOver() and "^x829AB1" or "^x394D60");visual.box(px+1,py+1,cw-2,218,"^x152B43");SetDrawColor(1,1,1);DrawImage(visual.image(entry[4]),px+(cw-64)/2,py+28,64,64);visual.text(px+20,py+116,24,entry[1],"^xF2D69E",cw-40);visual.text(px+20,py+158,14,entry[2],"^xBECFDC",cw-40);visual.text(px+20,py+192,14,"Create profile  >","^xA6D8EF",cw-40) end
		end
		ui.label(c,"emptyTitle",16,124,"Choose where you are in your build",20)
		ui.description(c,"emptyHelp",16,410,w-32,70,{saver.warning or "Start with a ready-made preset, then customise the labels, sounds and pickups for your character."},16)
	elseif page=="Overview" then
		local cw=math.floor((w-64)/3)
		card("strictCard",16,120,cw,"STRICTNESS",filters.strictness[profile.strictness+1],"Choose how much loot gets through","Assets/Crafting/chaos.png")
		card("targetCard",32+cw,120,cw,"PERSONAL PICKUPS",tostring(#profile.rules),"Crafting, gear and Atlas targets","Assets/Crafting/exalt.png")
		card("baseCard",48+cw*2,120,cw,"BASE PRESET",profile.template and "Imported" or "NeverSink","PoE 3.30 / "..profile.mode,"Assets/Crafting/vaal.png")
		local left=math.max(274,math.floor(w*0.31));local right=w-left-48
		ui.label(c,"setupLabel",16,214,"Your profile",18)
		ui.label(c,"titleLabel",16,246,"Name",12);c.title=new("EditControl"):EditControl(ui.anchor,{16,264,left,28},profile.title,nil,nil,120,function(value) profile.title=value;for _,entry in ipairs(c.profile.list) do if entry.val==profile.id then entry.label=value end end;draft() end)
		c.preset=new("DropDownControl"):DropDownControl(ui.anchor,{16,306,left/2-6,26},{{label="Campaign",val="campaign"},{label="Early maps",val="early_maps"},{label="Endgame",val="endgame"}},function(_,value) profile.preset=value.val;draft() end);c.preset:SelByValue(profile.preset,"val")
		c.mode=new("DropDownControl"):DropDownControl(ui.anchor,{28+left/2-6,306,left/2-6,26},{"Normal","Ruthless"},function(_,value) profile.mode=value;draft();reopen() end);c.mode:SelByValue(profile.mode)
		ui.label(c,"strictLabel",16,346,"Strictness",12);c.strictness=new("DropDownControl"):DropDownControl(ui.anchor,{16,364,left,26},filters.strictness,function(index) profile.strictness=index-1;draft();reopen() end);c.strictness.selIndex=profile.strictness+1
		button(c,"generate",16,406,left,"Auto-adjust for this build",function() profile.rules=filters.generate(build,profile);draft();reopen() end)
		button(c,"customize",16,448,left,"Customize pickups  >",function() page="Customize";reopen() end)
		sceneControl("preview",left+32,214,right,h-288,library.scene(profile,build,"Mixed drops",0,83),true)
		ui.description(c,"sceneHint",left+32,h-68,right,24,{"Live filter appearance. Open Simulate for drop inspection."},14)
	elseif page=="Customize" then
		local sidebar=152;local listX=184;local listW=math.floor((w-216)*0.51);local detailX=listX+listW+16;local detailW=w-detailX-16
		local ok,base=pcall(library.catalog,profile);catalog=ok and base or {}
		local sourceEntries=scope=="Base filter" and catalog or library.personal(profile)
		for i,name in ipairs(library.categories) do local control=button(c,"category"..i,16,120+(i-1)*38,sidebar,name,function() category=name;selected=nil;reopen() end);control.locked=category==name end
		c.search=new("EditControl"):EditControl(ui.anchor,{listX,120,listW-138,26},query,"Find an item or rule",nil,160,function(value) query=value end)
		c.source=new("DropDownControl"):DropDownControl(ui.anchor,{listX+listW-130,120,130,26},{"My rules","Base filter"},function(_,value) scope=value;selected=nil;query="";reopen() end);c.source:SelByValue(scope)
		c.rules=new("TextListControl"):TextListControl(ui.anchor,{listX,170,listW,h-274},nil,{})
		ui.label(c,"ruleCount",listX,152,"",12)
		local function refreshList()
			entries=library.entries(profile,sourceEntries,category,query);local rows={};selectedEntry=nil
			for _,entry in ipairs(entries) do if entry.rule.id==selected then selectedEntry=entry end;rows[#rows+1]={height=76,textSize=14,"",entry=entry} end
			if not selectedEntry then selectedEntry=entries[1];selected=selectedEntry and selectedEntry.rule.id end
			if #rows==0 then rows=ui.rows({scope=="My rules" and "No personal pickups here yet." or "No matching base rules.","Try another category or search."},listW-28,14) end
			c.rules.list=rows;updateSelection(selectedEntry)
			c.ruleCount.label="^7"..#entries.." matching rules"
		end
		local draw=c.rules.Draw
		function c.rules:Draw(viewport)
			draw(self,viewport);local x,y=self:GetPos();local width,height=self:GetSize();SetViewport(x+2,y+2,width-20,height-4);local top=-self.controls.scrollBar.offset
			for _,row in ipairs(self.list) do if row.entry and top+row.height>0 and top<height then local entry=row.entry
				visual.box(2,top+2,width-24,70,selected==entry.rule.id and "^x293D50" or "^x17232E");visual.text(12,top+8,14,entry.rule.title,selected==entry.rule.id and "^xF0D49B" or "^xDCE5EC",width-44)
				local styles=entry.block.styles;visual.chip(8,top+24,width-34,32,entry.sample,{action=entry.block.action,styles={SetTextColor=styles.SetTextColor,SetBorderColor=styles.SetBorderColor,SetBackgroundColor=styles.SetBackgroundColor,SetFontSize={"24"}}})
				visual.text(12,top+58,12,(entry.rule.enabled==false and "DISABLED / " or "")..entry.category.." / "..entry.tier,"^x9DB0C1",width-44)
			end;top=top+row.height end;SetViewport()
		end
		ui.selectable(c.rules,function(row) return row.entry and row.entry.rule.id end,function(row) updateSelection(row.entry) end,edit)
		c.search.changeFunc=function(value) query=value;refreshList() end
		local bw=math.floor((listW-24)/4)
		button(c,"add",listX,h-94,bw,"+ Rule",function() controller.EditRule(filters.rule("rule-"..identifier(),"New pickup",{'BaseType == "Iron Hat"'}),keepRule) end)
		button(c,"edit",listX+bw+8,h-94,bw,"Edit",edit)
		button(c,"toggle",listX+(bw+8)*2,h-94,bw,"On / off",function() if selectedEntry then local rule=copyTable(selectedEntry.rule)
			if selectedEntry.base then rule.text=rule.text:gsub("^%a+",selectedEntry.block.action=="Show" and (profile.mode=="Ruthless" and "Minimal" or "Hide") or "Show");rule.enabled=true else rule.enabled=not rule.enabled end
			keepRule(rule)
		end end)
		c.toggle.label=function() return selectedEntry and (selectedEntry.base and (selectedEntry.block.action=="Show" and "Hide" or "Show") or selectedEntry.rule.enabled==false and "Enable" or "Disable") or "On / off" end
		button(c,"remove",listX+(bw+8)*3,h-94,bw,"Delete",function() if selectedEntry and not selectedEntry.base then for i,r in ipairs(profile.rules) do if r.id==selected then table.remove(profile.rules,i);break end end;selected=nil;draft();reopen() end end)
		c.remove.enabled=function() return selectedEntry~=nil and not selectedEntry.base end
		local function move(delta) if selectedEntry and not selectedEntry.base then for i,rule in ipairs(profile.rules) do if rule.id==selected then local next=i+delta;if next>=1 and next<=#profile.rules then profile.rules[i],profile.rules[next]=profile.rules[next],profile.rules[i];draft();reopen() end;break end end end end
		button(c,"up",listX+listW-62,148,26,"^",function() move(-1) end);c.up.height=20
		button(c,"down",listX+listW-30,148,26,"v",function() move(1) end);c.down.height=20
		c.up.enabled=function() return selectedEntry~=nil and not selectedEntry.base end;c.down.enabled=c.up.enabled
		c.preview=new("Control"):Control(ui.anchor,{detailX,120,detailW,126});backgrounds.preview=true
		function c.preview:Draw() local x,y=self:GetPos();visual.floor(x,y,detailW,126);visual.chip(x+8,y+8,detailW-16,112,item,result) end
		c.detail=new("TextListControl"):TextListControl(ui.anchor,{detailX,260,detailW,h-382},nil,{})
		button(c,"appearance",detailX,h-110,detailW,"Colours, sound & size",edit)
		button(c,"sampleEdit",detailX,h-72,detailW,"Test sample properties",function() controller.EditSample(item,function(next) item=next;compile() end) end)
		refreshList()
	elseif page=="Simulate" then
		local left=208;local groundX=240;local groundW=w-256
		ui.label(c,"sceneTitle",16,124,"Loot simulator",20)
		c.sceneKind=new("DropDownControl"):DropDownControl(ui.anchor,{16,162,left,26},{"Mixed drops","Build targets","Currency"},function(_,value) sceneKind=value;reopen() end);c.sceneKind:SelByValue(sceneKind)
		button(c,"regenerate",16,202,left,"Generate sample loot",function() seed=seed+1;reopen() end)
		button(c,"hidden",16,242,left,showHidden and "Hidden drops: visible" or "Hidden drops: off",function() showHidden=not showHidden;reopen() end)
		button(c,"sampleEdit",16,282,left,"Configure an item",function() controller.EditSample(item,function(next) item=next;compile();reopen() end) end)
		button(c,"sound",16,322,left,"Preview selected sound",function() local _,message=require("Modules.LootFilterAudio").play(result and result.styles or {});c.selection.list=ui.rows({item.BaseType,message},left-28,14) end)
		c.selection=new("TextListControl"):TextListControl(ui.anchor,{16,370,left,h-434},nil,ui.rows({item.BaseType,result and result.action or "Choose a drop",result and result.ruleTitle or "Select a drop to inspect the rule."},left-28,14))
		scene=library.scene(profile,build,sceneKind,seed,83);table.insert(scene,1,item);sceneControl("preview",groundX,120,groundW,h-182,scene,true)
	else
		ui.label(c,"styleHeading",16,128,"A palette for your pickups",22)
		ui.description(c,"styleHelp",16,164,w-32,44,{"Choose the default style for generated targets, or edit a specific pickup in Customize. Existing base-preset colours are preserved."},14)
		local sw=math.floor((w-48)/2)
		for i,entry in ipairs({{"Gold / cyan","default",{255,235,175},{105,195,245},{20,30,45}},{"High contrast","contrast",{255,255,255},{255,220,0},{0,0,0}}}) do
			local x=16+(i-1)*(sw+16);local key="style"..i;local control=button(c,key,x,226,sw,entry[1],function() profile.theme=entry[2];draft();reopen() end);control.height=180;custom[key]=true;control.planningFocusable=true
			function control:Draw() local px,py=self:GetPos();visual.box(px,py,sw,180,profile.theme==entry[2] and "^xD1B579" or "^x384A5B");visual.box(px+1,py+1,sw-2,178,"^x14202C");visual.floor(px+12,py+12,sw-24,94);visual.chip(px+20,py+20,sw-40,76,{BaseType="Crafting base"},{action="Show",styles={SetTextColor=entry[3],SetBorderColor=entry[4],SetBackgroundColor=entry[5],SetFontSize={"42"}}});visual.text(px+18,py+124,20,entry[1],"^xEED39D",sw-36);visual.text(px+18,py+154,14,profile.theme==entry[2] and "Selected for new build targets" or "Use this palette","^xAFC2D3",sw-36) end
		end
		button(c,"applyStyle",16,438,260,"Restyle personal pickups",function() local template=parser.parse(filters.rule("style","Style",{},nil,profile.theme).text).rules[1].styles;for i,rule in ipairs(profile.rules) do profile.rules[i]=library.appearance(rule,template);profile.rules[i].origin=rule.origin end;draft();reopen() end)
	end
	if profile then
		button(c,"export",w-172,h-38,156,"Export to PoE",function() if raw then controller.Export(profile,raw) end end)
		ui.label(c,"saveHint",16,h-30,dirty and "Working draft / Keep in build, then Save" or "Kept profiles travel with your build",12)
		c.saveHint.label=function() return "^7"..(dirty and "Working draft / Keep in build, then Save" or "Kept profiles travel with your build") end
	end
	layout.snapshot=snapshot
	for _,control in pairs(c) do control.layoutAudit="loot-filter-workspace" end
	ui.style(c,{keep=true,export=true},custom);visual.layers(c,backgrounds);layout.mount(w,h,"Loot filter",c)
end
return M
