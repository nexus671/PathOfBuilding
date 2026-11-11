describe("Crafting projects", function()
	local projects = require("Modules.CraftingProjects")
	local bridge = require("Modules.DesktopBuildBridge")
	local json = require("dkjson")
	before_each(function() newBuild(); bridge.prepared=nil end)
	after_each(function() bridge.prepared=nil; bridge.history={}; main.popups={} end)
	local function project()
		return {id="life-helmet",title="Life helmet",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",
			targetItem="Rarity: RARE\nPlanned Hat\nIron Hat\n+100 to maximum Life",goals={"100 Life"},
			steps={{action="Choose and test a method in Craft of Exile",stopWhen="Target modifiers present",onFailure="Stop at budget limit"}}}
	end

	it("previews a target and project separately without changing or saving the live build", function()
		local entry=project()
		local revision=bridge.revision(build)
		local prepared=bridge.prepare(build,{mode="edit",title=entry.title,baseRevision=revision,operations={{type="set_crafting_project",project=entry},{type="equip_item",slot=entry.slot,text=entry.targetItem}}})
		assert.are.equal(0,#build.savers.CraftingProjects.projects)
		assert.are.equal(1,#prepared.candidate.savers.CraftingProjects.projects)
		assert.is_true(prepared.after.LifeUnreserved > prepared.before.LifeUnreserved)
		assert.are.equal(revision,bridge.revision(build))
		assert.is_truthy(table.concat(prepared.changes," "):find("Stop at budget limit",1,true))
	end)

	it("round trips plans and opaque simulator exports through the native build XML", function()
		local entry=project()
		entry.simulatorExport='{"data":"<not executable>&"}'
		entry.steps[1].done=true
		build.savers.CraftingProjects:Upsert(entry)
		local prepared=bridge.prepare(build,{mode="edit",title="Keep crafting metadata",baseRevision=bridge.revision(build),operations={{type="set_character",level=80}}})
		local loaded=prepared.candidate.savers.CraftingProjects.projects[1]
		assert.are.equal(entry.simulatorExport,loaded.simulatorExport)
		assert.is_true(loaded.steps[1].done)
		assert.are.equal(entry.steps[1].onFailure,loaded.steps[1].onFailure)
	end)

	it("preserves unsupported metadata instead of discarding it while loading a build", function()
		local store=projects.new(build)
		local raw='{"schemaVersion":99,"projects":[]}'
		store:Load({raw})
		assert.is_truthy(store.warning)
		local xml={}; store:Save(xml)
		assert.are.equal(raw,xml[1])
		assert.are.equal(false,pcall(store.Upsert,store,project()))
	end)

	it("rejects invalid equipment targets and bounds saved projects", function()
		local store=build.savers.CraftingProjects
		local entry=project(); entry.targetItem="Rarity: NORMAL\nGold Ring"
		assert.are.equal(false,pcall(store.Upsert,store,entry))
		assert.are.equal(0,#store.projects)
		for i=1,8 do entry=project(); entry.id="project-"..i; store:Upsert(entry) end
		entry=project(); entry.id="project-9"
		assert.are.equal(false,pcall(store.Upsert,store,entry))
		assert.are.equal(8,#store.projects)
	end)
	it("keeps a different equipment base after recombination without changing its slot", function()
		local entry=project();entry.targetItem="Rarity: NORMAL\nLeather Cap"
		build.savers.CraftingProjects:Upsert(entry)
		assert.are.equal("Leather Cap",projects.item(build.savers.CraftingProjects.projects[1].targetItem).baseName)
	end)

	it("labels lossy base handoffs and retains advanced game copies", function()
		local basic=projects.handoff(project().targetItem)
		assert.are.equal("base-only",basic.mode)
		assert.is_truthy(basic.warnings[1]:find("not transferred",1,true))
		assert.is_nil(basic.itemText:find("maximum Life",1,true))
		local raw="Item Class: Helmets\nRarity: Rare\nTest Hat\nIron Hat\n--------\nItem Level: 86\n--------\n{ Prefix Modifier \"Virile\" (Tier: 3) }\n+100 to maximum Life\n--------"
		local advanced=projects.handoff(raw)
		assert.are.equal("advanced-item",advanced.mode)
		assert.is_truthy(advanced.url:find("%2B100",1,true))
		assert.is_truthy(advanced.url:find("%0D%0A",1,true))
		assert.are.equal(raw,advanced.itemText)
	end)

	it("filters native modifier references by item level without presenting weights as odds", function()
		local early=projects.inspect("Rarity: NORMAL\nIron Hat\nItem Level: 1","maximum Life",100)
		local late=projects.inspect(project().startingItem,"maximum Life",100)
		assert.is_true(late.total > early.total)
		for _,entry in ipairs(early.matches) do assert.is_true(entry.level <= 1) end
		assert.is_truthy(late.limitations[2]:find("not success probabilities",1,true))
	end)

	it("records external simulation counts as supplied evidence and rejects impossible totals", function()
		local entry=project()
		entry.simulation={patch="3.29",observedAt=os.time(),trials=100,successes=25}
		local validated=projects.validate(entry)
		assert.are.equal(25,validated.simulation.successes)
		assert.is_truthy(table.concat(projects.lines(validated)," "):find("not rerun or verified",1,true))
		entry.simulation.successes=101
		assert.are.equal(false,pcall(projects.validate,entry))
	end)

	it("supports native project editing and reversible step progress", function()
		local panel=require("Classes.CraftingProjectControl")
		build.savers.CraftingProjects:Upsert(project())
		panel.Open(build)
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main.popups[1].controls.done:Click()
		assert.is_true(build.savers.CraftingProjects.projects[1].steps[1].done)
		main.popups[1].controls.undoStep:Click()
		assert.are.equal(false,build.savers.CraftingProjects.projects[1].steps[1].done)
		main.popups[1].controls.edit:Click()
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main.popups[1].controls.title:SetText("Edited plan")
		main.popups[1].controls.save:Click()
		assert.are.equal("Edited plan",build.savers.CraftingProjects.projects[1].title)
		assert.is_true(build.modFlag)
	end)

	it("emulates currency, undoes outcomes and saves a native recipe through desktop controls", function()
		local entry=project()
		build.savers.CraftingProjects:Upsert(entry)
		require("Classes.CraftingSimulatorControl").Open(build,entry)
		local popup=main.popups[1]
		popup:Draw({x=0,y=0,width=1920,height=1080})
		popup.controls.apply:Click()
		popup.controls.undo:Click()
		popup.controls.apply:Click()
		popup.controls.page:SelByValue("Target conditions")
		popup.controls.addTarget:Click()
		popup.controls.page:SelByValue("Emulate item")
		popup.controls.keepRecipe:Click()
		assert.is_truthy(build.savers.CraftingProjects.projects[1].nativeRecipe)
		assert.are.equal(1,#build.savers.CraftingProjects.projects[1].nativeRecipe.steps)
		assert.are.equal(0,build.itemsTab.slots.Helmet.selItemId)
		assert.are.equal("Native crafting emulator and simulator",main.popups[1].title)
	end)
end)
