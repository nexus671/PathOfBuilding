describe("Crafting result model notes",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local donor="Rarity: NORMAL\nCone Helmet\nItem Level: 70"
	it("shows the 3.30 Light Radius range in modifier inspection",function()
		local model=sim.model(raw);local details=require("Modules.CraftingInspection").modDetails(model,"LightRadiusAndAccuracy3")
		local joined=table.concat(details,"\n")
		assert.matches("%(21%-30%)%% increased Light Radius",joined)
		assert.matches("3%.30 Light Radius range: 21%-30%%",joined)
		assert.matches("Light Radius",table.concat(sim.limits,"\n"))
	end)
	it("uses the 3.30 client ingredients for every resistance conversion",function()
		local cases={fire={cold={wild_lifeforce=300,primal_lifeforce=300},lightning={wild_lifeforce=300,vivid_lifeforce=300}},
			cold={fire={primal_lifeforce=300,wild_lifeforce=300},lightning={primal_lifeforce=300,vivid_lifeforce=300}},
			lightning={fire={vivid_lifeforce=300,wild_lifeforce=300},cold={vivid_lifeforce=300,primal_lifeforce=300}}}
		for from,choices in pairs(cases) do for to,cost in pairs(choices) do
			local action={method="harvest_resistance",from=from,to=to}
			assert.same(cost,sim.components(action));assert.equal(0,#sim.actionWarnings(action))
		end end
		assert.has_error(function() sim.components({method="harvest_resistance",from="fire",to="fire"}) end)
	end)
	it("prices all supported tagged Harvest reforges and augments",function()
		local expected={fire={"wild_lifeforce",50,15000},cold={"vivid_lifeforce",50,15000},lightning={"primal_lifeforce",50,15000},
			physical={"vivid_lifeforce",50,15000},life={"wild_lifeforce",75,17500},defences={"primal_lifeforce",75,17500},
			chaos={"vivid_lifeforce",100,17500},attack={"wild_lifeforce",75,17500},caster={"primal_lifeforce",75,17500},
			speed={"vivid_lifeforce",150,20000},critical={"primal_lifeforce",150,20000}}
		for tag,cost in pairs(expected) do
			assert.same({[cost[1]]=cost[2]},sim.components({method="harvest_reforge",tag=tag}))
			assert.same({[cost[1]]=cost[3],sacred_lifeforce=1},sim.components({method="harvest_augment",tag=tag}))
		end
		assert.same({primal_lifeforce=5000,sacred_lifeforce=1},sim.components({method="harvest_reforge",tag="influence"}))
		assert.has_error(function() sim.components({method="harvest_augment",tag="influence"}) end)
	end)
	it("deduplicates contextual notes and leaves ordinary actions clear",function()
		assert.are.equal(0,#sim.actionWarnings({method="alchemy"}))
		local notes=sim.recipeWarnings({steps={{method="recombine",donorItem=donor},{method="recombine",donorItem=donor},{method="alchemy",allflame={auto=true}}}})
		assert.are.equal(2,#notes);assert.are.equal("recombination_count_odds",notes[1].code);assert.are.equal("allflame_historical",notes[2].code)
		assert.are.equal("allflame_historical",sim.actionWarnings({method="ducat_kishara"})[1].code)
		local locus=sim.recipeWarnings({steps={{method="locus"},{method="locus"}}})
		assert.equal(1,#locus);assert.equal("locus_legacy",locus[1].code);assert.matches("3.30 second%-corruption",locus[1].message)
		assert.equal("locus_legacy",sim.catalog(raw,"",10).methodWarnings.locus[1].code)
		local model=sim.model(raw);assert.matches("Historical 3.29",require("Modules.CraftingWorkbench").hint("locus",model.initial,model))
		assert.equal("locus_legacy",sim.perform(raw,{method="locus"},1).warnings[1].code)
		assert.equal("locus_legacy",sim.simulate(raw,{steps={{method="locus"}},targets={},requirements={corrupted=true}},{trials=1,maxActions=1}).warnings[1].code)
	end)
	it("attaches notes to action, simulation and sampled odds results",function()
		local action={method="recombine",donorItem=donor}
		local performed=sim.perform(raw,action,1);assert.are.equal("recombination_count_odds",performed.warnings[1].code)
		local simulated=sim.simulate(raw,{steps={action},targets={},requirements={minAffixes=1}},{trials=2,maxActions=1})
		assert.are.equal("recombination_count_odds",simulated.warnings[1].code)
		local odds=sim.calculate(raw,action,{},nil,{requirements={minAffixes=1},trials=2})
		assert.are.equal("recombination_count_odds",odds.warnings[1].code)
		local historical=sim.perform(raw,{method="alchemy",allflame={auto=true}},1)
		assert.are.equal("allflame_historical",historical.warnings[1].code)
	end)
	it("marks Binding as legacy supply without disabling the craft",function()
		local action={method="binding"};local notes=sim.recipeWarnings({steps={action,action}})
		assert.equal(1,#notes);assert.equal("binding_legacy",notes[1].code);assert.equal("3.30",notes[1].asOfPatch)
		assert.equal("binding_legacy",sim.catalog(raw,"",10).methodWarnings.binding[1].code)
		local performed=sim.perform(raw,action,1);assert.equal("RARE",performed.state.rarity);assert.equal("binding_legacy",performed.warnings[1].code)
		local simulated=sim.simulate(raw,{steps={action},targets={},requirements={minAffixes=1}},{trials=1,maxActions=1});assert.equal("binding_legacy",simulated.warnings[1].code)
		local odds=sim.calculate(raw,action,{},nil,{requirements={minAffixes=1},trials=2});assert.equal("binding_legacy",odds.warnings[1].code)
	end)
	it("keeps notes with chart routes even when prices are missing",function()
		local charts=require("Modules.CraftingChartData")
		local route={label="Historical route",result={trials=1,actionDistribution={{actions=1,trials=1,successes=0}},warnings={{code="allflame_historical",message="Allflame is historical."}}}}
		local data=charts.series({route},charts.modes[3]);assert.are.equal(0,#data.series)
		assert.are.equal("Historical route: Allflame is historical.",data.warnings[1])
	end)
end)
