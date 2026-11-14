-- Presentation queries over the pinned graph; no character or map-odds simulation.
local atlas=require("Modules.AtlasPlanner")
local M={mechanics={"Maps","Essence","Harvest","Expedition","Breach","Legion","Blight","Delirium","Ritual","Beyond","Abyss","Strongboxes","Shrines","Heist","Delve","Bestiary","Incursion","Betrayal","Ultimatum","Bosses","Mirage","Wildwood","Sentinels","Torment","Rogue Exiles","Threads"}}
local aliases={Maps={"map","kirac"},Bosses={"boss","shaper","elder","maven","eater","exarch"},Strongboxes={"strongbox"},Shrines={"shrine"},Bestiary={"beast","einhar"},Incursion={"incursion","alva"},Betrayal={"syndicate","jun"},Delve={"sulphite","niko"},Harvest={"harvest","sacred flora","sacred fauna","sacred specimen","lifeforce"},Wildwood={"viridian wildwood","wildwood chance"},Sentinels={"sentinel"},Torment={"tormented spirit","tormented procurator"},["Rogue Exiles"]={"rogue exile"},Threads={"thread"}}
local function matches(text,name)
	for _,word in ipairs(aliases[name] or {name:lower()}) do if text:find(word,1,true) then return true end end
	return false
end
function M.mechanic(node)
	local text=(node.name.." "..table.concat(node.stats," ")):lower()
	-- Generic map text is common to every mechanic: classify it last.
	for i=2,#M.mechanics do local name=M.mechanics[i];if matches(text,name) then return name end end
	if matches(text,"Maps") then return "Maps" end
	return "Other"
end
function M.hasMechanic(node,name)
	-- Keep generic map bonuses separate from mechanic-specific nodes.
	if name=="Maps" then return M.mechanic(node)=="Maps" end
	return matches((node.name.." "..table.concat(node.stats," ")):lower(),name)
end
function M.costs(plan,avoid)
	local tree=atlas.tree(plan.version);local blocked={};for _,id in ipairs(atlas.exclusions(plan,avoid)) do blocked[id]=true end
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
	for id,node in pairs(tree.nodes) do if id~=tree.start and (mechanic==nil or mechanic=="All" or M.hasMechanic(node,mechanic)) and (node.name.." "..table.concat(node.stats," ")):lower():find(query,1,true) then
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
		-- Additions are returned from target back towards the existing tree.
		-- The last addition is a valid intermediate node too, including for a
		-- two-node route; only the target itself must remain unblocked.
		for i=2,math.min(#first,9) do local blocked=copyTable(avoid or {});blocked[#blocked+1]=first[i];add("Alternative connection",{target},blocked);if #routes>=4 then break end end
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
			-- Try the whole target set before dropping a notable for the budget.
			local ok,optimized,_,routing=pcall(atlas.connectOptimized,plan,targets)
			if ok then nextPlan=optimized;kept=targets else
				ok,optimized,_,routing=pcall(atlas.connectOptimized,plan,kept);if ok then nextPlan=optimized end
			end
			if #kept>0 then result[#result+1]={label=mechanic.." starting route",plan=nextPlan,targets=kept,mechanic=mechanic,routing=ok and routing or nil} end
		end
	end
	return result
end
function M.transition(before,after)
	local diff=M.compare(before,after);local tree=atlas.tree(after.version);local goal={};for _,id in ipairs(after.nodes) do goal[id]=true end
	local budget=math.max(before.budget,after.budget)
	local function freePoints(state)
		local granted=tree.nodes[tree.start].grantedPoints or 0
		for _,id in ipairs(state.nodes) do granted=granted+(tree.nodes[id].grantedPoints or 0) end
		return state.budget+granted-#state.nodes
	end
	local function route(rebuild,initial)
		local state=copyTable(initial or before);state.budget=budget
		-- Saved routing preferences can change between stages. They do not
		-- prevent allocating or refunding the nodes in a respec sequence.
		state.desired=nil;state.avoided=nil
		local steps={};local clearing=rebuild
		for _=1,#state.nodes+#after.nodes+1 do
			if table.concat(state.nodes,",")==table.concat(after.nodes,",") then return steps end
			if #state.nodes==0 then clearing=false end
			local nextState,step
			for index,id in ipairs(state.nodes) do if clearing or not goal[id] then
				local candidate=copyTable(state);table.remove(candidate.nodes,index)
				local ok,validated=pcall(atlas.validate,candidate)
				if ok then nextState=validated;step={action="Refund",id=id};break end
			end end
			if not nextState and not clearing and freePoints(state)>0 then
				local allocated={[tree.start]=true};for _,id in ipairs(state.nodes) do allocated[id]=true end
				for _,id in ipairs(after.nodes) do if not allocated[id] then
					local adjacent=false;for _,other in ipairs(tree.nodes[id].links) do if allocated[other] then adjacent=true;break end end
					if adjacent then local candidate=copyTable(state);candidate.nodes[#candidate.nodes+1]=id;local ok,validated=pcall(atlas.validate,candidate);if ok then nextState=validated;step={action="Allocate",id=id};break end end
				end end
			end
			if not nextState then return end
			steps[#steps+1]=step;state=nextState
		end
	end
	local steps=route(false);local rebuilt=false;if not steps then steps=route(true);rebuilt=steps~=nil end
	local temporary=false
	if not steps then
		local allocated={[tree.start]=true};for _,id in ipairs(before.nodes) do allocated[id]=true end
		local grants={};for _,id in ipairs(after.nodes) do if not allocated[id] and (tree.nodes[id].grantedPoints or 0)>0 then grants[#grants+1]=id end end
		if #grants==1 then
			local avoid={};for _,id in ipairs(after.avoided or {}) do if not allocated[id] then avoid[#avoid+1]=id end end
			local start=copyTable(before);start.budget=budget;start.desired=nil;start.avoided=nil
			local ok,via,added=pcall(atlas.connect,start,{grants[1]},avoid)
			if ok then
				local prefix={};local state=copyTable(start)
				for i=#added,1,-1 do if freePoints(state)<1 then prefix=nil;break end;local candidate=copyTable(state);candidate.nodes[#candidate.nodes+1]=added[i];local valid,nextState=pcall(atlas.validate,candidate);if not valid then prefix=nil;break end;state=nextState;prefix[#prefix+1]={action="Allocate",id=added[i]} end
				if prefix then local suffix=route(false,via);if suffix then steps=prefix;for _,step in ipairs(suffix) do steps[#steps+1]=step end;temporary=true end end
			end
		end
	end
	local result={added=diff.added,removed=diff.removed,stats=diff.stats,steps=steps,rebuild=rebuilt,temporary=temporary,lines={before.title.." -> "..after.title,#diff.removed.." changed nodes to refund; "..#diff.added.." changed nodes to allocate.","Route assumes "..budget.." base points are available. Each step preserves connectivity and the supplied budget plus granted points. Refund currency prices are not assumed."}}
	if steps then
		local refunds=0;for _,step in ipairs(steps) do if step.action=="Refund" then refunds=refunds+1 end end
		result.lines[#result.lines+1]=(temporary and "Temporary grant path; includes extra refunds. " or rebuilt and "Rebuild route; may require extra refunds. " or "Direct route. ")..refunds.." refunds, "..(#steps-refunds).." allocations. This is a valid route, not a minimum-refund optimizer."
		for i,step in ipairs(steps) do result.lines[#result.lines+1]=i..". "..step.action..": "..tree.nodes[step.id].name.." ["..step.id.."]" end
	else result.lines[#result.lines+1]="No sequential route found within this budget. Earn more points or plan a temporary route before applying these allocations." end
	return result
end
return M
