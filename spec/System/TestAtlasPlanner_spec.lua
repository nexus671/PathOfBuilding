describe("Native Atlas planner", function()
	local atlas=require("Modules.AtlasPlanner")
	local bridge=require("Modules.DesktopBuildBridge")
	local function plan(version,budget)
		version=version or "3.27.0"
		return {id="mapping",title="Mapping strategy",version=version,budget=budget or atlas.tree(version).maxPoints,nodes={},notes="Map sustain first"}
	end
	before_each(function() newBuild(); bridge.prepared=nil end)
	after_each(function() bridge.prepared=nil; main.popups={} end)
	it("loads pinned Standard graphs with symmetric edges and free starts", function()
		for _,version in ipairs(atlas.versions) do
			local tree=atlas.tree(version)
			assert.are.equal(29045,tree.start)
			assert.are.equal(0,atlas.report(plan(version)).used)
			for id,node in pairs(tree.nodes) do for _,other in ipairs(node.links) do
				local found=false; for _,reverse in ipairs(tree.nodes[other].links) do if reverse == id then found=true end end
				assert.is_true(found)
			end end
		end
	end)
	it("searches literal names and stat text without allocating decorative labels", function()
		local matches=atlas.search("3.27.0","Essence",100)
		assert.is_true(matches.total > 1)
		assert.is_true(#matches.matches <= 100)
		assert.is_true(atlas.search("3.27.0","[",100).total >= 0)
		assert.are.equal(false,pcall(atlas.tree,"3.28.0"))
		assert.are.equal(false,pcall(atlas.validate,{id="x",title="x",version="3.27.0",budget=132,nodes={56946}}))
	end)
	it("connects a known path with a budget and no mutation of its input", function()
		local input=plan(); local tree=atlas.tree(input.version)
		local target=tree.nodes[tree.start].links[1]
		local result,added=atlas.connect(input,{target})
		assert.are.equal(1,#result.nodes); assert.are.equal(target,added[1])
		assert.are.equal(0,#input.nodes)
		assert.are.equal(false,pcall(atlas.connect,plan(nil,0),{target}))
		assert.are.equal(false,pcall(atlas.connect,input,{target},{target}))
	end)
	it("prunes nodes disconnected by branch removal and rejects duplicate or disconnected input", function()
		local tree=atlas.tree("3.27.0"); local target=atlas.search("3.27.0","Unwavering Vision",10).matches[1].id
		local result=atlas.connect(plan(),{target})
		assert.is_true(#result.nodes > 1)
		local startNeighbour
		for _,id in ipairs(result.nodes) do for _,other in ipairs(tree.nodes[tree.start].links) do if id == other then startNeighbour=id end end end
		assert.are.equal(0,#atlas.remove(result,startNeighbour).nodes)
		local invalid=plan(); invalid.nodes={target}; assert.are.equal(false,pcall(atlas.validate,invalid))
		invalid.nodes={tree.start,tree.start}; assert.are.equal(false,pcall(atlas.validate,invalid))
	end)
	it("accounts for granted points and keeps raw stat counts separate from effective odds", function()
		local target=atlas.search("3.27.0","Unwavering Vision",10).matches[1].id
		local result=atlas.connect(plan(),{target}); local report=atlas.report(result)
		assert.are.equal(20,report.bonus)
		assert.are.equal(result.budget+20-#result.nodes,report.remaining)
		assert.is_true(#report.stats > 0)
		assert.are.equal("Unwavering Vision",report.keystones[1])
		assert.is_truthy(report.limitations[2]:find("not combined",1,true))
	end)
	it("uses gateway graph links without allocating decorative mastery nodes", function()
		local tree=atlas.tree("3.29.1")
		local result=atlas.connect(plan("3.29.1"),{13842,17000})
		local nodes={}; for _,id in ipairs(result.nodes) do nodes[id]=true end
		assert.is_true(nodes[13842] and nodes[17000]); assert.are.equal(2,atlas.report(result).counts.gateway)
		local avoided=atlas.connect(plan("3.29.1"),{17000},{13842})
		for _,id in ipairs(avoided.nodes) do assert.are_not.equals(13842,id) end
		assert.is_true(#tree.nodes[13842].links > 0)
	end)
	it("round trips versioned JSON and strict official version-six links", function()
		local result=atlas.connect(plan(),{65225})
		local decoded=atlas.import(atlas.export(result))
		assert.is_true(tableDeepEquals(result,decoded))
		decoded=atlas.import(atlas.url(result),result.version,result.id,result.title,result.budget)
		assert.is_true(tableDeepEquals(result.nodes,decoded.nodes))
		assert.are.equal(false,pcall(atlas.import,"https://example.com/tree",result.version))
		assert.are.equal(false,pcall(atlas.import,atlas.url(result):sub(1,-7),result.version))
		assert.are.equal(#result.nodes,#atlas.import(" \n"..atlas.url(result).."\r\n",result.version).nodes)
		-- A known empty v6 Atlas payload: version, Standard mode, one start ID, two empty sections.
		local payload=string.char(0,0,0,6,0,0,1,113,117,0,0)
		local url="https://www.pathofexile.com/fullscreen-atlas-skill-tree/"..common.base64.encode(payload):gsub("+","-"):gsub("/","_")
		assert.are.equal(0,#atlas.import(url,"3.27.0").nodes)
	end)
	it("preserves unknown schemas and malformed XML metadata unchanged", function()
		local store=atlas.new(build); local raw='{"schemaVersion":99,"plans":[]}'
		store:Load({raw}); assert.is_truthy(store.warning)
		local xml={}; store:Save(xml); assert.are.equal(raw,xml[1])
		assert.are.equal(false,pcall(store.Upsert,store,plan()))
		store=atlas.new(build); store:Load({{elem="Unknown",attrib={},"opaque"}})
		xml={}; store:Save(xml); assert.are.equal("Unknown",xml[1].elem)
		store=atlas.new(build); raw='{"schemaVersion":1,"plans":[{"id":"x","title":"x","version":"3.27.0","budget":132,"nodes":{"unexpected":true}}]}'
		store:Load({raw}); assert.is_truthy(store.warning); xml={};store:Save(xml);assert.are.equal(raw,xml[1])
	end)
	it("persists native plans through candidate XML without changing character stats or live state", function()
		local entry=atlas.connect(plan(),{65225}); local revision=bridge.revision(build)
		local prepared=bridge.prepare(build,{mode="edit",title=entry.title,baseRevision=revision,operations={{type="set_atlas_plan",plan=entry}}})
		assert.are.equal(0,#build.savers.AtlasPlans.plans)
		assert.are.equal(1,#prepared.candidate.savers.AtlasPlans.plans)
		assert.are.equal(prepared.before.LifeUnreserved,prepared.after.LifeUnreserved)
		assert.are.equal(prepared.before.CombinedDPS,prepared.after.CombinedDPS)
		assert.are.equal(revision,bridge.revision(build))
		assert.is_truthy(table.concat(prepared.changes," "):find("Unwavering Vision",1,true))
		local store=build.savers.AtlasPlans
		for i=1,8 do local p=plan(); p.id="atlas-"..i; store:Upsert(p) end
		local p=plan();p.id="ninth";store:Upsert(p);store:Remove("atlas-1");assert.are.equal(8,#store.plans)
	end)
	it("exercises native canvas, search, allocation, undo and plan retention callbacks", function()
		local panel=require("Classes.AtlasPlannerControl")
		local controls=panel.Open(build,plan())
		controls.canvas:Draw()
		local mouseOver=controls.canvas.IsMouseOver
		controls.canvas.IsMouseOver=function() return true end
		local scale=controls.canvas.scale
		main.popups[1]:ProcessControlsInput({{type="KeyUp",key="WHEELUP"}},{x=-10000,y=-10000,width=20000,height=20000})
		controls.canvas.IsMouseOver=mouseOver
		assert.is_true(controls.canvas.scale > scale)
		controls.search:SetText("Unwavering Vision");controls.search.changeFunc();controls.find:Click()
		assert.are.equal(65225,controls.canvas.focus)
		controls.allocate:Click(); assert.is_true(controls.status.label:find("20 granted",1,true) ~= nil)
		controls.undo:Click(); assert.is_truthy(controls.status.label:find("0 /",1,true))
		controls.allocate:Click(); controls.keep:Click()
		assert.are.equal(1,#build.savers.AtlasPlans.plans)
		assert.is_true(#build.savers.AtlasPlans.plans[1].nodes > 0)
		panel.Library(build); main.popups[1].controls.open:Click()
		assert.is_truthy(main.popups[1].controls.canvas)
		controls=main.popups[1].controls
		local imported=plan("3.29.1"); imported.notes="Imported strategy notes"
		local environment=getfenv(panel.Open); local paste=environment.Paste
		environment.Paste=function() return atlas.export(imported) end
		controls.page:SelByValue("Notes & sharing");controls.import:Click(); environment.Paste=paste
		assert.are.equal(imported.notes,controls.notes.buf)
		assert.are.equal("3.29.1",controls.canvas.tree.version)
		controls.page:SelByValue("Tree");controls.undo:Click(); controls.canvas:Draw()
		assert.are.equal("3.27.0",controls.canvas.tree.version)
		assert.are.equal("Map sustain first",controls.notes.buf)
	end)
end)
