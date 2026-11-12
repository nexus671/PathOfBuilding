-- Local, portable editing primitives shared by the UI, compiler and AI proposals.
-- cspell:ignore jsontype
local parser=require("Modules.LootFilterParser")
local json=require("dkjson")
local encode=require("Modules.PlanningData").encode
local M={}
local function list(value)
	assert(type(value)=="table" and value~=json.null,"Expected an array")
	local meta=getmetatable(value);assert(not meta or meta.__jsontype~="object","Expected an array")
	for k in pairs(value) do assert(type(k)=="number" and k>=1 and k<=#value and k==math.floor(k),"Expected a dense array") end
	return value
end
local function label(value,limit)
	assert(type(value)=="string" and #value<=limit and value:match("%S") and not value:find("[%c]"),"Invalid name")
	return value
end
local function identity(value)
	assert(label(value,100):match("^[%w_-]+$"),"Invalid identity");return value
end
function M.items(text)
	local block=parser.parse(text).rules[1];local values
	assert(block,"A tier needs a filter block")
	for _,c in ipairs(block.conditions) do if c.keyword=="BaseType" then
		assert(not values and c.operator=="==","Tier editing requires one exact BaseType condition")
		values=copyTable(c.values)
	end end
	return assert(values,"This block has no exact item list")
end
function M.withItems(text,items)
	M.items(text);local values={};for _,name in ipairs(items) do values[#values+1]=require("Modules.LootFilters").quote(name) end
	assert(#values>0,"An empty tier does not produce a filter rule")
	local lines={};for line in (text.."\n"):gmatch("([^\n]*)\n") do
		if line:match("^%s*BaseType%s") then line="    BaseType == "..table.concat(values," ") end
		lines[#lines+1]=line
	end
	return table.concat(lines,"\n")
end
function M.validateTiers(tiers)
	local result,seen={},{}
	for _,tier in ipairs(list(tiers)) do
		local next={id=identity(tier.id),title=label(tier.title,160),items={},text=tier.text,enabled=tier.enabled~=false}
		assert(not seen[next.id],"Duplicate tier identity");seen[next.id]=true
		assert(type(next.text)=="string" and #next.text<=24000,"Invalid tier template")
		local parsed=parser.parse(next.text);assert(#parsed.rules==1 and #parsed.imports==0,"Use one block per tier")
		for _,d in ipairs(parsed.diagnostics) do assert(not d.error,d.error) end;M.items(next.text)
		local names={};for _,name in ipairs(list(tier.items)) do name=label(name,240);require("Modules.LootFilters").quote(name);assert(not names[name],"Duplicate item in tier");names[name]=true;next.items[#next.items+1]=name end
		result[#result+1]=next
	end
	return result
end
function M.rule(tier)
	if #tier.items==0 or tier.enabled==false then return end
	return {id=tier.id,title=tier.title,text=M.withItems(tier.text,tier.items),enabled=true}
end
function M.newTier(id,title,source)
	local text=source or require("Modules.LootFilters").rule(id,title,{'Class == "Stackable Currency"','BaseType == "Chaos Orb"'}).text
	M.items(text);return {id=id,title=title,text=text,items={},enabled=true}
end
function M.assignmentIssue(profile,id,name,sourceText)
	local destination;for _,tier in ipairs(profile.tiers or {}) do if tier.id==id then destination=tier end end
	if not destination then return "Choose a destination tier" end
	local function classes(text)
		if not text then return end
		for _,condition in ipairs(parser.parse(text).rules[1].conditions) do if condition.keyword=="Class" and condition.operator=="==" then return condition.values end end
	end
	if not sourceText then for _,tier in ipairs(profile.tiers or {}) do for _,item in ipairs(tier.items) do if item==name then sourceText=tier.text;break end end;if sourceText then break end end end
	local from,to=classes(sourceText),classes(destination.text)
	if from and to then local overlap=false;for _,a in ipairs(from) do for _,b in ipairs(to) do if a==b then overlap=true end end end
		if not overlap then return "These tiers require different item classes. Edit the destination conditions or use a compatible tier." end
	end
end
function M.assign(profile,id,name,sourceText)
	label(name,240);assert(not M.assignmentIssue(profile,id,name,sourceText),M.assignmentIssue(profile,id,name,sourceText))
	local next=copyTable(profile);local destination;for _,tier in ipairs(next.tiers or {}) do if tier.id==id then destination=tier end end
	for _,tier in ipairs(next.tiers) do for i=#tier.items,1,-1 do if tier.items[i]==name then table.remove(tier.items,i) end end end
	destination.items[#destination.items+1]=name
	M.validateTiers(next.tiers);return next
end
function M.validateModules(modules)
	local result,seen={},{};local filters=require("Modules.LootFilters")
	for _,module in ipairs(list(modules)) do
		local next={id=identity(module.id),title=label(module.title,160),enabled=module.enabled~=false}
		assert(not seen[next.id],"Duplicate module identity");seen[next.id]=true
		local p=filters.profile("module","Module");p.rules=module.rules
		next.rules=filters.validate({schemaVersion=1,activeId=p.id,profiles={p}}).profiles[1].rules
		for _,rule in ipairs(next.rules) do rule.origin=nil end
		result[#result+1]=next
	end
	return result
end
function M.module(profile,id,title)
	local rules=copyTable(profile.rules)
	for _,tier in ipairs(profile.tiers or {}) do local rule=M.rule(tier);if rule then rule.id="tier-"..require("sha1")(tier.id):sub(1,20);rules[#rules+1]=rule end end
	return M.validateModules({{id=id,title=title,rules=rules}})[1]
end
function M.install(profile,module)
	module=M.validateModules({module})[1];local next=copyTable(profile);next.modules=next.modules or {}
	for i,value in ipairs(next.modules) do if value.id==module.id then next.modules[i]=module;return next end end
	next.modules[#next.modules+1]=module;return next
end
function M.share(module) return json.encode({schemaVersion=1,lootFilterModule=M.validateModules({module})[1]},{indent=true}) end
function M.import(raw)
	assert(type(raw)=="string" and #raw<=require("Modules.LootFilters").limit,"Module exceeds 2 MiB")
	local data=assert(json.decode(raw));assert(data.schemaVersion==1 and data.lootFilterModule,"Use an AI Edition rule module")
	return M.validateModules({data.lootFilterModule})[1]
end
function M.review(before,after)
	local entries={};local old={};for _,p in ipairs(before.profiles) do old[p.id]=p end
	for _,p in ipairs(after.profiles) do
		local previous=old[p.id];old[p.id]=nil
		if not previous then entries[#entries+1]={id=p.id,label="+ "..p.title,details={"New profile",#p.rules.." personal rules"}}
		elseif encode(previous)~=encode(p) then
			local lines={"Before: "..previous.title,"After: "..p.title,"Strictness: "..previous.strictness.." -> "..p.strictness,"Mode: "..previous.mode.." -> "..p.mode}
			if previous.template~=p.template then lines[#lines+1]="Base filter changed: "..(previous.template and "imported ("..#previous.template.." bytes)" or "pinned preset").." -> "..(p.template and "imported ("..#p.template.." bytes)" or "pinned preset") end
			if previous.baseCommit~=p.baseCommit then lines[#lines+1]="Base revision: "..tostring(previous.baseCommit).." -> "..tostring(p.baseCommit) end
			for _,key in ipairs({"rules","tiers","modules"}) do local a,b={},{};for _,v in ipairs(previous[key] or {}) do a[#a+1]=v.id end;for _,v in ipairs(p[key] or {}) do b[#b+1]=v.id end;if #a==#b and table.concat(a,"/")~=table.concat(b,"/") then lines[#lines+1]="Priority order changed: "..key end end
			for _,key in ipairs({"rules","tiers","modules"}) do
				local map={};for _,v in ipairs(previous[key] or {}) do map[v.id]=v end
				for _,v in ipairs(p[key] or {}) do local prior=map[v.id];map[v.id]=nil
					if not prior or encode(prior)~=encode(v) then
						lines[#lines+1]=(prior and "Changed " or "Added ")..key..": "..v.title
						if prior and prior.text then lines[#lines+1]="Before:\n"..prior.text end;if v.text then lines[#lines+1]="After:\n"..v.text end
						if key=="tiers" then lines[#lines+1]="Items before: "..table.concat(prior and prior.items or {},", ");lines[#lines+1]="Items after: "..table.concat(v.items,", ") end
						if key=="modules" then lines[#lines+1]="Module before: "..(prior and encode(prior) or "not installed");lines[#lines+1]="Module after: "..encode(v) end
					end
				end
				for _,v in pairsSortByKey(map) do lines[#lines+1]="Removed "..key..": "..v.title end
			end
			if encode(previous.appearance)~=encode(p.appearance) then lines[#lines+1]="Appearance before: "..json.encode(previous.appearance);lines[#lines+1]="Appearance after: "..json.encode(p.appearance) end
			entries[#entries+1]={id=p.id,label="Changed: "..p.title,details=lines}
		end
	end
	for id,p in pairsSortByKey(old) do entries[#entries+1]={id=id,label="- "..p.title,details={"Profile removed"}} end
	return entries
end
return M
