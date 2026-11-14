describe("Crafting resource usage independent of pricing",function()
	local sim=require("Modules.CraftingSimulator")
	local pricing=require("Modules.CraftingPrices")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local numbers="Metadata/Items/Currency/CurrencyRerollSocketNumbers"
	local links="Metadata/Items/Currency/CurrencyRerollSocketLinks"
	local vaal="Metadata/Items/Currency/CurrencyCorrupt"
	local scrap="Metadata/Items/Currency/CurrencyArmourQuality"
	local function entries(result)
		local out={};for _,entry in ipairs(result.resourceUsage) do out[entry.key]=entry end;return out
	end
	before_each(function() newBuild() end)
	after_each(function() require("Modules.CraftingTasks").cancel();main.popups={} end)
	it("retains physical quantities under zero and nonzero whole-action prices",function()
		local action={method="socket_bench",count=6};local key=sim.priceKey(action)
		local recipe={steps={action},targets={},requirements={sockets=6}}
		local expected
		for _,price in ipairs({0,7}) do
			local r=sim.simulate(raw,recipe,{trials=2,maxActions=1,actionPrices={[key]=price},currency="chaos"})
			assert.are.equal(price,r.meanCost);assert.are.equal(2,r.currencySpent[key]);assert.is_nil(r.currencySpent[numbers])
			local usage=entries(r);assert.are.equal(700,usage[numbers].amount);assert.are.equal(350,usage[numbers].meanPerTrial);assert.are.equal("resource",usage[numbers].kind)
			if expected then assert.are.same(expected,r.resourceUsage) else expected=r.resourceUsage end
		end
		local r=sim.simulate(raw,recipe,{trials=2,maxActions=1,prices={[numbers]=1},currency="chaos"})
		assert.are.same(expected,r.resourceUsage);assert.are.equal(350,r.meanCost);assert.are.equal(700,r.currencySpent[numbers])
	end)
	it("uses each socket transition's input for corrupted preparation and linking",function()
		local state=sim.model(raw).initial;state.corrupted=true
		local recipe={initialState=state,steps={{method="socket_bench",count=6},{method="socket_bench",count=6,linked=true}},targets={},requirements={links=6}}
		local r=sim.simulate(raw,recipe,{trials=2,maxActions=2})
		local usage=entries(r);assert.are.equal(700,usage[numbers].amount);assert.are.equal(3000,usage[links].amount);assert.are.equal(3700,usage[vaal].amount)
		assert.is_nil(r.meanCost);assert.is_truthy(next(r.unpriced))
	end)
	it("charges Allflame currency and Sulphur once per executed craft under an override",function()
		local state=sim.model(raw).initial;state.rarity="RARE";state.affixes={{id="IncreasedLife1",range=0.5}}
		local action={method="exalt",allflame={outcomes=4,gainMin=5,gainMax=5,sulphur=100}}
		local r=sim.simulate(raw,{initialState=state,steps={action},targets={},requirements={minAffixes=2}},{trials=3,maxActions=1,actionPrices={[sim.priceKey(action)]=7},currency="chaos"})
		local usage=entries(r);assert.are.equal(3,usage[pricing.key("exalt",sim.model(raw))].amount);assert.are.equal(300,usage.dead_mans_sulphur.amount)
		assert.are.equal(100,usage.dead_mans_sulphur.meanPerTrial);assert.are.equal(7,r.meanCost);assert.is_nil(r.currencySpent.dead_mans_sulphur)
	end)
	it("includes every fossil and its resonator without needing supplied prices",function()
		local fossils={"Metadata/Items/Currency/CurrencyDelveCraftingLife","Metadata/Items/Currency/CurrencyDelveCraftingCold"}
		local r=sim.simulate(raw,{steps={{method="fossil",fossils=fossils}},targets={},requirements={minAffixes=1}},{trials=2,maxActions=1})
		local usage=entries(r);for _,id in ipairs(fossils) do assert.are.equal(2,usage[pricing.key(id,sim.model(raw))].amount) end
		assert.are.equal(2,usage[pricing.key("resonator:2",sim.model(raw))].amount);assert.is_nil(r.meanCost)
	end)
	it("counts executed resources across restarts without charging rejected transitions",function()
		local recipe={steps={{method="quality"},{method="chaos",onFailureAction="restart"}},targets={},requirements={minQuality=20}}
		local r=sim.simulate(raw,recipe,{trials=2,maxActions=4,baseCost=3,prices={quality=1},currency="chaos"})
		local usage=entries(r);assert.are.equal(4,usage[scrap].amount);assert.are.equal(2,usage[scrap].meanPerTrial);assert.are.equal(1,#r.resourceUsage)
		assert.are.equal(4,r.meanActions);assert.are.equal(8,r.meanCost);assert.is_truthy(next(r.transitionErrors));assert.are.equal(0,r.successes)
	end)
	it("reports no use when targets already match and keeps starting cost separate",function()
		local state=sim.model(raw).initial;state.quality=20
		local r=sim.simulate(raw,{initialState=state,steps={{method="quality"}},targets={},requirements={minQuality=20}},{trials=2,maxActions=1,baseCost=3,currency="chaos"})
		assert.are.same({},r.resourceUsage);assert.are.equal(3,r.meanCost);assert.are.equal(0,r.meanActions)
	end)
	it("labels service units without claiming their physical ingredients are known",function()
		local r=sim.simulate(raw.."\nCorrupted",{steps={{method="locus"}},targets={},requirements={minQuality=30}},{trials=2,maxActions=1,actionPrices={locus=7},currency="chaos"})
		local usage=entries(r);assert.are.equal("service",usage.locus.kind);assert.are.equal(2,usage.locus.amount);assert.are.equal(7,r.meanCost)
	end)
	it("retains resource identities after a legal recombined base change",function()
		local base="Rarity: NORMAL\nGlorious Plate\nItem Level: 86"
		local state=sim.model(base).initial;state.origin=sim.model(raw).initial.origin;state.baseItem=base
		local r=sim.simulate(raw,{initialState=state,steps={{method="quality"}},targets={},requirements={minQuality=1}},{trials=2,maxActions=1})
		local usage=entries(r);assert.are.equal(2,usage[scrap].amount);assert.are.equal(1,#r.resourceUsage)
	end)
	it("shows ingredient quantities separately from overridden spending in the native summary",function()
		local p={id="usage",title="Usage",slot="Body Armour",startingItem=raw,goals={},steps={},preferredMethod="quality",nativeRecipe={steps={{method="quality"}},targets={},requirements={minQuality=1}}}
		local c=require("Classes.CraftingSimulatorControl").Open(build,p);c.page:SelByValue("Simulate recipe");c.page.selFunc();c.trials:SetText("2");c.budget:SetText("1");c.price:SetText("7")
		-- Run the saved property-only recipe with the selected action override.
		c.runRecipe:Click();local tasks=require("Modules.CraftingTasks");for i=1,1000 do if not tasks.job then break end;tasks.tick(build) end
		assert.is_nil(tasks.job);local lines={};for _,row in ipairs(c.resultSummary.list) do lines[#lines+1]=row[1] end;local text=table.concat(lines," ")
		assert.is_truthy(text:find("Mean spent: 7.00 chaos",1,true));assert.is_truthy(text:find("Armourer's Scrap: 2 total | 1 per trial",1,true))
		c.distribution:Click();assert.is_true(main.popups[1].controls.resources:IsEnabled());main.popups[1].controls.resources:Click()
		assert.are.equal("Crafting resources used",main.popups[1].title);local view=main.popups[1].controls
		assert.is_truthy(view.results.list[1].icon);assert.are.equal(scrap,view.results.list[1].entry.id)
		local details={};for _,row in ipairs(view.details.list) do details[#details+1]=row[1] end
		assert.is_truthy(table.concat(details," "):find("Total used: 2",1,true))
	end)
end)
