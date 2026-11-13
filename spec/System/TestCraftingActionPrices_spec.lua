describe("Crafting action price isolation",function()
	local sim=require("Modules.CraftingSimulator")
	local pricing=require("Modules.CraftingPrices")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local alchemy="Metadata/Items/Currency/CurrencyUpgradeToRare"
	local chaos="Metadata/Items/Currency/CurrencyRerollRare"
	local scour="Metadata/Items/Currency/CurrencyConvertToNormal"
	local function book(values) return {currency="chaos",source="Action scope quotes",quotedAt=1700000000,values=values or {[alchemy]=1}} end
	local function benchAction()
		local model=sim.model(raw)
		for _,entry in ipairs(model.bench) do
			local cost=require("Modules.CraftingBenchCosts").cost(model,entry.id)
			if cost and cost[alchemy]==1 then return {method="bench",modId=entry.id} end
		end
		error("No Alchemy-priced bench fixture")
	end
	local function recipe(action) return {steps={action},targets={},requirements={minAffixes=1}} end
	local function finish()
		local tasks=require("Modules.CraftingTasks")
		for i=1,1000 do if not tasks.job then return end;tasks.tick(build) end
		error("Crafting job did not complete")
	end
	local function text(control)
		local lines={};for _,row in ipairs(control.list) do lines[#lines+1]=row[1] end;return table.concat(lines," ")
	end
	before_each(function() newBuild() end)
	after_each(function() require("Modules.CraftingTasks").cancel();main.popups={} end)
	it("prices only matching action keys while resource aliases still price every use",function()
		local bench=benchAction()
		local function run(action,overrides,resources)
			return sim.simulate(raw,recipe(action),{trials=2,maxActions=1,priceBook=book(),actionPrices=overrides,prices=resources})
		end
		local result=run(bench,{alchemy=7})
		assert.are.equal(1,result.meanCost);assert.are.equal(0,result.actionPriceOverridesApplied)
		assert.are.same({{step=1,method="bench",priceKey=bench.modId}},result.stepPriceKeys)
		assert.is_true(result.actionPriceOverridesSupplied);assert.are.equal(2,result.currencySpent[alchemy])
		result=run({method="alchemy"},{alchemy=7});assert.are.equal(7,result.meanCost);assert.are.equal(2,result.actionPriceOverridesApplied)
		result=run(bench,{[bench.modId]=0});assert.are.equal(0,result.meanCost);assert.are.equal(2,result.actionPriceOverridesApplied)
		result=run(bench,nil,{alchemy=5});assert.are.equal(5,result.meanCost);assert.are.equal(0,result.actionPriceOverridesApplied)
		result=run(bench,{[bench.modId]=3},{alchemy=5});assert.are.equal(3,result.meanCost)
	end)
	it("validates action quotes and leaves caller maps unchanged",function()
		local action=benchAction();local options={trials=1,maxActions=1,priceBook=book(),prices={alchemy=2},actionPrices={[action.modId]=3}}
		local before=copyTable(options);local result=sim.simulate(raw,recipe(action),options)
		assert.are.equal(3,result.meanCost);assert.are.same(before,options)
		for _,value in ipairs({-1,math.huge,0/0,"2"}) do
			assert.is_false(pcall(sim.simulate,raw,recipe(action),{trials=1,maxActions=1,priceBook=book(),actionPrices={[action.modId]=value}}))
		end
		assert.is_false(pcall(sim.simulate,raw,recipe(action),{trials=1,maxActions=1,actionPrices={[action.modId]=2}}))
		assert.is_false(pcall(sim.simulate,raw,recipe(action),{trials=1,maxActions=1,currency="chaos",actionPrices={["bad\0key"]=2}}))
		local tooMany={};for i=1,101 do tooMany["action:"..i]=1 end
		assert.is_false(pcall(sim.simulate,raw,recipe(action),{trials=1,maxActions=1,currency="chaos",actionPrices=tooMany}))
		assert.is_nil(pricing.actionOverride(nil,nil));assert.are.same({alchemy=0},pricing.actionOverride("alchemy",0))
		local model=sim.model(raw);local ids={};for _,entry in ipairs(model.fossils) do ids[#ids+1]=entry.id end
		table.sort(ids,function(a,b) if #a~=#b then return #a>#b end;return a<b end)
		local craft={method="fossil",fossils={ids[1],ids[2],ids[3],ids[4]},allflame={auto=true,upgradeTier=0}}
		local key=sim.priceKey(craft);assert.is_true(#key>240)
		local run={schemaVersion=1,state=model.initial,initial=model.initial,history={},actions={},sequence=0,configured={fossil=craft},targets={},requirements={minAffixes=1},settings={currency="chaos",price="7"},priceOverrides={[key]="7"},method="fossil"}
		build.savers.CraftingProjects:Upsert({id="long-action-key",title="Four fossil Allflame quote",slot="Body Armour",startingItem=raw,goals={},steps={},run=run})
		local xml=build:SaveDB("Long action quote");loadBuildFromXML(xml,"Long action quote")
		assert.are.equal("7",build.savers.CraftingProjects.projects[1].run.priceOverrides[key])
	end)
	it("explains an unused native override and keeps recipe comparisons isolated",function()
		local p={id="scope-ui",title="Scoped action quote",slot="Body Armour",startingItem=raw,goals={},steps={},preferredMethod="alchemy",nativeRecipe=recipe(benchAction()),priceBook=book()}
		local c=require("Classes.CraftingSimulatorControl").Open(build,p);c.page:SelByValue("Simulate recipe");c.page.selFunc()
		c.trials:SetText("2");c.budget:SetText("1");c.price:SetText("7");c.runRecipe:Click();finish()
		assert.is_truthy(text(c.resultSummary):find("Mean spent: 1.00 chaos",1,true))
		assert.is_truthy(text(c.resultSummary):find("Selected-action override was not used by this recipe.",1,true))
		c.simulate:Click();finish();assert.is_truthy(text(c.resultSummary):find("Mean spent: 7.00 chaos",1,true))
		assert.is_truthy(text(c.resultSummary):find("Includes selected-action price overrides.",1,true))
		c.compareRecipes:Click();local compare=main.popups[1].controls
		compare.price1:SetText("many");compare.run:Click();assert.are.equal("Compare recipes",main.popups[1].title)
		main:ClosePopup();assert.are.equal("many",compare.price1.buf)
		compare.price1:SetText("7");compare.run:Click();finish()
		local summary=text(compare.results)
		assert.is_truthy(summary:find("Mean spent: 7.00 chaos",1,true));assert.is_truthy(summary:find("Mean spent: 1.00 chaos",1,true))
		assert.are.equal(1,p.priceBook.values[alchemy])
	end)
	it("uses pinned costs for crafted-mod removal and one or three modifier reforges",function()
		local model=sim.model(raw)
		assert.are.same({[scour]=1},sim.components({method="remove_crafted"},model.initial,model))
		assert.are.same({[chaos]=8},sim.components({method="bench_reroll",count=1},model.initial,model))
		assert.are.same({[chaos]=3},sim.components({method="bench_reroll",count=3},model.initial,model))
		local performed=sim.perform(raw,{method="bench",modId="bench:1"},1);assert.are.equal("bench:1",performed.priceKey)
		local crafted=performed.state
		local result=sim.simulate(raw,{steps={{method="remove_crafted"}},targets={},requirements={maxAffixes=0}},
			{trials=2,maxActions=1,initialState=crafted,priceBook=book({[scour]=2})})
		assert.are.equal(2,result.meanCost);assert.are.equal(2,result.currencySpent[scour]);assert.are.equal(0,#result.sampleState.affixes)
		local rare=sim.perform(raw,{method="alchemy"},1).state
		for count,cost in pairs({[1]=8,[3]=3}) do
			result=sim.simulate(raw,recipe({method="bench_reroll",count=count}),{trials=2,maxActions=1,initialState=rare,forceFirstAction=true,priceBook=book({[chaos]=1})})
			assert.are.equal(cost,result.meanCost);assert.are.equal(cost*2,result.currencySpent[chaos])
		end
		local catalog=sim.catalog(raw,"bench_reroll",10);assert.are.equal(2,#catalog.benchServiceCosts)
		for _,service in ipairs(catalog.benchServiceCosts) do assert.is_true(service.ingredientCostsKnown);assert.are.equal(sim.priceKey(service.action),service.priceKey);assert.is_truthy(service.components[chaos]);assert.is_truthy(service.costSources[1]:find("reroll_rare_mods",1,true)) end
		local unknown={item={type="Unknown class",base={}}}
		assert.is_nil(require("Modules.CraftingBenchCosts").service(unknown,{method="remove_crafted"}))
	end)
	it("scopes fossil totals to the exact subset without changing other resonator quotes",function()
		local life,cold="Metadata/Items/Currency/CurrencyDelveCraftingLife","Metadata/Items/Currency/CurrencyDelveCraftingCold"
		local aliases=pricing.aliases(sim.model(raw))
		local prices=book({[life]=1,[cold]=2,[aliases["resonator:1"]]=2,[aliases["resonator:2"]]=4})
		local key=sim.priceKey({method="fossil",fossils={life,cold}})
		local result=sim.optimizeFossils(raw,{}, {fossils={life,cold},maxSockets=2,trials=2,requirements={minAffixes=1},priceBook=prices,actionPrices={[key]=9}})
		local costs={};for _,entry in ipairs(result.combinations) do assert.are.equal(sim.priceKey({method="fossil",fossils=entry.fossils}),entry.priceKey);costs[entry.priceKey]=entry.meanCost
			assert.are.equal(#entry.fossils==2 and 2 or 0,entry.actionPriceOverridesApplied)
		end
		assert.are.equal(3,costs[sim.priceKey({method="fossil",fossils={life}})])
		assert.are.equal(4,costs[sim.priceKey({method="fossil",fossils={cold}})])
		assert.are.equal(9,costs[key])
		local csv=require("Modules.CraftingFossilResults").csv(result)
		assert.is_truthy(csv:find('"Action override uses"',1,true));assert.is_truthy(csv:find('"Resource overrides supplied"',1,true))
		assert.is_true(result.actionPriceOverridesSupplied);assert.is_false(result.resourcePriceOverridesSupplied)
	end)
end)
