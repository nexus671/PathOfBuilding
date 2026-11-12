describe("Build-owned crafting inventory",function()
	local inventory=require("Modules.CraftingInventory")
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local function project() return {id="inventory-test",title="Helmet",slot="Helmet",startingItem=raw,goals={},steps={}} end
	before_each(function() newBuild();main.popups={} end)
	it("round-trips full item states and resumes an independent working craft",function()
		local state=sim.perform(raw,{method="alchemy"},104729).state
		state.affixes[1].fractured=true
		local entry=inventory.capture(project(),state,"Fractured option");local resumed=inventory.project(entry)
		assert.same(entry.state,resumed.run.state);assert.same(entry.state,resumed.run.initial)
		assert.same({},resumed.run.actions);assert.not_equal(project().id,resumed.id)
		resumed.run.state.affixes[1].range=0.9;assert.not_equal(0.9,entry.state.affixes[1].range)
		local valid=require("Modules.CraftingProjects").validate(resumed);assert.is_true(valid.run.state.affixes[1].fractured)
	end)
	it("preserves inventory on old-client project edits and allows explicit removal",function()
		local store=build.savers.CraftingProjects;local value=project();value.inventory={inventory.capture(value,sim.model(raw).initial)};store:Upsert(value)
		value=project();value.title="Renamed project";store:Upsert(value);assert.equal(1,#store.projects[1].inventory)
		local xml={};store:Save(xml);local restored=require("Modules.CraftingProjects").new(build);restored:Load(xml)
		assert.same(store.projects,restored.projects);assert.equal(1,#inventory.entries(restored.projects,"helmet"));assert.equal(0,#inventory.entries(restored.projects,"[no match]"))
		value.inventory={};store:Upsert(value);assert.equal(0,#store.projects[1].inventory)
	end)
	it("rejects malformed inventory data and slot mismatches without changing projects",function()
		local value=project();local entry=inventory.capture(value,sim.model(raw).initial)
		assert.has_error(function() inventory.validate({entry,entry}) end)
		assert.has_error(function() inventory.validate({[2]=entry}) end)
		entry.state.affixes={{id="unknown-modifier"}};assert.has_error(function() inventory.validate({entry}) end)
		entry=inventory.capture(value,sim.model(raw).initial);entry.slot="Boots";value.inventory={entry}
		assert.has_error(function() build.savers.CraftingProjects:Upsert(value) end);assert.equal(0,#build.savers.CraftingProjects.projects)
	end)
	it("retains imprints, pending unveils and league properties through portable bundles",function()
		local state=sim.perform(raw,{method="transmute"},104729).state;state=sim.perform(raw,{method="beast_imprint"},104729,state).state
		state=sim.perform(raw,{method="regal"},104729,state).state;state=sim.perform(raw,{method="veiled_orb"},104729,state).state;state.intangibility=12;state.memoryStrands=73
		local value=project();value.inventory={inventory.capture(value,state,"Unfinished unveil")};build.savers.CraftingProjects:Upsert(value)
		local kept=build.savers.CraftingProjects.projects[1].inventory[1].state;assert.is_truthy(kept.imprint);assert.is_truthy(kept.veil);assert.equal(73,kept.memoryStrands)
		local bundle,contents=require("Modules.PlanningBundle").export(build);assert.equal(1,contents.inventory);assert.equal(1,require("Modules.PlanningBundle").import(bundle).contents.inventory)
		local resumed=inventory.project(build.savers.CraftingProjects.projects[1].inventory[1]);assert.same(kept,resumed.run.state)
	end)
end)
