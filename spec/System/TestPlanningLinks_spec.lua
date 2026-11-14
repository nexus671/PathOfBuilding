describe("Linked planning tools",function()
	local filters=require("Modules.LootFilters")
	local dependencies=require("Modules.LootFilterDependencies")
	local function craft() return {id="helmet",title="Helmet",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",goals={},steps={}} end
	before_each(function() newBuild();main.popups={} end)
	after_each(function() main.popups={} end)
	it("distinguishes quoted numeric modifier names from counts when checking linked targets",function()
		build.savers.CraftingProjects:Upsert(craft());local profile=filters.profile("filter","Filter");profile.rules=filters.generate(build,profile)
		profile.rules[1].text='Show\n HasExplicitMod "1" "foo"'
		local current=copyTable(profile.rules);current[1].text='Show\n HasExplicitMod 1 "foo"'
		local generate=filters.generate;filters.generate=function() return current end
		local ok,report=pcall(dependencies.report,build,profile);filters.generate=generate
		assert.is_true(ok);assert.is_true(report.stale);assert.equal("Changed",report.entries[1].status)
	end)
	it("does not mark linked targets stale for harmless string quoting",function()
		build.savers.CraftingProjects:Upsert(craft());local profile=filters.profile("filter","Filter");profile.rules=filters.generate(build,profile)
		profile.rules[1].text='Show\n BaseType "IronHat"'
		local current=copyTable(profile.rules);current[1].text='Show\n BaseType IronHat'
		local generate=filters.generate;filters.generate=function() return current end
		local ok,report=pcall(dependencies.report,build,profile);filters.generate=generate
		assert.is_true(ok);assert.is_false(report.stale)
	end)
	it("detects changed or removed generated targets without treating styles or inventory as dependencies",function()
		local project=craft();build.savers.CraftingProjects:Upsert(project);local profile=filters.profile("filter","Filter");profile.rules=filters.generate(build,profile)
		assert.is_false(dependencies.report(build,profile).stale)
		profile.rules[1].enabled=false;profile.rules[1].text=profile.rules[1].text.."\n SetFontSize 20";assert.is_false(dependencies.report(build,profile).stale)
		project.inventory={require("Modules.CraftingInventory").capture(project,require("Modules.CraftingSimulator").model(project.startingItem).initial)};build.savers.CraftingProjects:Upsert(project);assert.is_false(dependencies.report(build,profile).stale)
		project.startingItem=project.startingItem:gsub("86","87");build.savers.CraftingProjects:Upsert(project);local report=dependencies.report(build,profile);assert.is_true(report.stale);assert.equal("Changed",report.entries[1].status)
		profile.rules=filters.generate(build,profile);assert.is_false(dependencies.report(build,profile).stale)
		build.savers.CraftingProjects.projects={};assert.is_true(dependencies.report(build,profile).stale)
	end)
	it("links modeled recipe currencies to the filter and marks changed recipes stale",function()
		local project=craft();project.nativeRecipe={steps={{method="omen_connections"},{method="beast_max_links"}},targets={},requirements={links=4}}
		build.savers.CraftingProjects:Upsert(project)
		local profile=filters.profile("craft-resources","Craft resources");profile.rules=filters.generate(build,profile)
		local names={};for _,rule in ipairs(profile.rules) do names[rule.title]=true end
		assert.is_true(names["Omen of Connections"]);assert.is_true(names["Orb of Fusing"]);assert.is_nil(names["The Black Morrigan"])
		assert.equal("Show",filters.simulate(profile,{BaseType="Omen of Connections"}).action)
		assert.is_false(dependencies.report(build,profile).stale)
		project.nativeRecipe.steps={{method="socket_white_bench"}};build.savers.CraftingProjects:Upsert(project)
		assert.is_true(dependencies.report(build,profile).stale)
		profile.rules=filters.generate(build,profile);names={};for _,rule in ipairs(profile.rules) do names[rule.title]=true end
		assert.is_nil(names["Omen of Connections"]);assert.is_true(names["Orb of Scouring"])
	end)
	it("preserves recipe pickups and reports inspection failures",function()
		local project=craft();project.nativeRecipe={steps={{method="omen_connections"}},targets={},requirements={links=4}}
		build.savers.CraftingProjects:Upsert(project);local profile=filters.profile("review-craft","Review craft");profile.rules=filters.generate(build,profile)
		project.nativeRecipe.steps={{method="omen_connections"},{method="scour"}};build.savers.CraftingProjects:Upsert(project)
		local sim=require("Modules.CraftingSimulator");local original=sim.model;sim.model=function() error("fixture failure") end
		local ok,rules,warnings=pcall(filters.generate,build,profile)
		local reportOk,report=pcall(dependencies.report,build,profile);sim.model=original
		assert.is_true(ok);assert.equal(1,#warnings);assert.equal("craft:helmet",warnings[1].origin)
		assert.is_true(reportOk,report);assert.is_true(report.stale);assert.equal("Needs review",report.entries[1].status)
		local found=false;for _,rule in ipairs(rules) do if rule.title=="Omen of Connections" then found=true end end;assert.is_true(found)
		report=dependencies.report(build,profile);assert.equal("Changed",report.entries[1].status)
	end)
	it("shows recipe inspection warnings when refreshing pickups in the workspace",function()
		local project=craft();project.nativeRecipe={steps={{method="omen_connections"}},targets={},requirements={links=4}}
		build.savers.CraftingProjects:Upsert(project);local profile=filters.profile("review-ui","Review UI");profile.rules=filters.generate(build,profile)
		local workspace=require("Modules.PlanningWorkspace").new(build);workspace:Show("filters",{data={schemaVersion=1,activeId=profile.id,profiles={profile}}})
		project.nativeRecipe.steps={{method="omen_connections"},{method="chaos"}};build.savers.CraftingProjects:Upsert(project)
		local sim=require("Modules.CraftingSimulator");local original=sim.model;sim.model=function() error("fixture failure") end
		local ok,err=pcall(function() workspace.controls.generate:Click();assert.is_truthy(main.popups[1].controls.results) end)
		sim.model=original;assert.is_true(ok,err)
	end)
	it("leaves entirely manual filters untracked and preserves personal overrides on refresh",function()
		build.savers.CraftingProjects:Upsert(craft());local profile=filters.profile("filter","Filter");profile.rules={filters.rule("mine","Personal",{'BaseType == "Chaos Orb"'})}
		assert.is_false(dependencies.report(build,profile).stale);local original=copyTable(profile.rules[1]);profile.rules=filters.generate(build,profile);assert.same(original,profile.rules[1])
		local opened;dependencies.open(build,{openWorkbench=function(project) opened=project.id end},"craft:helmet");assert.equal("helmet",opened)
		assert.has_error(function() dependencies.open(build,{},"craft:missing") end)
	end)
	it("reuses generated dependencies until native source state changes",function()
		local project=craft();build.savers.CraftingProjects:Upsert(project);local p=filters.profile("filter","Filter");local original=filters.generate;local calls=0
		filters.generate=function(...) calls=calls+1;return original(...) end
		local ok,err=pcall(function()
			dependencies.report(build,p);dependencies.report(build,p);assert.equal(1,calls)
			project.startingItem=project.startingItem:gsub("86","87");build.savers.CraftingProjects:Upsert(project);dependencies.report(build,p);assert.equal(2,calls)
		end)
		filters.generate=original;assert.is_true(ok,err)
	end)
	it("detects skill and active weapon changes before recalculation",function()
		local original=build.skillsTab.socketGroupList
		build.skillsTab.socketGroupList={{enabled=true,slot="Weapon 1",gemList={{enabled=true,nameSpec="Fireball"}}},{enabled=true,slot="Weapon 1 Swap",gemList={{enabled=true,nameSpec="Arc"}}}}
		local profile=filters.profile("skills","Skills");profile.rules=filters.generate(build,profile)
		local revision=build.outputRevision;assert.is_false(dependencies.report(build,profile).stale)
		build.itemsTab.activeItemSet.useSecondWeaponSet=true
		assert.equal(revision,build.outputRevision);assert.is_true(dependencies.report(build,profile).stale)
		profile.rules=filters.generate(build,profile);assert.is_false(dependencies.report(build,profile).stale)
		build.skillsTab.socketGroupList[2].enabled=false
		assert.equal(revision,build.outputRevision);assert.is_true(dependencies.report(build,profile).stale)
		build.itemsTab.activeItemSet.useSecondWeaponSet=false;build.skillsTab.socketGroupList=original
	end)
	it("keeps the source filter draft and previous working craft when following a link",function()
		local project=craft();build.savers.CraftingProjects:Upsert(project);local workspace=require("Modules.PlanningWorkspace").new(build)
		local profile=filters.profile("filter","Unsaved filter name");workspace:Show("filters",{data={schemaVersion=1,activeId=profile.id,profiles={profile}},dirty=true})
		workspace.cache.filters.layout.openWorkbench(project);assert.equal("crafting",workspace.page);assert.is_truthy(workspace.drafts.filters.plan.dirty)
		workspace.controls.currency_alchemy:Click();workspace.controls.apply:Click();local previous=workspace.cache.crafting.layout.snapshot();assert.equal(1,#previous.actions)
		local item=require("Modules.CraftingInventory").capture(project,previous.state);workspace.cache.crafting.layout.openWorkbench(require("Modules.CraftingInventory").project(item))
		assert.equal(1,#workspace.craftDrafts[project.id].actions)
		workspace:Show("filters");assert.equal("Unsaved filter name",workspace.cache.filters.layout.snapshot().data.profiles[1].title)
	end)
end)
