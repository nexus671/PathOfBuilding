describe("Exact small Atlas routes",function()
	local exact=require("Modules.AtlasExactRoute")
	local atlas=require("Modules.AtlasPlanner")
	local bit=require("bit")
	local function graph(edges)
		local t={nodes={}}
		for _,edge in ipairs(edges) do
			for _,id in ipairs(edge) do t.nodes[id]=t.nodes[id] or {id=id,links={}} end
			t.nodes[edge[1]].links[#t.nodes[edge[1]].links+1]=edge[2]
			t.nodes[edge[2]].links[#t.nodes[edge[2]].links+1]=edge[1]
		end
		return t
	end
	local function brute(tree,allocated,blocked,targets)
		local candidates={};for id in pairs(tree.nodes) do if not allocated[id] and not blocked[id] then candidates[#candidates+1]=id end end;table.sort(candidates)
		local best
		for mask=0,2^#candidates-1 do
			local chosen=copyTable(allocated);local count=0
			for i,id in ipairs(candidates) do if bit.band(mask,2^(i-1))~=0 then chosen[id]=true;count=count+1 end end
			if not best or count<best then
				local start=next(allocated);local reached={[start]=true};local queue={start};local i=1
				while i<=#queue do for _,id in ipairs(tree.nodes[queue[i]].links) do if chosen[id] and not reached[id] then reached[id]=true;queue[#queue+1]=id end end;i=i+1 end
				local valid=true;for _,id in ipairs(targets) do if not reached[id] then valid=false end end
				if valid then best=count end
			end
		end
		return best
	end
	local function assertConnected(tree,allocated,blocked,targets,added)
		if not added then return end
		local chosen=copyTable(allocated);for id in pairs(added) do assert.is_nil(blocked[id]);chosen[id]=true end
		local start=next(allocated);local reached={[start]=true};local queue={start};local i=1
		while i<=#queue do for _,id in ipairs(tree.nodes[queue[i]].links) do if chosen[id] and not reached[id] then reached[id]=true;queue[#queue+1]=id end end;i=i+1 end
		for _,id in ipairs(targets) do assert.is_true(reached[id]) end
		for id in pairs(chosen) do assert.is_true(reached[id]) end
	end
	it("matches exhaustive graph search with shared paths, allocations and exclusions",function()
		local tree=graph({{1,2},{2,3},{3,4},{1,5},{5,6},{6,4},{2,7},{7,8},{6,8},{3,9},{8,9}})
		for _,case in ipairs({{{[1]=true},{},{4,8,9}},{{[1]=true,[2]=true},{},{4,6,9}},{{[1]=true},{[3]=true},{4,8}},{{[1]=true},{[2]=true,[6]=true},{4,9}},{{[1]=true},{},{4,6,8,9}}}) do
			local actual=exact.find(tree,case[1],case[2],case[3]);local expected=brute(tree,case[1],case[2],case[3]);local count=0
			if actual then for _ in pairs(actual) do count=count+1 end end
			assert.equal(expected,actual and count or nil);assertConnected(tree,case[1],case[2],case[3],actual)
		end
	end)
	it("matches exhaustive search across many small graph shapes",function()
		for seed=1,48 do
			local edges={};for id=1,7 do edges[#edges+1]={id,id+1} end
			for a=1,8 do for b=a+2,8 do if (a*31+b*17+seed*13)%7<2 then edges[#edges+1]={a,b} end end end
			local tree=graph(edges);local blocked=seed%3==0 and {[4]=true} or {};local targets={6,7,8}
			local expected=brute(tree,{[1]=true},blocked,targets);local actual=exact.find(tree,{[1]=true},blocked,targets);local count=0
			if actual then for _ in pairs(actual) do count=count+1 end end
			assert.equal(expected,actual and count or nil);assertConnected(tree,{[1]=true},blocked,targets,actual)
		end
	end)
	it("finds the best valid shared route on the bundled tree",function()
		local p={id="exact",title="Exact",version="3.30.0-preview",budget=150,nodes={},notes=""}
		local ids={53175,34352,14203}
		local original,first=atlas.connect(p,ids);local route,added,info=atlas.connectOptimized(p,ids)
		assert.is_false(info.heuristic);assert.is_true(#added<=#first)
		local present={};for _,id in ipairs(route.nodes) do present[id]=true end;for _,id in ipairs(ids) do assert.is_true(present[id]) end
		assert.is_truthy(atlas.validate(original));assert.is_truthy(atlas.validate(route))
		local _,_,quick=atlas.connectOptimized(p,ids,nil,{exact=false});assert.is_true(quick.heuristic)
	end)
end)
