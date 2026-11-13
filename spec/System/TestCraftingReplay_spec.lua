describe("Native crafting simulation replay",function()
	local tasks=require("Modules.CraftingTasks")
	local panel=require("Classes.CraftingSimulatorControl")
	local function project()
		return {id="replay",title="Captured quality recipe",slot="Body Armour",startingItem="Rarity: NORMAL\nPlate Vest\nItem Level: 86",goals={},steps={},preferredMethod="alchemy",
			nativeRecipe={steps={{method="quality"}},targets={},requirements={minQuality=1}},
			priceBook={currency="chaos",source="Replay quotes",quotedAt=1700000000,values={["Metadata/Items/Currency/CurrencyArmourQuality"]=2}}}
	end
	local function page(controls,value) controls.page:SelByValue(value);controls.page.selFunc() end
	local function finish()
		for i=1,1000 do if not tasks.job then return end;tasks.tick(build) end
		error("Replay did not finish")
	end
	local function summary(controls)
		local lines={};for _,row in ipairs(controls.resultSummary.list) do lines[#lines+1]=row[1] end;return table.concat(lines," ")
	end
	before_each(function() tasks.cancel();newBuild() end)
	after_each(function() tasks.cancel();main.popups={} end)
	it("refines the captured saved recipe after action, working item and inputs change",function()
		local c=panel.Open(build,project());page(c,"Simulate recipe")
		c.trials:SetText("2");c.budget:SetText("1");c.price:SetText("7");c.baseCost:SetText("3")
		c.runRecipe:Click();finish()
		assert.is_truthy(summary(c):find("Mean spent: 5.00 chaos",1,true))
		page(c,"Emulate item");c.apply:Click();page(c,"Simulate recipe")
		c.resourcePrices:Click();local quotes=main.popups[1].controls
		quotes.search:SetText("Armourer's Scrap",true);quotes.price:SetText("20",true);quotes.keep:Click()
		assert.are.equal(20,build.savers.CraftingProjects.projects[1].priceBook.values["Metadata/Items/Currency/CurrencyArmourQuality"])
		c.price:SetText("99");c.baseCost:SetText("17");c.budget:SetText("5");c.seed:SetText("19")
		c.distribution:Click();main.popups[1].controls.moreTrials:Click();finish()
		assert.is_truthy(summary(c):find("Modeled successes: 32 / 32",1,true))
		assert.is_truthy(summary(c):find("Mean spent: 5.00 chaos",1,true))
		assert.are.equal("32",c.trials.buf)
		assert.is_truthy(summary(c):find("Captured: 1 action/trial | seed 104729",1,true))
		assert.are.equal("99",c.price.buf);assert.are.equal("17",c.baseCost.buf);assert.are.equal("5",c.budget.buf);assert.are.equal("19",c.seed.buf)
	end)
	it("prevents duplicate jobs and preserves an unrelated job when closing",function()
		local c=panel.Open(build,project());page(c,"Simulate recipe")
		assert.is_truthy(c.intro:GetProperty("label"):find("Orb of Alchemy",1,true))
		c.simulate:Click();local job=assert(tasks.job)
		for _,key in ipairs({"simulate","runRecipe","exact","compareRecipes","optimize"}) do assert.is_false(c[key]:IsEnabled(),key) end
		c.simulate:Click();c.runRecipe:Click();assert.are.equal(job,tasks.job)
		assert.are.equal("Crafting workbench",main.popups[1].title)
		c.cancelJob:Click();assert.is_nil(tasks.job);assert.is_true(c.simulate:IsEnabled());assert.is_true(c.runRecipe:IsEnabled())
		c.simulate:Click();c.close:Click();assert.is_nil(tasks.job)
		c=panel.Open(build,project())
		local foreign=tasks.start(build,function() return {} end,function() end)
		c.close:Click();assert.are.equal(foreign,tasks.job)
	end)
	it("retains captured replay through layout changes and safely handles older results",function()
		local layout={width=920,height=580,mount=function(w,h,title,controls) main:OpenPopup(w,h,title,controls,nil,nil,"close") end,openProjects=function() main:ClosePopup() end}
		local p=project();local c=panel.Open(build,p,layout);page(c,"Simulate recipe")
		c.trials:SetText("2");c.budget:SetText("1");c.baseCost:SetText("3");c.runRecipe:Click();finish()
		local snapshot=layout.snapshot();local original=snapshot.lastSimulation
		main:ClosePopup();layout.workbench=snapshot;c=panel.Open(build,p,layout)
		c.price:SetText("99");c.seed:SetText("19");c.distribution:Click();main.popups[1].controls.moreTrials:Click();finish()
		local refined=layout.snapshot().lastSimulation
		assert.are.equal(32,refined.trials);assert.are.equal(5,refined.meanCost)
		for i=1,2 do assert.are.same(original.retainedSuccesses[i],refined.retainedSuccesses[i]) end
		main:ClosePopup();newBuild();snapshot.lastSimulationRun=nil;layout.workbench=snapshot;c=panel.Open(build,p,layout)
		c.distribution:Click();assert.is_false(main.popups[1].controls.moreTrials:IsEnabled())
	end)
end)
