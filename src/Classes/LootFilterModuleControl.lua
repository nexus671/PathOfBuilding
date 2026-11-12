local ui=require("Modules.PlanningUI")
local editing=require("Modules.LootFilterEditing")
local M={}
function M.Mount(c,data,profile,w,h,options)
	local selected;local selectedRule
	local function button(key,x,y,width,title,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},title,run) end
	ui.label(c,"moduleHeading",16,124,"Reusable pickup modules",20)
	ui.description(c,"moduleHelp",16,158,w-32,44,{"Keep a named set of pickup rules in multiple profiles. Copies are portable snapshots; Update copies deliberately synchronises profiles in this build."},14)
	c.modules=new("TextListControl"):TextListControl(ui.anchor,{16,220,300,h-366},nil,{})
	c.moduleRules=new("TextListControl"):TextListControl(ui.anchor,{332,220,w-348,h-366},nil,{})
	local rows={}
	for _,module in ipairs(profile.modules or {}) do rows[#rows+1]={height=46,textSize=15,"^7"..ui.fit(module.title,268,15),subtitle=#module.rules.." rules | "..(module.enabled and "Enabled" or "Disabled"),module=module} end
	c.modules.list=#rows>0 and rows or ui.rows({"No modules in this profile.","Create one from your personal pickups, paste a shared module, or copy one from another profile."},268,14)
	local function show(module)
		selected=module;selectedRule=nil;local lines={}
		for _,rule in ipairs(module and module.rules or {}) do lines[#lines+1]={height=42,textSize=14,"^7"..ui.fit(rule.title,w-380,14),subtitle=rule.enabled and "Enabled pickup" or "Disabled pickup",rule=rule} end
		c.moduleRules.list=#lines>0 and lines or ui.rows({"Choose a module to inspect its rules."},w-380,14)
	end
	ui.selectable(c.modules,function(row) return row.module and row.module.id end,function(row) show(row.module) end)
	ui.selectable(c.moduleRules,function(row) return row.rule and row.rule.id end,function(row) selectedRule=row.rule end)
	button("moduleCreate",16,h-126,144,"Create module",function()
		local module=editing.module(profile,options.id(),c.moduleTitle.buf);local next=editing.install(profile,module);profile.modules=next.modules;options.change()
	end)
	c.moduleTitle=new("EditControl"):EditControl(ui.anchor,{172,h-126,144,28},"My pickups",nil,nil,160)
	button("modulePaste",16,h-86,144,"Paste module",function() local next=editing.install(profile,editing.import(Paste()));profile.modules=next.modules;options.change() end)
	button("moduleOther",172,h-86,144,"Other profiles",function()
		local entries={};for _,p in ipairs(data.profiles) do if p.id~=profile.id then for _,module in ipairs(p.modules or {}) do entries[#entries+1]={id=p.id..":"..module.id,label=module.title,category=p.title,details={#module.rules.." rules","Copies or updates the module snapshot in this profile."},module=module} end end end
		require("Classes.PlanningBrowserControl").Open("Copy a pickup module",entries,{action="Use module",choose=function(entry) profile.modules=editing.install(profile,entry.module).modules;options.change() end})
	end)
	button("moduleCopy",332,h-126,136,"Copy / share",function() Copy(editing.share(assert(selected,"Choose a module"))) end)
	button("moduleToggle",480,h-126,136,"Enable / disable",function() assert(selected,"Choose a module");selected.enabled=not selected.enabled;options.change() end)
	button("moduleRemove",628,h-126,136,"Remove",function() assert(selected,"Choose a module");for i,module in ipairs(profile.modules) do if module==selected then table.remove(profile.modules,i);break end end;options.change() end)
	button("moduleEdit",332,h-86,136,"Edit pickup",function() assert(selectedRule,"Choose a module pickup");local module=selected;options.edit(selectedRule,function(rule) for i,value in ipairs(module.rules) do if value.id==rule.id then module.rules[i]=rule end end;options.change() end) end)
	button("moduleUpdate",480,h-86,284,"Update copies in this build",function()
		assert(selected,"Choose a module");for _,p in ipairs(data.profiles) do for i,module in ipairs(p.modules or {}) do if module.id==selected.id then p.modules[i]=copyTable(selected) end end end;options.change()
	end)
	for _,key in ipairs({"moduleCopy","moduleToggle","moduleRemove","moduleUpdate"}) do c[key].enabled=function() return selected~=nil end end
	c.moduleEdit.enabled=function() return selectedRule~=nil end
	show(rows[1] and rows[1].module)
end
return M
