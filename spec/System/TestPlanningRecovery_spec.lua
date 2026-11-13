describe("Local planning draft recovery",function()
	local recovery=require("Modules.PlanningRecovery")
	local filters=require("Modules.LootFilters")
	local directory;local session
	local function entry(title) return {plan={data={schemaVersion=1,activeId="test",profiles={filters.profile("test",title)}},selected="test",page="Overview"}} end
	before_each(function()
		newBuild();directory=os.tmpname();os.remove(directory);assert(require("lfs").mkdir(directory));session=recovery.session;recovery.testDirectory=directory;recovery.cache={}
	end)
	after_each(function() for _,kind in ipairs({"filters","atlas","crafting"}) do recovery.clear(build,kind) end;os.remove(directory);recovery.testDirectory=nil;recovery.cache={};recovery.session=session;recovery.lastError=nil end)
	it("recovers the older complete slot after an interrupted write",function()
		assert.is_true(recovery.save(build,"filters",entry("First"),true));assert.is_true(recovery.save(build,"filters",entry("Second"),true))
		local latest=recovery.load(build,"filters");assert.equal("Second",latest.entry.plan.data.profiles[1].title)
		local file=assert(io.open(latest.path,"wb"));file:write('{"schemaVersion":');file:close()
		assert.equal("First",recovery.load(build,"filters").entry.plan.data.profiles[1].title)
	end)
	it("preserves earlier-session drafts until they are acknowledged",function()
		recovery.save(build,"filters",entry("Interrupted"),true);recovery.session="new-session";recovery.cache={}
		recovery.save(build,"filters",entry("Current saved state"),true)
		assert.equal("Interrupted",recovery.load(build,"filters").entry.plan.data.profiles[1].title);assert.is_true(recovery.hasPending(build))
		recovery.acknowledge(build,"filters");recovery.save(build,"filters",entry("Reviewed"),true)
		assert.equal("Reviewed",recovery.load(build,"filters").entry.plan.data.profiles[1].title);assert.is_false(recovery.hasPending(build))
	end)
	it("rejects invalid payloads and separates draft kinds",function()
		assert.is_false(recovery.save(build,"filters",{plan={data={schemaVersion=99}}},true));assert.is_nil(recovery.load(build,"filters"))
		local atlas=require("Modules.AtlasPlanner");local plan={id="test",title="Test",version="3.30.0-preview",budget=150,nodes={}}
		assert.is_true(recovery.save(build,"atlas",{plan=plan},true));assert.same(atlas.validate(plan),recovery.load(build,"atlas").entry.plan);assert.is_nil(recovery.load(build,"filters"))
	end)
	it("does not flag an identical kept plan but retains unfinished Atlas editor text",function()
		local value=entry("Kept");build.savers.LootFilters:Replace(value.plan.data);assert.is_true(recovery.isCurrent(build,"filters",recovery.clean("filters",value)))
		local plan={id="test",title="Saved Atlas",version="3.30.0-preview",budget=150,nodes={}};build.savers.AtlasPlans:Upsert(plan)
		assert.is_true(recovery.isCurrent(build,"atlas",{plan=require("Modules.AtlasPlanner").validate(plan)}))
		assert.is_false(recovery.isCurrent(build,"atlas",{plan=plan,view={title="",budgetText="-1",notes="Unfinished"}}))
	end)
	it("removes only the requested project's valid recovery slots and returns its working draft",function()
		local function craft(id)
			local p={id=id,title=id,slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",goals={},steps={}}
			local state=require("Modules.CraftingSimulator").model(p.startingItem).initial
			local run=require("Modules.CraftingInventory").run(state);run.project=p;run.kind="workbench";return {plan=run}
		end
		assert.is_true(recovery.save(build,"crafting",craft("a"),true));assert.is_true(recovery.save(build,"crafting",craft("b"),true))
		assert.is_true(recovery.save(build,"filters",entry("Unrelated filter"),true))
		local saved=recovery.forgetCraftingProject(build,"a");assert.are.equal("a",saved.draft.project.id)
		assert.is_nil(recovery.forCraftingProject(build,"a"));assert.are.equal("b",recovery.load(build,"crafting").entry.plan.project.id)
		assert.are.equal("Unrelated filter",recovery.load(build,"filters").entry.plan.data.profiles[1].title)
		assert.is_true(recovery.save(build,"crafting",{plan=saved.draft},true));assert.is_truthy(recovery.forCraftingProject(build,"a"))
	end)
	it("keeps recovery files unchanged while preparing and applying an MCP removal",function()
		local p={id="review-delete",title="Review delete",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",goals={},steps={}}
		build.savers.CraftingProjects:Upsert(p)
		local run=require("Modules.CraftingInventory").run(require("Modules.CraftingSimulator").model(p.startingItem).initial);run.project=p;run.kind="workbench"
		assert.is_true(recovery.save(build,"crafting",{plan=run},true))
		local function bytes() local f=assert(io.open(recovery.load(build,"crafting").path,"rb"));local raw=f:read("*a");f:close();return raw end
		local original=bytes();local bridge=require("Modules.DesktopBuildBridge");local base=build
		local prepared=bridge.prepare(base,{mode="edit",title="Remove guide",baseRevision=bridge.revision(base),operations={{type="remove_crafting_project",projectId=p.id}}})
		assert.are.equal(original,bytes());bridge.apply(prepared);assert.are.equal(original,bytes())
		bridge.restore();assert.are.equal(original,bytes())
	end)
end)
