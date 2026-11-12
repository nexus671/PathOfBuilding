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
local function modal(title,raw,save)
	local c={};local w,h=math.min(860,main.screenW-40),math.min(570,main.screenH-60)
	ui.description(c,"help",16,28,w-32,44,{save and "Paste an exported .filter. Original text is preserved; personal rules stay separate." or "Ready to save as a UTF-8 .filter in your Path of Exile filter folder. Copy does not change any game files."},14)
	c.text=new("EditControl"):EditControl(ui.anchor,{16,84,w-32,h-150},raw,nil,"^%C\t\n",filters.limit,nil,14,true)
	button(c,"copy",16,h-48,124,"Copy filter",function() Copy(c.text.buf) end)
	if save then button(c,"import",152,h-48,140,"Use import",function() attempt(function() save(c.text.buf);main:ClosePopup() end) end) end
	button(c,"close",w-140,h-48,124,"Close",function() main:ClosePopup() end)
	ui.style(c);main:OpenPopup(w,h,title,c,nil,"text","close")
end
function M.Conditions(rule,save)
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
		if c.sound.selIndex>1 then if c.sound.selIndex==2 then styles.PlayAlertSound=nil else styles.PlayAlertSound={c.sound.selIndex==3 and "2" or "6","200"} end;styles.CustomAlertSound=nil;styles.CustomAlertSoundOptional=nil;styles.PlayAlertSoundPositional=nil end
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
function M.EditRule(rule,save)
 require("Classes.LootFilterAppearance").Open(rule,function(nextRule)
  local profile=filters.profile("validate","Validate");profile.rules={nextRule};filters.validate({schemaVersion=1,activeId=profile.id,profiles={profile}})
  save(nextRule)
 end,M.Conditions)
end
function M.Import(save)
 modal("Import loot filter","",function(raw)
  local parsed=parser.parse(raw);assert(#parsed.rules>0,"No filter rules found")
  for _,d in ipairs(parsed.diagnostics) do assert(not d.error,d.error) end
  save(raw)
 end)
end
function M.Open(build,source,layout)
 return require("Classes.LootFilterWorkspace").Open(build,source,layout,M)
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
	local fields={"BaseType","Class","Rarity","ItemLevel","AreaLevel","UnidentifiedItemTier","SocketGroup","Sockets","SocketColours","LinkedSockets","StackSize","GemLevel","MapTier","Quality","Fated","Identified","Corrupted","FracturedItem","HasInfluence"}
	for i,key in ipairs(fields) do local x=16+((i-1)%3)*(w/3);local y=28+math.floor((i-1)/3)*56;ui.label(c,key.."Label",x,y,key:gsub("(%l)(%u)","%1 %2"),14)
		local value=item[key];if type(value)=="table" then value=table.concat(value," ") end
		c[key]=new("EditControl"):EditControl(ui.anchor,{x,y+18,w/3-32,24},tostring(value==nil and "" or value),nil,nil,240)
	end
	button(c,"useSample",16,h-48,140,"Test drop",function() attempt(function()
		local nextItem=copyTable(item);for _,key in ipairs(fields) do local v=c[key].buf
			if parser.numeric[key] then local n=v~="" and tonumber(v);assert(v=="" or n and n==n and math.abs(n)<1e9,"Enter a finite number for "..key);nextItem[key]=n or nil
			elseif parser.booleans[key] then assert(v=="true" or v=="false" or v=="","Use true or false for "..key);if v=="" then nextItem[key]=nil else nextItem[key]=v=="true" end
			elseif key=="HasInfluence" then nextItem[key]=parser.tokens(v)
			else nextItem[key]=v~="" and v or nil end
		end;save(nextItem);main:ClosePopup()
	end) end)
	button(c,"cancel",w-156,h-48,140,"Cancel",function() main:ClosePopup() end);ui.style(c,{useSample=true});main:OpenPopup(w,h,"Test a drop",c,nil,"BaseType","cancel")
end
function M.Export(profile,raw)
	local c={};local w,h=math.min(800,main.screenW-40),342
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
	button(c,"writeAll",16,282,280,"Save all seven strictnesses",function() attempt(function()
		assert(c.filename.buf:match("^[%w_-]+%.filter$"),"Use a filename with letters, numbers, hyphens or underscores")
		local directory=c.directory.buf;assert(directory~="" and not directory:find("[%c]"),"Choose a directory")
		local variants=filters.variants(profile);local targets={}
		for i,variant in ipairs(variants) do
			local target=directory.."/"..c.filename.buf:gsub("%.filter$","-"..variant.strictness..".filter");local existing=io.open(target,"rb")
			if existing then existing:close();error("Batch cancelled: file already exists: "..target) end;targets[i]=target
		end
		MakeDir(directory);local written=0
		for i,variant in ipairs(variants) do
			local file=io.open(targets[i],"wb");assert(file,"Could not create "..targets[i]..". Files already written: "..written)
			local ok=file:write(variant.text);local closed=file:close();assert(ok and closed,"Could not finish "..targets[i]..". Files already completed: "..written);written=written+1
		end
		notify("Filters exported","Saved seven strictnesses to "..directory)
	end) end)
	c.writeAll.enabled=not profile.template;c.writeAll.tooltipText="Keeps personal rules and global appearance in every variant. Imported filters have no preset variants."
	button(c,"close",w-156,236,140,"Close",function() main:ClosePopup() end);ui.style(c,{write=true});main:OpenPopup(w,h,"Export loot filter",c,nil,"filename","close")
end
function M.Audit(profile,report,save)
	local entries={};for name,value in pairs(report and report.changes or {}) do entries[#entries+1]={id=name,label=name,details={value=="removed" and "Removed in 3.30. An empty BaseType list removes its entire rule." or "Renamed to "..value}} end
	for i,d in ipairs(report and report.diagnostics or {}) do entries[#entries+1]={id="diagnostic-"..i,label="Line "..d.line,details={d.error or d.warning}} end
	entries[#entries+1]={id="update",label="Update bundled NeverSink base",details={"Saved revision: "..profile.baseCommit,"Bundled revision: "..filters.source().commit,"Personal rules and original imported text are preserved. Templates refresh with fork releases; no live economy feed is implied.","New 3.30 items have explicit Show rules until tiering is available."}}
	require("Classes.PlanningBrowserControl").Open("Filter audit",entries,{action="Use current base",closeOnChoose=false,choose=function(entry) if entry.id=="update" then save(filters.update(profile));main:ClosePopup() end end})
end
return M
