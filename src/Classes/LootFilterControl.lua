-- A graphical rule workbench. Raw filter text is confined to import/export.
local ui=require("Modules.PlanningUI")
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local M={}
local function button(c,key,x,y,w,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run);return c[key] end
local function notify(title,message)
	local c={};local w,h=math.min(760,main.screenW-40),math.min(360,main.screenH-60)
	ui.description(c,"message",16,28,w-32,h-100,{tostring(message)},16)
	button(c,"close",w-156,h-48,140,"Close",function() main:ClosePopup() end);ui.style(c);main:OpenPopup(w,h,title,c,"close",nil,"close")
end
local function attempt(callback) local ok,why=pcall(callback);if not ok then notify("Loot filter",why) end end
local function id(prefix) return prefix.."-"..os.time().."-"..tostring(GetTime()):gsub("%W","") end
local function modal(title,raw,save)
	local c={};local w,h=math.min(860,main.screenW-40),math.min(570,main.screenH-60)
	ui.description(c,"help",16,28,w-32,44,{save and "Paste an exported .filter. Original text is preserved; personal rules stay separate." or "Ready to save as a UTF-8 .filter in your Path of Exile filter folder. Copy does not change any game files."},14)
	c.text=new("EditControl"):EditControl(ui.anchor,{16,84,w-32,h-150},raw,nil,"^%C\t\n",filters.limit,nil,14,true)
	button(c,"copy",16,h-48,124,"Copy filter",function() Copy(c.text.buf) end)
	if save then button(c,"import",152,h-48,140,"Use import",function() attempt(function() save(c.text.buf);main:ClosePopup() end) end) end
	button(c,"close",w-140,h-48,124,"Close",function() main:ClosePopup() end)
	ui.style(c);main:OpenPopup(w,h,title,c,nil,"text","close")
end
local function sample(rule)
	local item={BaseType="Chaos Orb",Class="Stackable Currency",Rarity="Normal",ItemLevel=86,AreaLevel=83,DropLevel=1,Quality=0,StackSize=1,Sockets=0,SocketGroup="",LinkedSockets=0,Width=1,Height=1,UnidentifiedItemTier=0,HasInfluence={"None"}}
	for key in pairs(parser.booleans) do item[key]=false end
	if rule then
		local parsed=parser.parse(rule.text);for _,c in ipairs(parsed.rules[1].conditions) do
			if parser.numeric[c.keyword] then item[c.keyword]=tonumber(c.values[1]) or c.values[1]
			elseif parser.booleans[c.keyword] then item[c.keyword]=c.values[1]=="True"
			elseif c.keyword=="HasInfluence" then item[c.keyword]=copyTable(c.values)
			else item[c.keyword]=c.values[tonumber(c.values[1]) and 2 or 1] end
		end
	end
	return item
end
function M.EditRule(rule,save)
	local c={};local w,h=math.min(880,main.screenW-40),math.min(600,main.screenH-60);local parsed=parser.parse(rule.text);local block=parsed.rules[1]
	local conditions=copyTable(block.conditions);local keywords={"BaseType","Class","Rarity","ItemLevel","AreaLevel","Quality","LinkedSockets","Sockets","SocketGroup","GemLevel","MapTier","StackSize","UnidentifiedItemTier","Fated","Identified","Corrupted","FracturedItem","HasInfluence"}
	for _,condition in ipairs(conditions) do local known=false;for _,k in ipairs(keywords) do if k==condition.keyword then known=true end end;if not known then keywords[#keywords+1]=condition.keyword end end
	ui.label(c,"nameLabel",16,28,"Rule name",14);c.title=new("EditControl"):EditControl(ui.anchor,{16,50,w-200,26},rule.title,nil,nil,160)
	c.action=new("DropDownControl"):DropDownControl(ui.anchor,{w-168,50,152,26},{"Show","Hide","Minimal"});c.action:SelByValue(block.action)
	ui.description(c,"hint",16,88,w-32,42,{"All conditions must match. Add values in quotes for names with spaces. A filter cannot inspect unidentified explicit modifiers."},14)
	local rows=math.max(1,math.floor((h-280)/40));local offset=1;local dialog
	local function drawConditions()
		for i=1,rows do
			local index=offset+i-1;local condition=conditions[index];local y=142+(i-1)*40
			for _,suffix in ipairs({"key","op","values","remove"}) do c["c"..i..suffix]=nil end
			if condition then
				c["c"..i.."key"]=new("DropDownControl"):DropDownControl(ui.anchor,{16,y,190,26},keywords,function(_,value) condition.keyword=value end);c["c"..i.."key"]:SelByValue(condition.keyword)
				c["c"..i.."op"]=new("DropDownControl"):DropDownControl(ui.anchor,{218,y,72,26},{"=","==",">=","<=",">","<","!="},function(_,value) condition.operator=value end);c["c"..i.."op"]:SelByValue(condition.operator)
				local values={};for _,v in ipairs(condition.values) do values[#values+1]=v:find(" ",1,true) and filters.quote(v) or v end
				c["c"..i.."values"]=new("EditControl"):EditControl(ui.anchor,{302,y,w-366,26},table.concat(values," "),nil,nil,2000,function(value) local ok,result=pcall(parser.tokens,value);condition.invalid=not ok;if ok then condition.values=result end end)
				button(c,"c"..i.."remove",w-52,y,36,"X",function() table.remove(conditions,index);drawConditions() end)
			end
		end
		if dialog then for _,control in pairs(c) do if not control.anchor.other then control.anchor.other=dialog end end;ui.style(c,{keepRule=true}) end
	end
	local styleY=h-124
	ui.label(c,"themeLabel",16,styleY-24,"Label style",14)
	c.theme=new("DropDownControl"):DropDownControl(ui.anchor,{16,styleY,160,26},{"Keep original","Gold / cyan","High contrast"})
	c.sound=new("DropDownControl"):DropDownControl(ui.anchor,{188,styleY,164,26},{"Keep sound","Silent","Alert 2","Alert 6"})
	button(c,"addCondition",364,styleY,140,"Add condition",function() conditions[#conditions+1]={keyword="BaseType",operator="==",values={"Iron Hat"}};offset=math.max(1,#conditions-rows+1);drawConditions() end)
	button(c,"previous",516,styleY,60,"<",function() offset=math.max(1,offset-rows);drawConditions() end)
	button(c,"next",588,styleY,60,">",function() offset=math.min(math.max(1,#conditions-rows+1),offset+rows);drawConditions() end)
	button(c,"keepRule",16,h-48,140,"Keep rule",function() attempt(function()
		local lines={c.action:GetSelValue()};for _,condition in ipairs(conditions) do
			assert(not condition.invalid,"Close every quoted condition value")
			local controlValues={};for _,value in ipairs(condition.values) do controlValues[#controlValues+1]=((parser.strings[condition.keyword] and not tonumber(value)) or value:find("%s")) and filters.quote(value) or value end
			assert(#controlValues>0,"Every condition needs a value");lines[#lines+1]="    "..condition.keyword.." "..condition.operator.." "..table.concat(controlValues," ")
		end
		local styles=copyTable(block.styles)
		if c.theme.selIndex>1 then local generated=filters.rule("style","Style",{},nil,c.theme.selIndex==3 and "contrast" or "default");local style=parser.parse(generated.text).rules[1].styles;for key,value in pairs(style) do styles[key]=value end end
		if c.sound.selIndex>1 then styles.PlayAlertSound=c.sound.selIndex==2 and nil or {c.sound.selIndex==3 and "2" or "6","200"};styles.CustomAlertSound=nil;styles.CustomAlertSoundOptional=nil;styles.PlayAlertSoundPositional=nil end
		local keys={};for key in pairs(styles) do keys[#keys+1]=key end;table.sort(keys)
		for _,key in ipairs(keys) do local values=styles[key];local quoted=key:match("^CustomAlertSound") and (filters.quote(values[1])..(#values>1 and " "..table.concat(values," ",2) or "")) or table.concat(values," ");lines[#lines+1]="    "..key.." "..quoted end
		if block.continue then lines[#lines+1]="    Continue" end
		local nextRule=copyTable(rule);nextRule.title=c.title.buf;nextRule.text=table.concat(lines,"\n");nextRule.origin=nil
		local p=filters.profile("validate","Validate");p.rules={nextRule};filters.validate({schemaVersion=1,activeId=p.id,profiles={p}})
		save(nextRule);main:ClosePopup()
	end) end)
	button(c,"cancel",w-156,h-48,140,"Cancel",function() main:ClosePopup() end)
	drawConditions();ui.style(c,{keepRule=true});main:OpenPopup(w,h,"Loot filter rule",c,nil,"title","cancel");dialog=main.popups[1]
end
function M.Open(build,source,layout)
	local saver=build.savers.LootFilters;local c={};local w,h=layout.width,layout.height
	local data=source and source.data or copyTable(saver.data);local profile=filters.find(data,source and source.selected) or data.profiles[1]
	local selected=source and source.rule;local sampleItem=source and source.sample or sample();local compiled,report,result;local dirty=source and source.dirty or false
	local left=math.floor(w*0.38);local right=w-left-48
	local function draft() dirty=true;ui.draft(build,"filters") end
	local function reopen() layout.navigate("filters",{data=data,selected=profile and profile.id,rule=selected,sample=sampleItem,dirty=dirty}) end
	local function refresh()
		if profile then local ok,a,b=pcall(filters.compile,profile);if ok then compiled,report=a,b;result=parser.simulate(parser.parse(a),sampleItem);for _,d in ipairs(report.diagnostics) do if d.error then compiled=nil;result={status="invalid",action="Unknown",reasons={d.error},styles={}};break end end else compiled=nil;report={error=a};result={action="Unknown",reasons={a},styles={}} end end
		local list={};if profile then for _,r in ipairs(profile.rules) do list[#list+1]={height=30,textSize=15,"^7"..(r.enabled and "" or "[off] ")..ui.fit(r.title,left-80,15),rule=r} end end
		if #list==0 then list=ui.rows({"No personal rules yet.","Use build targets or add a rule."},left-32,14) end
		c.rules.list=list
		if c.sample then local found=false;for i,value in ipairs(c.sample.list) do if value==sampleItem.BaseType then c.sample.selIndex=i;found=true;break end end;if not found then c.sample.selIndex=#c.sample.list end end
		local lines={};if profile then
			lines[#lines+1]=(result and result.action or "Unknown").." | "..(result and result.status or "invalid")..(result and result.line and " | deciding line "..result.line or "")
			if result and result.ruleTitle then lines[#lines+1]=result.ruleTitle end
			for _,reason in ipairs(result and result.reasons or {}) do lines[#lines+1]=reason end
			if report and not report.error then local n=0;for _ in pairs(report.changes) do n=n+1 end
				lines[#lines+1]=report.rules.." compiled rules | "..n.." 3.30 migrations"
				lines[#lines+1]=(profile.template and "Imported base preserved" or "NeverSink "..filters.strictness[profile.strictness+1]).." | personal rules take priority"
				if profile.baseCommit~=filters.source().commit then lines[#lines+1]="A newer bundled base is available. Review Update base." end
				if #report.diagnostics>0 then lines[#lines+1]=#report.diagnostics.." parser diagnostics; use Audit to inspect." end
			end
		else lines={"Create a profile to start. Campaign, early mapping and endgame profiles can travel with this build."} end
		if saver.warning then lines[#lines+1]=saver.warning end
		c.explanation.list=ui.rows(lines,right-28,14)
	end
	ui.label(c,"heading",16,16,"Loot filter",24)
	button(c,"sound",w-332,16,152,"Sound preview",function() local _,message=require("Modules.LootFilterAudio").play(result and result.styles or {});notify("Sound preview",message) end)
	button(c,"account",w-168,16,152,"Account filters",function() if profile then M.Account(profile,function(raw) profile.template=raw;draft();refresh() end) end end)
	ui.description(c,"intro",16,48,w-32,24,{"Pick up what your build needs. Preview every rule before exporting."},14)
	local choices={};for _,p in ipairs(data.profiles) do choices[#choices+1]={label=p.title,val=p.id} end;if #choices==0 then choices={{label="Create your first profile",val=""}} end
	c.profile=new("DropDownControl"):DropDownControl(ui.anchor,{16,84,left,28},choices,function(_,value) profile=filters.find(data,value.val);selected=nil;reopen() end);c.profile:SelByValue(profile and profile.id or "","val")
	c.title=new("EditControl"):EditControl(ui.anchor,{left+32,84,right-164,28},profile and profile.title or "",nil,nil,120,function(value) if profile then profile.title=value;for _,entry in ipairs(c.profile.list) do if entry.val==profile.id then entry.label=value end end;draft() end end)
	c.mode=new("DropDownControl"):DropDownControl(ui.anchor,{w-168,84,152,28},{"Normal","Ruthless"},function(_,value) if profile then profile.mode=value;draft();refresh() end end);c.mode:SelByValue(profile and profile.mode or "Normal")
	c.preset=new("DropDownControl"):DropDownControl(ui.anchor,{16,124,150,26},{{label="Campaign",val="campaign"},{label="Early maps",val="early_maps"},{label="Endgame",val="endgame"}},function(_,value) if profile then profile.preset=value.val;profile.strictness=value.val=="campaign" and 1 or value.val=="endgame" and 4 or 2;draft();reopen() end end);c.preset:SelByValue(profile and profile.preset or "early_maps","val")
	c.strictness=new("DropDownControl"):DropDownControl(ui.anchor,{178,124,left-162,26},filters.strictness,function(index) if profile then profile.strictness=index-1;draft();refresh() end end);c.strictness.selIndex=profile and profile.strictness+1 or 3
	c.theme=new("DropDownControl"):DropDownControl(ui.anchor,{left+32,124,164,26},{{label="Gold / cyan",val="default"},{label="High contrast",val="contrast"}},function(_,value) if profile then profile.theme=value.val;draft();refresh() end end);c.theme:SelByValue(profile and profile.theme or "default","val")
	button(c,"generate",left+208,124,right-176,"Use build targets",function() if profile then profile.rules=filters.generate(build,profile);selected=nil;draft();refresh() end end)
	ui.label(c,"rulesHeading",16,170,"Personal rules | first match wins",16)
	local function move(delta)
		if not profile then return end
		for i,r in ipairs(profile.rules) do if r.id==selected then local target=i+delta;if target>=1 and target<=#profile.rules then profile.rules[i],profile.rules[target]=profile.rules[target],profile.rules[i];draft();refresh() end;return end end
	end
	button(c,"up",left-48,162,28,"^",function() move(-1) end)
	button(c,"down",left-12,162,28,"v",function() move(1) end)
	c.rules=new("TextListControl"):TextListControl(ui.anchor,{16,198,left,h-302},nil,{})
	ui.selectable(c.rules,function(row) return row.rule and row.rule.id end,function(row) selected=row.rule.id;sampleItem=sample(row.rule);refresh() end)
	local function current() if profile then for _,r in ipairs(profile.rules) do if r.id==selected then return r end end end end
	local function put(rule) for i,r in ipairs(profile.rules) do if r.id==rule.id then profile.rules[i]=rule;draft();refresh();return end end;profile.rules[#profile.rules+1]=rule;selected=rule.id;draft();refresh() end
	local bw=math.floor((left-24)/4)
	button(c,"add",16,h-94,bw,"+ Rule",function() if profile then M.EditRule(filters.rule(id("rule"),"New pickup rule",{'BaseType == "Iron Hat"'}),put) end end)
	button(c,"edit",24+bw,h-94,bw,"Edit",function() if current() then M.EditRule(current(),put) end end)
	button(c,"toggle",32+bw*2,h-94,bw,"On / off",function() if current() then current().enabled=not current().enabled;draft();refresh() end end)
	button(c,"remove",40+bw*3,h-94,bw,"Delete",function() if current() then for i,r in ipairs(profile.rules) do if r.id==selected then table.remove(profile.rules,i);break end end;selected=nil;draft();refresh() end end)
	c.preview=new("Control"):Control(ui.anchor,{left+32,170,right,148})
	function c.preview:Draw()
		local x,y=self:GetPos();local width,height=self:GetSize();SetDrawColor(0.10,0.12,0.10);DrawImage(nil,x,y,width,height)
		local styles=result and result.styles or {};local function color(key,default) local v=styles[key] or default;SetDrawColor((tonumber(v[1]) or 255)/255,(tonumber(v[2]) or 255)/255,(tonumber(v[3]) or 255)/255,(tonumber(v[4]) or 255)/255) end
		local size=math.min(32,tonumber(styles.SetFontSize and styles.SetFontSize[1]) or 24);local label=ui.fit(sampleItem.BaseType or "Sample item",width-64,size);local labelWidth=DrawStringWidth(size,"VAR",label)+28
		local palette={Cyan={0.2,0.8,0.95},Red={0.95,0.25,0.2},Green={0.35,0.9,0.4},Blue={0.3,0.5,1},White={1,1,1},Yellow={1,0.9,0.2},Orange={1,0.55,0.2},Pink={1,0.4,0.75},Purple={0.7,0.4,1},Brown={0.6,0.4,0.2},Grey={0.6,0.6,0.6}}
		if styles.PlayEffect and styles.PlayEffect[1]~="None" then local color=palette[styles.PlayEffect[1]] or palette.Cyan
			for i=1,4 do SetDrawColor(color[1],color[2],color[3],0.10+i*0.08);DrawImage(nil,x+width/2-12+i*2,y+10,24-i*4,52) end
		end
		local icon=styles.MinimapIcon
		if icon and tonumber(icon[1]) and tonumber(icon[1])>=0 then
			local color=palette[icon[2]] or palette.White;local cx,cy=x+width-30,y+30
			SetDrawColor(0.08,0.1,0.12);DrawImage(nil,cx-22,cy-22,44,44);SetDrawColor(color[1],color[2],color[3])
			if icon[3]=="Diamond" then DrawImageQuad(nil,cx,cy-12,cx+12,cy,cx,cy+12,cx-12,cy)
			elseif icon[3]=="Triangle" then DrawImageQuad(nil,cx,cy-12,cx+12,cy+12,cx-12,cy+12,cx-12,cy+12)
			else DrawImage(nil,cx-9,cy-9,18,18) end
		end
		color("SetBorderColor",{140,155,140});DrawImage(nil,x+(width-labelWidth)/2-2,y+62,labelWidth+4,44)
		color("SetBackgroundColor",{10,15,10});DrawImage(nil,x+(width-labelWidth)/2,y+64,labelWidth,40)
		color("SetTextColor",{220,225,215});DrawString(x+width/2,y+68,"CENTER_X",size,"VAR",label)
		SetDrawColor(0.85,0.88,0.9);DrawString(x+12,y+height-26,"LEFT",14,"VAR",result and result.action=="Hide" and "Hidden in game | shown here for inspection" or "Drop preview")
	end
	c.sample=new("DropDownControl"):DropDownControl(ui.anchor,{left+32,330,right-164,26},{"Chaos Orb","Iron Hat","Frayed Thread","Enshrouded Quiver","Coven Queen's Crown","Custom drop"},function(_,value) if value=="Custom drop" then M.EditSample(sampleItem,function(item) sampleItem=item;refresh() end);return end;sampleItem=sample();sampleItem.BaseType=value;if value=="Iron Hat" then sampleItem.Class="Helmets" end;for class,items in pairs(filters.patch().added) do for _,name in ipairs(items) do if name==value then sampleItem.Class=class end end end;refresh() end)
	button(c,"sampleEdit",w-168,330,152,"Sample properties",function()
		M.EditSample(sampleItem,function(item) sampleItem=item;refresh() end)
	end)
	c.explanation=new("TextListControl"):TextListControl(ui.anchor,{left+32,368,right,math.max(44,h-426)},nil,{})
	local width=math.floor((w-80)/7)
	local function footer(key,i,label,run) button(c,key,16+(width+8)*i,h-48,width,label,run) end
	footer("new",0,"New profile",function() profile=filters.profile(id("filter"),"New loot filter","early_maps");data.profiles[#data.profiles+1]=profile;data.activeId=profile.id;selected=nil;draft();reopen() end)
	footer("duplicate",1,"Duplicate",function() if profile then profile=copyTable(profile);profile.id=id("filter");profile.title=profile.title.." copy";data.profiles[#data.profiles+1]=profile;draft();reopen() end end)
	footer("import",2,"Import",function() modal("Import loot filter","",function(raw) local parsed=parser.parse(raw);assert(#parsed.rules>0,"No filter rules found");for _,d in ipairs(parsed.diagnostics) do assert(not d.error,d.error) end;if not profile then profile=filters.profile(id("filter"),"Imported filter");data.profiles[#data.profiles+1]=profile end;profile.template=raw;draft();reopen() end) end)
	footer("export",3,"Export",function() if compiled then M.Export(profile,compiled) end end)
	footer("audit",4,"Audit / update",function() if profile then M.Audit(profile,report,function(nextProfile) for i,p in ipairs(data.profiles) do if p.id==nextProfile.id then data.profiles[i]=nextProfile end end;profile=nextProfile;draft();refresh() end) end end)
	footer("keep",5,"Keep in build",function() attempt(function() if profile then data.activeId=profile.id end;saver:Replace(data);dirty=false;refresh() end) end)
	footer("deleteProfile",6,"Delete profile",function() if profile then for i,p in ipairs(data.profiles) do if p==profile then table.remove(data.profiles,i);break end end;profile=data.profiles[1];data.activeId=profile and profile.id or "";draft();reopen() end end)
	for _,key in ipairs({"title","mode","preset","strictness","theme","generate","add","edit","toggle","remove","duplicate","export","audit","deleteProfile"}) do c[key].enabled=function() return profile~=nil and not saver.unreadable end end
	layout.snapshot=function() return {data=data,selected=profile and profile.id,rule=selected,sample=sampleItem,dirty=dirty} end
	refresh();for _,control in pairs(c) do control.layoutAudit="loot-filter-workspace" end;ui.style(c,{keep=true});layout.mount(w,h,"Loot filter",c)
end
function M.Account(profile,import)
	local account=require("Modules.LootFilterAccount");local c={};local w,h=math.min(900,main.screenW-40),math.min(560,main.screenH-60);local entries={};local selected;local status="No account request made."
	ui.description(c,"help",16,28,w-32,70,{"Optional account sync needs account:item_filter permission from GGG. Log in requests that additional scope; it may require OAuth client approval. Local export works independently. Publishing is explicit and sends this profile's compiled filter."},14)
	c.realm=new("DropDownControl"):DropDownControl(ui.anchor,{16,112,160,26},{"pc","xbox","sony"})
	c.entries=new("TextListControl"):TextListControl(ui.anchor,{16,154,w-32,h-298},nil,{})
	ui.selectable(c.entries,function(row) return row.entry and row.entry.id end,function(row) selected=row.entry end)
	c.status=new("TextListControl"):TextListControl(ui.anchor,{16,h-132,w-32,60},nil,ui.rows({status},w-64,14))
	local function show(message) status=message;c.status.list=ui.rows({status},w-64,14) end
	local function request(method,target,payload,done)
		attempt(function() show("Request in progress...");account.request(main.api,method,target,payload,function(value,err)
			if err then show(err) else local ok=pcall(done,value);if not ok then show("The account response was incomplete. Check your account before retrying a write.") end end
		end) end)
	end
	local bw=math.floor((w-72)/6)
	local function action(key,i,label,run) button(c,key,16+i*(bw+8),h-48,bw,label,run);c[key].enabled=function() return not account.busy end end
	action("login",0,"Log in",function() show("Complete login in your browser. If item-filter scope is unavailable, use local export.");main.api:FetchAuthToken(function(err) show(err and "Login failed; item-filter permission may need approval. Use local export." or "Logged in. List filters to check access.") end,true) end)
	action("fetch",1,"List filters",function() request("GET",nil,nil,function(value)
		entries=value.filters or {};local rows={};selected=nil;for _,entry in ipairs(entries) do rows[#rows+1]={height=30,textSize=15,"^7"..ui.fit((entry.filter_name or entry.id).." ["..(entry.realm or "?").."]",w-64,15),entry=entry} end;c.entries.list=rows
	end) end)
	action("importAccount",2,"Import selected",function() if selected then request("GET",selected.id,nil,function(value) assert(value.filter and value.filter.filter,"No filter text returned");import(value.filter.filter);show("Imported as a working draft. Keep in build and Save to persist.") end) else show("Select a listed filter first.") end end)
	local function publish(target)
		local raw,report=filters.compile(profile);for _,d in ipairs(report.diagnostics) do assert(not d.error,d.error) end
		local payload={filter_name=profile.title,realm=c.realm:GetSelValue(),description="Created with Path of Building AI Edition",version="3.30",type=profile.mode or "Normal",filter=raw}
		if not target then payload.public=false end
		if target then assert(selected.realm==payload.realm,"Choose the selected filter's realm before updating") end
		local confirmation={};local cw,ch=math.min(760,main.screenW-40),320
		ui.description(confirmation,"summary",16,28,cw-32,200,{target and "Replace account filter: "..(selected.filter_name or target).." ["..target.."]" or "Create a new private account filter: "..profile.title,"Realm: "..payload.realm.." | "..report.rules.." rules | "..#raw.." bytes","This publishes the current working profile, including personal rules and 3.30 migrations. Existing subscriptions are not changed. The server will validate against its current game version."},16)
		button(confirmation,"publish",16,ch-48,160,target and "Replace filter" or "Create filter",function() main:ClosePopup();request("POST",target,payload,function(value) show("Server confirmed valid filter "..value.filter.id..". Select it in game.") end) end)
		button(confirmation,"cancel",cw-176,ch-48,160,"Cancel",function() main:ClosePopup() end);ui.style(confirmation,{publish=true});main:OpenPopup(cw,ch,"Review account publication",confirmation,nil,nil,"cancel")
	end
	action("createAccount",3,"Publish new",function() attempt(function() publish() end) end)
	action("updateAccount",4,"Update selected",function() if selected then attempt(function() publish(selected.id) end) else show("Select a listed filter first.") end end)
	action("close",5,"Close",function() main:ClosePopup() end)
	ui.style(c);main:OpenPopup(w,h,"Account loot filters",c,nil,nil,"close")
end
function M.EditSample(item,save)
	local c={};local w,h=math.min(820,main.screenW-40),math.min(560,main.screenH-60)
	local fields={"BaseType","Class","Rarity","ItemLevel","AreaLevel","UnidentifiedItemTier","SocketGroup","Sockets","LinkedSockets","StackSize","GemLevel","MapTier","Quality","Fated","Identified","Corrupted","FracturedItem","HasInfluence"}
	for i,key in ipairs(fields) do local x=16+((i-1)%2)*(w/2);local y=28+math.floor((i-1)/2)*46;ui.label(c,key.."Label",x,y,key,14)
		local value=item[key];if type(value)=="table" then value=table.concat(value," ") end
		c[key]=new("EditControl"):EditControl(ui.anchor,{x,y+18,w/2-32,24},tostring(value==nil and "" or value),nil,nil,240)
	end
	button(c,"useSample",16,h-48,140,"Test drop",function() attempt(function()
		local nextItem=copyTable(item);for _,key in ipairs(fields) do local v=c[key].buf
			if parser.numeric[key] then nextItem[key]=v~="" and assert(tonumber(v),"Enter a number for "..key) or nil
			elseif parser.booleans[key] then assert(v=="true" or v=="false" or v=="","Use true or false for "..key);if v=="" then nextItem[key]=nil else nextItem[key]=v=="true" end
			elseif key=="HasInfluence" then nextItem[key]=parser.tokens(v)
			else nextItem[key]=v~="" and v or nil end
		end;save(nextItem);main:ClosePopup()
	end) end)
	button(c,"cancel",w-156,h-48,140,"Cancel",function() main:ClosePopup() end);ui.style(c,{useSample=true});main:OpenPopup(w,h,"Test a drop",c,nil,"BaseType","cancel")
end
function M.Export(profile,raw)
	local c={};local w,h=math.min(800,main.screenW-40),300
	ui.description(c,"help",16,28,w-32,62,{"Save a .filter file, then select it in Path of Exile's item-filter settings. Exporting does not equip items or change the character."},16)
	ui.label(c,"directoryLabel",16,106,"Destination directory",14)
	c.directory=new("EditControl"):EditControl(ui.anchor,{16,128,w-32,26},main.userPath.."LootFilters",nil,nil,1000)
	c.filename=new("EditControl"):EditControl(ui.anchor,{16,170,w-32,26},profile.id..".filter",nil,nil,120)
	button(c,"copy",16,236,140,"Copy .filter",function() Copy(raw) end)
	button(c,"write",168,236,140,"Save file",function() attempt(function()
		assert(c.filename.buf:match("^[%w_-]+%.filter$"),"Use a filename with letters, numbers, hyphens or underscores")
		local directory=c.directory.buf;assert(directory~="" and not directory:find("[%c]"),"Choose a directory")
		local target=directory.."/"..c.filename.buf;local existing=io.open(target,"rb")
		if existing then existing:close();notify("File exists","Choose another filename to preserve the existing filter.");return end
		MakeDir(directory);local file=assert(io.open(target,"wb"),"Could not create filter file");assert(file:write(raw));assert(file:close());notify("Filter exported",target)
	end) end)
	button(c,"raw",320,236,140,"Inspect text",function() modal("Compiled filter",raw) end)
	button(c,"close",w-156,236,140,"Close",function() main:ClosePopup() end);ui.style(c,{write=true});main:OpenPopup(w,h,"Export loot filter",c,nil,"filename","close")
end
function M.Audit(profile,report,save)
	local entries={};for name,value in pairs(report and report.changes or {}) do entries[#entries+1]={id=name,label=name,details={value=="removed" and "Removed in 3.30. An empty BaseType list removes its entire rule." or "Renamed to "..value}} end
	for i,d in ipairs(report and report.diagnostics or {}) do entries[#entries+1]={id="diagnostic-"..i,label="Line "..d.line,details={d.error or d.warning}} end
	entries[#entries+1]={id="update",label="Update bundled NeverSink base",details={"Saved revision: "..profile.baseCommit,"Bundled revision: "..filters.source().commit,"Personal rules and original imported text are preserved. Templates refresh with fork releases; no live economy feed is implied.","New 3.30 items have explicit Show rules until tiering is available."}}
	require("Classes.PlanningBrowserControl").Open("Filter audit",entries,{action="Use current base",closeOnChoose=false,choose=function(entry) if entry.id=="update" then save(filters.update(profile));main:ClosePopup() end end})
end
return M
