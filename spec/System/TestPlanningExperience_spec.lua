describe("Planning experience queries",function()
	local atlas=require("Modules.AtlasPlanner")
	local strategy=require("Modules.AtlasStrategy")
	local sim=require("Modules.CraftingSimulator")
	local inspect=require("Modules.CraftingInspection")
	local function empty(version) return {id="test",title="Strategy",version=version or "3.29.1",budget=138,nodes={},notes=""} end
	before_each(function() newBuild() end)
	after_each(function() main.popups={} end)
	it("uses one distance field and sorts literal search results by added points",function()
		local plan=empty();local tree=atlas.tree(plan.version);local neighbor=tree.nodes[tree.start].links[1]
		local costs=strategy.costs(plan);assert.are.equal(1,costs[neighbor])
		local grown=atlas.connect(plan,{neighbor});assert.are.equal(0,strategy.costs(grown)[neighbor])
		local results=strategy.results(plan,"Essence","Essence")
		assert.is_true(#results>0)
		for i,entry in ipairs(results) do if i>1 then assert.is_true(entry.cost>=results[i-1].cost) end;assert.are.equal("Essence",strategy.mechanic(entry.node)) end
		assert.are.equal(0,#plan.nodes)
	end)
	it("returns valid bounded alternatives and explicit waypoints without mutating exclusions",function()
		local plan=empty();local target=65225;local avoid={}
		local routes=strategy.routes(plan,target,avoid,atlas.tree(plan.version).nodes[atlas.tree(plan.version).start].links[1])
		assert.is_true(#routes>0)
		local seen={}
		for _,route in ipairs(routes) do
			local valid=atlas.validate(route.plan);assert.are.equal(#valid.nodes,route.cost)
			local key=table.concat(valid.nodes,",");assert.is_nil(seen[key]);seen[key]=true
		end
		assert.are.equal(0,#avoid);assert.are.equal(0,#plan.nodes)
		assert.are.equal(0,#strategy.routes(empty(),target,{target}))
	end)
	it("compares raw bonus counts and refuses cross-version plan comparisons",function()
		local a=empty();local b=atlas.connect(a,{65225});local delta=strategy.compare(a,b)
		assert.are.equal(#b.nodes,#delta.added);assert.are.equal(0,#delta.removed);assert.is_true(#delta.stats>0)
		local reverse=strategy.compare(b,a);assert.are.equal(#b.nodes,#reverse.removed)
		assert.is_false(pcall(strategy.compare,a,empty("3.27.0")))
	end)
	it("builds editable starting routes from the pinned version and budget",function()
		for _,version in ipairs(atlas.versions) do
			local plan=empty(version);plan.budget=atlas.tree(version).maxPoints
			local presets=strategy.presets(plan);assert.is_true(#presets>0)
			for _,preset in ipairs(presets) do assert.are.equal(version,atlas.validate(preset.plan).version);assert.is_true(#preset.targets<=3) end
		end
	end)
	it("accepts official link decorations and rejects lookalike hosts and unsupported builders",function()
		local plan=atlas.connect(empty(),{65225});local url=atlas.url(plan)
		assert.are.same(plan.nodes,atlas.import(url.."/?tracking=1#tree",plan.version).nodes)
		assert.is_false(pcall(atlas.import,url:gsub("www.pathofexile.com","www.pathofexile.com.invalid"),plan.version))
		assert.is_false(pcall(atlas.import,"https://poeplanner.com/atlas-tree/example",plan.version))
	end)
	it("inspects ordinary and bench modifiers without assuming every entry has spawn weights",function()
		local model=sim.model("Rarity: NORMAL\nIron Hat\nItem Level: 86")
		assert.is_true(#inspect.modDetails(model,model.mods[1].id)>2)
		assert.is_true(#inspect.modDetails(model,model.bench[1].id)>2)
	end)
	it("distinguishes a changed roll from added or removed affixes and flags socket changes",function()
		local model=sim.model("Rarity: NORMAL\nIron Hat\nItem Level: 86")
		local id=model.mods[1].id
		local a={rarity="RARE",affixes={{id=id,range=0}}};local b={rarity="RARE",affixes={{id=id,range=1,fractured=true}},sockets={{color="R",group=1}}}
		local result=table.concat(inspect.diff(model,a,b),"\n")
		assert.is_truthy(result:find("Changed:",1,true));assert.is_truthy(result:find("fractured",1,true));assert.is_truthy(result:find("Socket",1,true))
		assert.is_truthy(inspect.slots(model,b):find("Prefixes",1,true))
	end)
	it("keeps standalone modifier pickers read-only until a selection is confirmed",function()
		local chosen
		local controls=require("Classes.PlanningBrowserControl").Open("Find",{{id="a",label="Life",category="Prefix",details={"A target"}}},{choose=function(entry) chosen=entry.id end,favorites={}})
		assert.is_nil(chosen);controls.favorite:Click();assert.is_nil(chosen);controls.choose:Click();assert.are.equal("a",chosen)
	end)
	it("draws only visible text rows even for a large history",function()
		local ui=require("Modules.HeadlessUI").install({width=1024,height=768})
		local ok,message=pcall(function()
			local rows={};for i=1,10000 do rows[i]={height=18,"^7History entry "..i} end
			local list=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,16,600,200},nil,rows)
			ui:frame(function() list:Draw(main.viewPort) end)
			assert.is_true(#ui.commands<200,"Hidden rows still generate drawing commands")
			list.controls.scrollBar:SetOffset(9000);ui:frame(function() list:Draw(main.viewPort) end)
			assert.is_true(#ui.commands<200,"Scrolling draws the entire history")
		end)
		ui:restore();assert.is_true(ok,tostring(message))
	end)
end)
