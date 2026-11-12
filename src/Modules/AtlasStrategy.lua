-- Presentation queries over the pinned graph; no character or map-odds simulation.
local atlas=require("Modules.AtlasPlanner")
local M={mechanics={"Maps","Essence","Harvest","Expedition","Breach","Legion","Blight","Delirium","Ritual","Beyond","Abyss","Strongboxes","Shrines","Heist","Delve","Bestiary","Incursion","Betrayal","Ultimatum","Bosses"}}
local aliases={Maps={"map","kirac"},Bosses={"boss","shaper","elder","maven","eater","exarch"},Strongboxes={"strongbox"},Shrines={"shrine"},Bestiary={"beast","einhar"},Incursion={"incursion","alva"},Betrayal={"syndicate","jun"},Delve={"sulphite","niko"}}
function M.mechanic(node)
	local text=(node.name.." "..table.concat(node.stats," ")):lower()
	-- Generic map text is common to every mechanic: classify it last.
	for i=2,#M.mechanics do local name=M.mechanics[i];for _,word in ipairs(aliases[name] or {name:lower()}) do if text:find(word,1,true) then return name end end end
	for _,word in ipairs(aliases.Maps) do if text:find(word,1,true) then return "Maps" end end
	return "Other"
end
function M.costs(plan,avoid)
	local tree=atlas.tree(plan.version);local blocked={};for _,id in ipairs(avoid or {}) do blocked[id]=true end
	local costs={[tree.start]=0};local queue={tree.start}
	for _,id in ipairs(plan.nodes) do costs[id]=0;queue[#queue+1]=id end
	local index=1
	while index<=#queue do
		local id=queue[index];index=index+1
		for _,nextId in ipairs(tree.nodes[id].links) do if costs[nextId]==nil and not blocked[nextId] then costs[nextId]=costs[id]+1;queue[#queue+1]=nextId end end
	end
	return costs
end
function M.results(plan,query,mechanic,avoid)
	local costs=M.costs(plan,avoid);local tree=atlas.tree(plan.version);local entries={}
	query=(query or ""):lower()
	for id,node in pairs(tree.nodes) do if id~=tree.start and (mechanic==nil or mechanic=="All" or M.mechanic(node)==mechanic) and (node.name.." "..table.concat(node.stats," ")):lower():find(query,1,true) then
		entries[#entries+1]={id=id,node=node,cost=costs[id]}
	end end
	table.sort(entries,function(a,b) if a.cost~=b.cost then return (a.cost or math.huge)<(b.cost or math.huge) elseif a.node.name~=b.node.name then return a.node.name<b.node.name else return a.id<b.id end end)
	return entries
end
function M.compare(before,after)
	assert(before.version==after.version,"Choose plans from the same Atlas version to compare")
	local old,new={},{};for _,id in ipairs(before.nodes) do old[id]=true end;for _,id in ipairs(after.nodes) do new[id]=true end
	local result={added={},removed={},stats={}};local tree=atlas.tree(after.version)
	for id in pairs(new) do if not old[id] then result.added[#result.added+1]=tree.nodes[id] end end
	for id in pairs(old) do if not new[id] then result.removed[#result.removed+1]=tree.nodes[id] end end
	for _,list in ipairs({result.added,result.removed}) do table.sort(list,function(a,b) return a.id<b.id end) end
	local counts={}
	for _,entry in ipairs(atlas.report(before).stats) do counts[entry.text]=-entry.count end
	for _,entry in ipairs(atlas.report(after).stats) do counts[entry.text]=(counts[entry.text] or 0)+entry.count end
	for text,count in pairs(counts) do if count~=0 then result.stats[#result.stats+1]=string.format("%+dx %s",count,text) end end
	table.sort(result.stats)
	return result
end
function M.routes(plan,target,avoid,preferred)
	local routes={};local seen={}
	local function add(label,targets,blocked)
		local ok,nextPlan,added=pcall(atlas.connect,plan,targets,blocked)
		if ok then local signature=table.concat(nextPlan.nodes,",");if not seen[signature] then seen[signature]=true;routes[#routes+1]={label=label,plan=nextPlan,added=added,cost=#added} end end
	end
	add("Shortest connection",{target},avoid)
	if preferred and preferred~=target then add("Via preferred node",{preferred,target},avoid) end
	if routes[1] then
		local first=routes[1].added
		for i=2,math.min(#first-1,8) do local blocked=copyTable(avoid or {});blocked[#blocked+1]=first[i];add("Alternative connection",{target},blocked);if #routes>=4 then break end end
	end
	table.sort(routes,function(a,b) if a.cost~=b.cost then return a.cost<b.cost else return a.label<b.label end end)
	return routes
end
function M.presets(plan)
	local result={}
	for _,mechanic in ipairs(M.mechanics) do
		local targets={};local matches=M.results(plan,"",mechanic)
		for _,entry in ipairs(matches) do if entry.node.kind=="notable" then targets[#targets+1]=entry.id;if #targets==3 then break end end end
		if #targets>0 then
			local nextPlan=copyTable(plan);local kept={}
			for _,target in ipairs(targets) do local ok,value=pcall(atlas.connect,nextPlan,{target});if ok then nextPlan=value;kept[#kept+1]=target end end
			if #kept>0 then result[#result+1]={label=mechanic.." starting route",plan=nextPlan,targets=kept,mechanic=mechanic} end
		end
	end
	return result
end
return M
