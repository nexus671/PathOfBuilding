-- Build-owned progression, acquisition and actual spending. Never assumes live prices.
-- cspell:ignore jsontype
local json=require("dkjson")
local M={limit=2*1024*1024}
local collections={"milestones","wishlist","resources","ledger","stages"}
local function text(v,n,label,optional)
	if v==nil and optional then return nil end
	assert(type(v)=="string" and #v<=n and (optional or v:match("%S")),"Invalid "..label);return v
end
local function num(v,lo,hi,label)
	assert(type(v)=="number" and v==v and v>=lo and v<=hi,"Invalid "..label);return v
end
local function id(v) v=text(v,64,"ID");assert(v:match("^[%w_-]+$"),"Invalid ID");return v end
local function array(v)
	assert(type(v)=="table" and v~=json.null,"Expected an array")
	assert(not getmetatable(v) or getmetatable(v).__jsontype~="object","Expected an array")
	for k in pairs(v) do assert(type(k)=="number" and k==math.floor(k) and k>=1 and k<=#v,"Expected a dense array") end
	return v
end
local function choice(v,values)
	for _,valid in ipairs(values) do if v==valid then return v end end;error("Invalid choice")
end
function M.empty() return {schemaVersion=1,milestones={},wishlist={},resources={},ledger={},stages={}} end
function M.dependents(data,id)
	local children={}
	for _,entry in ipairs(data.milestones) do for _,dep in ipairs(entry.dependencies or {}) do children[dep]=children[dep] or {};children[dep][#children[dep]+1]=entry.id end end
	local seen,queue={[id or ""]=true},{id or ""};local cursor=1
	while cursor<=#queue do local parent=queue[cursor];cursor=cursor+1
		for _,child in ipairs(children[parent] or {}) do if not seen[child] then seen[child]=true;queue[#queue+1]=child end end
	end
	return seen
end
function M.validate(input,build)
	assert(type(input)=="table" and input.schemaVersion==1,"Unsupported journey data")
	local out=M.empty();local ids={}
	for _,key in ipairs(collections) do
		ids[key]={}
		for _,entry in ipairs(array(input[key]==nil and {} or input[key])) do
			assert(type(entry)=="table","Invalid journey entry")
			local e={id=id(entry.id)};assert(not ids[key][e.id],"Duplicate "..key.." ID");ids[key][e.id]=e
			if key=="ledger" then
				e.resourceId=id(entry.resourceId);e.kind=choice(entry.kind,{"add","spend"});e.amount=num(entry.amount,0.000001,1e12,"quantity")
				e.at=num(entry.at,0,4102444800,"record time");e.note=text(entry.note,1000,"record note",true)
			else
				e.title=text(entry.title,120,"title");e.notes=text(entry.notes,8000,"notes",true)
			end
			for _,link in ipairs({"projectId","atlasId","stageId","wishlistId"}) do if entry[link] then e[link]=id(entry[link]) end end
			if key=="resources" then e.unit=text(entry.unit,40,"unit",true)
			elseif key=="milestones" then
				e.kind=choice(entry.kind or "task",{"task","passives","gems","gear","craft","atlas","quest","ascendancy"})
				e.priority=num(entry.priority or 3,1,5,"priority");e.done=entry.done==true;e.dependencies={}
				local seen={};for _,dep in ipairs(array(entry.dependencies or {})) do dep=id(dep);assert(not seen[dep],"Duplicate prerequisite");seen[dep]=true;e.dependencies[#e.dependencies+1]=dep end
			elseif key=="wishlist" then
				e.slot=text(entry.slot,80,"slot");e.route=choice(entry.route,{"buy","craft","farm","owned"})
				if build then assert(build.itemsTab.slots[e.slot],"Unknown wishlist equipment slot") end
				e.stage=choice(entry.stage or "next",{"next","final","alternative"});e.status=choice(entry.status or "planned",{"planned","owned","skipped"})
				e.priority=num(entry.priority or 3,1,5,"priority");e.reserve=entry.reserve==true
				e.targetItem=text(entry.targetItem,24000,"target item",true)
				if build and e.targetItem and e.targetItem~="" then local item=require("Modules.CraftingProjects").item(e.targetItem);assert(build.itemsTab:IsItemValidForSlot(item,e.slot),"Target item cannot use this slot") end
				if entry.resourceId then e.resourceId=id(entry.resourceId);e.estimate=num(entry.estimate,0,1e12,"estimate") end
			elseif key=="stages" then
				for _,field in ipairs({"gems","passives","gear","ascendancy","quests","transition"}) do e[field]=text(entry[field],12000,field,true) end
			end
			if entry.level then e.level=num(entry.level,1,100,"level");assert(e.level==math.floor(e.level),"Level must be an integer") end
			if e.priority then assert(e.priority==math.floor(e.priority),"Priority must be an integer") end
			if key=="stages" then assert(e.level,"Guide stages need a level") end
			out[key][#out[key]+1]=e
		end
	end
	-- Validate the entire dependency graph iteratively, including disconnected cycles.
	local degree,children,queue={},{},{}
	for _,e in ipairs(out.milestones) do
		degree[e.id]=#e.dependencies
		for _,dep in ipairs(e.dependencies) do
			local parent=assert(ids.milestones[dep],"Unknown prerequisite: "..dep)
			assert(not e.done or parent.done,"Complete prerequisites first")
			children[dep]=children[dep] or {};children[dep][#children[dep]+1]=e.id
		end
		if degree[e.id]==0 then queue[#queue+1]=e.id end
	end
	local cursor=1;while cursor<=#queue do local key=queue[cursor];cursor=cursor+1
		for _,child in ipairs(children[key] or {}) do degree[child]=degree[child]-1;if degree[child]==0 then queue[#queue+1]=child end end
	end
	assert(#queue==#out.milestones,"Prerequisites contain a cycle")
	local balances={}
	for _,e in ipairs(out.ledger) do
		assert(ids.resources[e.resourceId],"Unknown ledger resource")
		local balance=(balances[e.resourceId] or 0)+(e.kind=="add" and e.amount or -e.amount)
		assert(balance>=-1e-8,"Spending exceeds recorded holdings");balances[e.resourceId]=balance
	end
	for _,e in ipairs(out.wishlist) do if e.resourceId then assert(ids.resources[e.resourceId],"Unknown estimate resource") end end
	for _,e in ipairs(out.milestones) do
		if e.stageId then assert(ids.stages[e.stageId],"Unknown guide stage") end
		if e.wishlistId then assert(ids.wishlist[e.wishlistId],"Unknown gear goal") end
	end
	assert(#json.encode(out)<=M.limit,"Journey exceeds supported size")
	return out
end
function M.budget(data)
	local result={}
	for _,r in ipairs(data.resources) do result[r.id]={id=r.id,title=r.title,unit=r.unit or "",owned=0,spent=0,reserved=0} end
	for _,e in ipairs(data.ledger) do local r=result[e.resourceId];if e.kind=="add" then r.owned=r.owned+e.amount else r.owned=r.owned-e.amount;r.spent=r.spent+e.amount end end
	for _,e in ipairs(data.wishlist) do if e.reserve and e.status=="planned" and e.resourceId then local r=result[e.resourceId];r.reserved=r.reserved+e.estimate end end
	for _,r in pairs(result) do r.available=math.max(0,r.owned-r.reserved);r.gap=math.max(0,r.reserved-r.owned) end
	return result
end
function M.captureStage(candidate,title,key,revision)
	local snapshot=require("Modules.BuildInsights").snapshot(candidate)
	local passives,gear={},{}
	for node,name in pairsSortByKey(snapshot.passives) do passives[#passives+1]=name.." (#"..node..")" end
	for slot,item in pairsSortByKey(snapshot.items) do gear[#gear+1]=slot..": "..item.name end
	return {id=key,title=title,level=snapshot.level,gems=table.concat(snapshot.skills,"\n"),passives=table.concat(passives,"\n"),gear=table.concat(gear,"\n"),ascendancy=snapshot.ascendancy,
		notes="Captured from a native calculated candidate at "..os.date("!%Y-%m-%d %H:%M UTC")..". Base revision "..revision..". Recalculate after changes; this guide does not apply the candidate."}
end
function M.next(data,build)
	local result,done,projects,atlas,titles={},{},{},{},{}
	for _,e in ipairs(data.milestones) do done[e.id]=e.done;titles[e.id]=e.title end
	for _,e in ipairs(build.savers.CraftingProjects.projects) do projects[e.id]=true end
	for _,e in ipairs(build.savers.AtlasPlans.plans) do atlas[e.id]=true end
	local budget=M.budget(data);local gear={};for _,e in ipairs(data.wishlist) do gear[e.id]=e end
	local function funding(e,reasons)
		if e.status=="owned" or e.status=="skipped" then return end
		if e.resourceId then local r=budget[e.resourceId];local available=r.owned-r.reserved+(e.reserve and e.estimate or 0)
			if e.estimate>available then reasons[#reasons+1]=string.format("Need %.2f more %s after reservations",e.estimate-available,r.title) end
		else reasons[#reasons+1]="Cost not recorded; affordability unknown" end
		if e.projectId and not projects[e.projectId] then reasons[#reasons+1]="Linked craft is missing" end
	end
	for _,e in ipairs(data.milestones) do if not e.done then
		local reasons={};for _,dep in ipairs(e.dependencies) do if not done[dep] then reasons[#reasons+1]="Finish prerequisite: "..(titles[dep] or dep) end end
		if e.level and e.level>(build.characterLevel or 1) then reasons[#reasons+1]="Requires level "..e.level end
		if e.projectId and not projects[e.projectId] then reasons[#reasons+1]="Linked craft is missing" end
		if e.atlasId and not atlas[e.atlasId] then reasons[#reasons+1]="Linked Atlas plan is missing" end
		if e.wishlistId then funding(gear[e.wishlistId],reasons) end
		result[#result+1]={id=e.id,title=e.title,kind="milestone",priority=e.priority,blocked=#reasons>0,reasons=reasons,entry=e}
	end end
	for _,e in ipairs(data.wishlist) do if e.status=="planned" then local reasons={};funding(e,reasons)
		result[#result+1]={id=e.id,title=e.title,kind="gear",priority=e.priority,blocked=#reasons>0,reasons=reasons,entry=e}
	end end
	local linked={};for _,e in ipairs(data.milestones) do if e.projectId then linked[e.projectId]=true end end
	for _,e in ipairs(data.wishlist) do if e.projectId then linked[e.projectId]=true end end
	for _,e in ipairs(build.savers.CraftingProjects.projects) do if not linked[e.id] then
		local pending=#e.steps==0;for _,step in ipairs(e.steps) do if not step.done then pending=true end end
		if pending then result[#result+1]={id=e.id,title="Continue craft: "..e.title,kind="craft",priority=4,blocked=true,reasons={"Link a gear goal to record affordability; no budget is assumed."},entry={projectId=e.id,notes=e.run and "A working item checkpoint is saved." or "No working checkpoint yet."}} end
	end end
	table.sort(result,function(a,b) if a.blocked~=b.blocked then return not a.blocked end;if a.priority~=b.priority then return a.priority<b.priority end;return a.kind..a.id<b.kind..b.id end)
	return result
end
function M.new(build)
	local self={build=build,data=M.empty()}
	function self:Load(xml)
		local raw=table.concat(xml);if raw:match("^%s*$") then return end
		local ok,data=pcall(function() assert(#raw<=M.limit,"Journey too large");return M.validate(assert(json.decode(raw,1,json.null)),build) end)
		if ok then self.data=data else self.unreadable=raw;self.warning="Journey data could not be read. It will be preserved unchanged." end
	end
	function self:Save(xml) xml[#xml+1]=self.unreadable or json.encode(self.data) end
	function self:Replace(data) assert(not self.unreadable,self.warning);self.data=M.validate(data,build);build.modFlag=true;return self.data end
	function self:Put(key,entry)
		assert(type(self.data[key])=="table","Unknown collection")
		local data=copyTable(self.data);local found=false
		for i,e in ipairs(data[key]) do if e.id==entry.id then data[key][i]=entry;found=true;break end end
		if not found then data[key][#data[key]+1]=entry end;return self:Replace(data)
	end
	function self:Complete(key)
		local data=copyTable(self.data);local found
		for _,e in ipairs(data.milestones) do if e.id==key then e.done=not e.done;found=e;break end end
		assert(found,"Unknown milestone")
		if not found.done then
			local unfinished=M.dependents(data,key)
			for _,entry in ipairs(data.milestones) do if unfinished[entry.id] then entry.done=false end end
		end
		return self:Replace(data)
	end
	return self
end
return M
