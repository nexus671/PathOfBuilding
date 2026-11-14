-- Minimum added-node Steiner route for at most four targets. Existing connected
-- allocations have zero cost, and avoided nodes are excluded from the graph.
local bit=require("bit")
local M={}

function M.find(tree,allocated,blocked,targets,checkpoint)
	local unique,seen={},{}
	for _,id in ipairs(targets) do if not allocated[id] and not seen[id] then unique[#unique+1]=id;seen[id]=true end end
	if #unique>4 then return nil end
	if #unique==0 then return {} end
	local nodes={};for id in pairs(tree.nodes) do if not blocked[id] then nodes[#nodes+1]=id end end;table.sort(nodes)
	local distance,trace={},{};local full=2^#unique-1;local operations=0
	local function tick(mask)
		operations=operations+1
		if checkpoint and operations%128==0 then checkpoint({phase="exact",target=mask,targets=full}) end
	end
	local function cost(id) return allocated[id] and 0 or 1 end
	for mask=1,full do
		local d,t={},{};distance[mask]=d;trace[mask]=t
		for index,id in ipairs(unique) do if mask==2^(index-1) then d[id]=cost(id);t[id]={leaf=true} end end
		local part=bit.band(mask-1,mask)
		while part>0 do
			local other=mask-part
			if part<other then
				for _,id in ipairs(nodes) do
					local left,right=distance[part][id],distance[other][id]
					if left and right then local value=left+right-cost(id);if not d[id] or value<d[id] then d[id]=value;t[id]={split=part,other=other} end end
					tick(mask)
				end
			end
			part=bit.band(part-1,mask)
		end
		-- Multi-source Dijkstra makes the merged partial routes available at
		-- every graph node, including zero-cost existing allocations.
		local heap={}
		local function less(a,b) return a.value<b.value or a.value==b.value and a.id<b.id end
		local function push(id,value)
			local item={id=id,value=value};local i=#heap+1
			while i>1 do local parent=math.floor(i/2);if not less(item,heap[parent]) then break end;heap[i]=heap[parent];i=parent end;heap[i]=item
		end
		local function pop()
			local first=heap[1];local last=table.remove(heap);if #heap==0 then return first end
			local i=1;while i*2<=#heap do local child=i*2;if child<#heap and less(heap[child+1],heap[child]) then child=child+1 end;if not less(heap[child],last) then break end;heap[i]=heap[child];i=child end;heap[i]=last;return first
		end
		for _,id in ipairs(nodes) do if d[id] then push(id,d[id]) end end
		while #heap>0 do
			local entry=pop();local id=entry.id
			if entry.value==d[id] then for _,nextId in ipairs(tree.nodes[id].links) do if not blocked[nextId] then
				local value=entry.value+cost(nextId)
				if not d[nextId] or value<d[nextId] then d[nextId]=value;t[nextId]={previous=id};push(nextId,value) end
			end end end
			tick(mask)
		end
	end
	local root,best
	for _,id in ipairs(nodes) do if allocated[id] and distance[full][id] and (not best or distance[full][id]<best) then root=id;best=distance[full][id] end end
	if not root then return nil end
	local result,visited={},{}
	local function collect(mask,id)
		local key=mask..":"..id;if visited[key] then return end;visited[key]=true
		if not allocated[id] then result[id]=true end
		local entry=assert(trace[mask][id],"Missing exact Atlas route trace")
		if entry.previous then collect(mask,entry.previous) elseif entry.split then collect(entry.split,id);collect(entry.other,id) end
	end
	collect(full,root);return result
end
return M
