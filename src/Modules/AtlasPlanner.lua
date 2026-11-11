-- Native Atlas plans use pinned GGG data, independently of character passives.
local json = require("dkjson")
local M = {versions={"3.27.0","3.29.1"},cache={}}
local function integer(value,low,high,label)
	assert(type(value) == "number" and value == math.floor(value) and value >= low and value <= high,"Invalid "..label)
	return value
end
local function text(value,limit,label)
	assert(type(value) == "string" and #value <= limit,"Invalid "..label)
	return value
end
local function array(value,limit,label)
	assert(type(value) == "table" and value ~= json.null and #value <= limit,"Invalid "..label)
	local meta=getmetatable(value)
	assert(not meta or meta.__jsontype ~= "object","Expected an array for "..label)
	for key in pairs(value) do assert(type(key) == "number" and key == math.floor(key) and key >= 1 and key <= #value,"Invalid array for "..label) end
	return value
end
function M.tree(version)
	assert(version == "3.27.0" or version == "3.29.1","Unsupported Atlas version; choose a bundled Standard tree")
	if not M.cache[version] then
		local root=GetScriptPath()
		local file=assert(io.open((root ~= "" and root.."/" or "").."Data/Atlas/"..version..".json","rb"))
		local raw=file:read("*a"); file:close()
		local tree=assert(json.decode(raw))
		local nodes={}
		for id,node in pairs(tree.nodes) do nodes[tonumber(id)]=node end
		tree.nodes=nodes; M.cache[version]=tree
	end
	return M.cache[version]
end
local function nodeSet(tree,ids)
	array(ids,300,"Atlas node IDs")
	local set={}
	for _,id in ipairs(ids) do
		integer(id,1,65535,"Atlas node ID")
		assert(tree.nodes[id],"Unknown or decorative Atlas node: "..id)
		assert(not set[id],"Duplicate Atlas node: "..id); set[id]=true
	end
	return set
end
local function sorted(set)
	local result={}; for id in pairs(set) do result[#result+1]=id end; table.sort(result); return result
end
local function reachable(tree,set)
	local visited,queue={[tree.start]=true},{tree.start}
	local index=1
	while index <= #queue do
		for _,id in ipairs(tree.nodes[queue[index]].links) do
			if set[id] and not visited[id] then visited[id]=true; queue[#queue+1]=id end
		end
		index=index+1
	end
	return visited
end
function M.validate(plan)
	assert(type(plan) == "table","Invalid Atlas plan")
	local tree=M.tree(plan.version)
	local result={id=text(plan.id,64,"Atlas plan ID"),title=text(plan.title,120,"Atlas title"),version=plan.version,
		budget=integer(plan.budget,0,tree.maxPoints,"Atlas point budget"),notes=text(plan.notes or "",8000,"Atlas notes"),nodes={}}
	assert(result.id:match("^[%w_-]+$") and result.title:match("%S"),"Use an Atlas plan ID and title")
	local set=nodeSet(tree,plan.nodes); set[tree.start]=true
	local connected=reachable(tree,set)
	local used,bonus=0,0
	for id in pairs(set) do
		assert(connected[id],"Atlas plan has disconnected nodes")
		if id ~= tree.start then used=used+1; result.nodes[#result.nodes+1]=id end
		bonus=bonus+(tree.nodes[id].grantedPoints or 0)
	end
	assert(used <= result.budget+bonus,"Atlas plan exceeds point budget")
	table.sort(result.nodes)
	return result
end
function M.search(version,query,limit)
	local tree=M.tree(version)
	query=text(query or "",160,"Atlas search"):lower(); limit=integer(limit or 30,1,100,"search limit")
	local all={}
	for _,id in ipairs(sorted(tree.nodes)) do
		local node=tree.nodes[id]
		if id ~= tree.start and (node.name.." "..table.concat(node.stats," ")):lower():find(query,1,true) then all[#all+1]=node end
	end
	local matches={}; for i=1,math.min(limit,#all) do matches[i]=copyTable(all[i]) end
	return {version=version,total=#all,matches=matches,source=tree.source}
end
-- Greedy shortest connections, deterministic in caller target order. Not a global optimizer.
function M.connect(plan,targets,avoid)
	plan=M.validate(plan)
	local tree=M.tree(plan.version)
	local set=nodeSet(tree,plan.nodes); set[tree.start]=true
	local blocked=nodeSet(tree,avoid or {})
	for id in pairs(blocked) do assert(not set[id],"Cannot avoid an allocated Atlas node") end
	array(targets,30,"Atlas targets")
	local additions={}
	for _,target in ipairs(targets) do
		integer(target,1,65535,"Atlas target")
		assert(tree.nodes[target] and not blocked[target],"Unknown or avoided Atlas target")
		local previous,queue={},sorted(set)
		for _,id in ipairs(queue) do previous[id]=false end
		local index=1
		while previous[target] == nil and index <= #queue do
			local current=queue[index]; index=index+1
			for _,id in ipairs(tree.nodes[current].links) do
				if previous[id] == nil and not blocked[id] then previous[id]=current; queue[#queue+1]=id end
			end
		end
		assert(previous[target] ~= nil,"Atlas target cannot be reached with these avoided nodes")
		local cursor=target
		while not set[cursor] do set[cursor]=true; additions[#additions+1]=cursor; cursor=previous[cursor] end
	end
	set[tree.start]=nil; plan.nodes=sorted(set)
	return M.validate(plan),additions
end
function M.remove(plan,id)
	plan=M.validate(plan); local tree=M.tree(plan.version)
	assert(id ~= tree.start and tree.nodes[id],"Cannot remove the Atlas start")
	local set=nodeSet(tree,plan.nodes); set[id]=nil
	local keep=reachable(tree,set); keep[tree.start]=nil; plan.nodes=sorted(keep)
	return M.validate(plan)
end
function M.report(plan)
	plan=M.validate(plan); local tree=M.tree(plan.version)
	local counts,notables,keystones,stats,bonus={small=0,notable=0,keystone=0,gateway=0},{},{},{},0
	for _,id in ipairs(plan.nodes) do
		local node=tree.nodes[id]; counts[node.kind]=counts[node.kind]+1
		if node.kind == "notable" then notables[#notables+1]=node.name end
		if node.kind == "keystone" then keystones[#keystones+1]=node.name end
		bonus=bonus+node.grantedPoints
		for _,stat in ipairs(node.stats) do stats[stat]=(stats[stat] or 0)+1 end
	end
	local lines={}
	for stat,count in pairs(stats) do lines[#lines+1]={text=stat,count=count} end
	table.sort(lines,function(a,b) return a.text < b.text end); table.sort(notables); table.sort(keystones)
	return {version=plan.version,mode="Standard",used=#plan.nodes,budget=plan.budget,bonus=bonus,remaining=plan.budget+bonus-#plan.nodes,
		counts=counts,notables=notables,keystones=keystones,stats=lines,source=tree.source,sourceCommit=tree.commit,
		limitations={"Atlas plans do not modify character DPS or EHP.","Stat lines are grouped verbatim, not combined into effective map odds. Keystone interactions are not simulated.","Budget is supplied progression, not imported account completion. Routing is greedy shortest connection, not a global optimum."}}
end
function M.export(plan)
	return json.encode({schemaVersion=1,atlasPlan=M.validate(plan)})
end
function M.import(raw,version,id,title,budget)
	text(raw,64000,"Atlas import")
	raw=raw:match("^%s*(.-)%s*$")
	if raw:match("^%s*{") then
		local decoded=assert(json.decode(raw),"Invalid Atlas JSON")
		assert(decoded.schemaVersion == 1,"Unsupported Atlas export version")
		local plan=M.validate(decoded.atlasPlan); plan.id=id or plan.id; plan.title=title or plan.title
		return M.validate(plan)
	end
	local token=raw:match("^https://www%.pathofexile%.com/fullscreen%-atlas%-skill%-tree/([%w_%-=]+)$")
	assert(token,"Paste our plan JSON or a full official Atlas URL without query parameters")
	local bytes=common.base64.decode(token:gsub("-","+"):gsub("_","/"))
	assert(bytes and #bytes >= 9 and bytes:sub(1,5) == string.char(0,0,0,6,0),"Unsupported Atlas URL format or game mode")
	local count=bytes:byte(6)*256+bytes:byte(7)
	assert(count <= 300 and #bytes == 9+count*2 and bytes:sub(-2) == string.char(0,0),"Unsupported or truncated Atlas URL")
	local ids={}; for i=1,count do ids[i]=bytes:byte(6+i*2)*256+bytes:byte(7+i*2) end
	return M.validate({id=id or "atlas-import",title=title or "Imported Atlas",version=version,budget=budget or M.tree(version).maxPoints,nodes=ids})
end
function M.url(plan)
	plan=M.validate(plan)
	local ids=copyTable(plan.nodes); ids[#ids+1]=M.tree(plan.version).start; table.sort(ids)
	local bytes={0,0,0,6,0,math.floor(#ids/256),#ids%256}
	for _,id in ipairs(ids) do bytes[#bytes+1]=math.floor(id/256); bytes[#bytes+1]=id%256 end
	bytes[#bytes+1]=0; bytes[#bytes+1]=0
	return "https://www.pathofexile.com/fullscreen-atlas-skill-tree/"..common.base64.encode(string.char(unpack(bytes))):gsub("+","-"):gsub("/","_")
end
function M.new(build)
	local self={plans={},build=build}
	function self:Load(xml)
		local ok,plans=pcall(function()
			local raw=table.concat(xml); assert(#raw <= 128000,"Atlas metadata too large")
			if not raw:match("%S") then return {} end
			local decoded=assert(json.decode(raw)); assert(decoded.schemaVersion == 1); array(decoded.plans,8,"saved Atlas plans")
			local result,ids={},{}
			for _,plan in ipairs(decoded.plans) do local entry=M.validate(plan); assert(not ids[entry.id]); ids[entry.id]=true; result[#result+1]=entry end
			return result
		end)
		if ok then self.plans=plans else self.unreadable=copyTable(xml); self.warning="Atlas metadata could not be read; it is preserved unchanged." end
	end
	function self:Save(xml)
		if self.unreadable then for _,entry in ipairs(self.unreadable) do xml[#xml+1]=type(entry) == "table" and copyTable(entry) or entry end
		elseif #self.plans > 0 then xml[#xml+1]=json.encode({schemaVersion=1,plans=self.plans}) end
	end
	function self:Upsert(plan)
		assert(not self.unreadable,self.warning)
		local entry=M.validate(plan); local replacement=copyTable(self.plans); local found
		for i,old in ipairs(replacement) do if old.id == entry.id then replacement[i]=entry; found=true; break end end
		if not found then assert(#replacement < 8,"Keep up to eight Atlas plans per build"); replacement[#replacement+1]=entry end
		assert(#json.encode(replacement) <= 128000,"Atlas metadata too large")
		self.plans=replacement; build.modFlag=true; return entry
	end
	function self:Remove(id)
		assert(not self.unreadable,self.warning)
		for i,plan in ipairs(self.plans) do if plan.id == id then table.remove(self.plans,i); build.modFlag=true; return end end
	end
	return self
end
return M
