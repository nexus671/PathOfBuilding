describe("Current crafting reference workflows",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local function sixAffixes(model)
		local state=copyTable(model.initial);state.rarity="RARE";state.affixes={}
		local groups,counts={},{Prefix=0,Suffix=0}
		for _,entry in ipairs(model.mods) do local mod=entry.mod
			if not groups[mod.group] and counts[mod.type] < 3 then
				state.affixes[#state.affixes+1]={id=entry.id,range=0.5};groups[mod.group]=true;counts[mod.type]=counts[mod.type]+1
			end
		end
		assert.are.equal(6,#state.affixes);return state
	end
	it("derives ghost counts, gains and scaled costs from the pinned client tables",function()
		local model=sim.model(raw)
		local profile=sim.allflameProfile(model,model.initial,{method="exalt",allflame={auto=true,upgradeTier=2}})
		assert.are.equal("3.29.3c",profile.dataPatch)
		assert.are.equal(4,profile.outcomes);assert.are.equal(8,profile.gainMin);assert.are.equal(12,profile.gainMax)
		assert.are.equal(5490,profile.sulphur)
		local basic=sim.allflameProfile(model,model.initial,{method="exalt",allflame={auto=true,upgradeTier=0}})
		assert.are.equal(2,basic.outcomes);assert.are.equal(3660,basic.sulphur)
		local limited=sim.allflameProfile(model,model.initial,{method="fracture",allflame={auto=true,upgradeTier=2}})
		assert.are.equal(2,limited.outcomes);assert.are.equal(0,limited.upgradeTier)
		local jewel=sim.model("Rarity: NORMAL\nCobalt Jewel\nItem Level: 86")
		local cheap=sim.allflameProfile(jewel,jewel.initial,{method="alchemy",allflame={auto=true,upgradeTier=2}})
		assert.are.equal(450,cheap.sulphur)
		local unsupported=sim.model("Rarity: NORMAL\nPrismatic Tincture\nItem Level: 85")
		assert.are.equal(false,pcall(sim.allflameProfile,unsupported,unsupported.initial,{method="alchemy",allflame={auto=true}}))
	end)
	it("charges derived Allflame costs once and consumes an existing imprint",function()
		local craft={method="alchemy",allflame={auto=true,upgradeTier=2}}
		local result=sim.simulate(raw,{steps={craft},targets={},requirements={minAffixes=4}},{trials=10,maxActions=1,prices={alchemy=1,dead_mans_sulphur=0.001},currency="chaos"})
		assert.are.equal(10,result.successes);assert.are.near(1.732,result.meanCost,1e-8)
		assert.are.equal(7320,result.currencySpent.dead_mans_sulphur)
		assert.is_nil(craft.allflame.outcomes)
		local magic=sim.perform(raw,{method="transmute"},12)
		local imprint=sim.perform(raw,{method="beast_imprint"},13,magic.state)
		assert.is_truthy(imprint.state.imprint)
		local ghost=sim.perform(raw,{method="alteration",allflame={auto=true}},14,imprint.state)
		assert.is_nil(ghost.state.imprint)
		assert.are.equal(false,pcall(sim.perform,raw,{method="restore_imprint"},15,ghost.state))
	end)
	it("produces four independently retained Kishara modifiers without serial crafting",function()
		local model=sim.model(raw);local state=sixAffixes(model)
		local result=sim.perform(raw,{method="ducat_kishara"},91,state)
		assert.are.equal(4,#result.choices)
		assert.are.equal(19520,result.allflame.sulphur)
		for _,choice in ipairs(result.choices) do
			assert.are.equal(1,#choice.state.affixes)
			assert.are.equal("RARE",choice.state.rarity)
			assert.is_true(choice.state.intangibility >= 8 and choice.state.intangibility <= 12)
			sim.validateState(model,choice.state)
		end
		assert.are.equal(6,#state.affixes)
	end)
	it("resets Intangibility or terminates destruction with Tzamoto",function()
		local model=sim.model(raw);local state=sixAffixes(model);state.intangibility=80
		local reset=sim.action(model,state,{method="ducat_tzamoto",allflame={auto=true}},function() return 0.1 end)
		assert.are.equal(0,reset.intangibility);assert.are.equal(6,#reset.affixes)
		local destroyed=sim.action(model,state,{method="ducat_tzamoto"},function() return 0.9 end)
		assert.is_true(destroyed.destroyed);assert.are.equal(0,#destroyed.affixes)
		assert.are.equal(80,state.intangibility)
	end)
	it("fractures two distinct modifiers on a corrupted rare Talisman",function()
		local model=sim.model("Rarity: NORMAL\nChieftain Talisman\nItem Level: 86")
		local state=sixAffixes(model);state.corrupted=true
		local result=sim.action(model,state,{method="beast_talisman_fracture",count=2},function() return 0.1 end)
		local count=0;for _,entry in ipairs(result.affixes) do if entry.fractured then count=count+1 end end
		assert.are.equal(2,count);assert.is_true(result.corrupted);sim.validateState(model,result)
		for _,entry in ipairs(state.affixes) do assert.is_nil(entry.fractured) end
		assert.are.equal(false,pcall(sim.action,sim.model(raw),sixAffixes(sim.model(raw)),{method="beast_talisman_fracture",count=2},function() return 0.1 end))
	end)
	it("distinguishes desired fractures and crafted modifiers from ordinary hits",function()
		local model=sim.model(raw);local state=sixAffixes(model);local id=state.affixes[1].id
		assert.is_true(sim.matches(state,{{anyOf={id},fractured=false,crafted=false}},nil,model))
		assert.is_false(sim.matches(state,{{anyOf={id},fractured=true}},nil,model))
		state.affixes[1].fractured=true;state.intangibility=22
		assert.is_true(sim.matches(state,{{anyOf={id},fractured=true}},nil,model,{minFractured=1,maxFractured=1,minIntangibility=20,maxIntangibility=30}))
		assert.is_false(sim.matches(state,{},nil,model,{maxFractured=0}))
		assert.is_false(sim.matches(state,{},nil,model,{maxIntangibility=0}))
		assert.is_false(pcall(sim.validateRecipe,{steps={{method="chaos"}},targets={},requirements={minFractured=2,maxFractured=1}}))
	end)
	it("enumerates all two-fracture pairs and accounts for ghost collapse",function()
		local talisman="Rarity: NORMAL\nChieftain Talisman\nItem Level: 86"
		local model=sim.model(talisman);local state=sixAffixes(model);state.corrupted=true
		local result=sim.calculate(talisman,{method="beast_talisman_fracture",count=2},{{anyOf={state.affixes[1].id},fractured=true}},state)
		assert.are.equal(15,#result.outcomes);assert.are.near(100/3,result.successChance,1e-8)
		state.corrupted=false;state.intangibility=25
		local targets={{anyOf={state.affixes[1].id}}}
		local ghosts=sim.calculate(talisman,{method="ducat_kishara"},targets,state)
		local expected=100*(0.25/6+0.75*(1-(5/6)^4))
		assert.are.near(expected,ghosts.successChance,1e-8)
		local sum=0;for _,entry in ipairs(ghosts.outcomes) do sum=sum+entry.chance end
		assert.are.near(100,sum,1e-8)
		local fixed=sim.calculate(talisman,{method="ducat_kishara",allflame={auto=true,choiceIndex=3}},targets,state)
		assert.are.near(100/6,fixed.successChance,1e-8)
		state.intangibility=100
		local collapsed=sim.calculate(talisman,{method="ducat_kishara"},targets,state)
		assert.are.near(100/6,collapsed.successChance,1e-8)
	end)
	it("selects next-affix ghosts by the same preference rules as recipes",function()
		local model=sim.model(raw);local state=sixAffixes(model);table.remove(state.affixes,6)
		local first=sim.calculate(raw,{method="exalt"},{{anyOf={state.affixes[1].id},negate=true}},state)
		local targets={{anyOf={first.outcomes[1].id}}}
		local single=sim.calculate(raw,{method="exalt"},targets,state)
		local ghosts=sim.calculate(raw,{method="exalt",allflame={auto=true}},targets,state)
		assert.are.near(100*(1-(1-single.successChance/100)^4),ghosts.successChance,1e-8)
		local sampled=sim.simulate(raw,{steps={{method="exalt",allflame={auto=true}}},targets=targets,initialState=state},{trials=1000,maxActions=1,seed=7})
		assert.is_true(sampled.confidenceLow <= ghosts.successChance and sampled.confidenceHigh >= ghosts.successChance)
	end)

	it("retains successful items, counts final modifiers and includes the starting cost",function()
		local recipe={steps={{method="alchemy"}},targets={},requirements={minAffixes=4}}
		local result=sim.simulate(raw,recipe,{trials=12,maxActions=1,prices={alchemy=2},baseCost=10,currency="chaos",retainSuccesses=3})
		assert.are.equal(12,result.successes);assert.are.equal(3,#result.retainedSuccesses)
		assert.are.equal(12,result.meanCost);assert.are.equal(12,result.currencySpent.alchemy)
		local total=0;for _,count in pairs(result.propertyDistribution.affixes) do total=total+count end
		assert.are.equal(12,total)
		for i,entry in ipairs(result.retainedSuccesses) do
			assert.are.equal(i,entry.trial);assert.are.equal(12,entry.cost)
			assert.are.equal(entry.itemText,sim.toItem(sim.model(raw),entry.state).raw)
		end
		local frequencies=0;for _,entry in pairs(result.affixDistribution) do frequencies=frequencies+entry.trials;assert.are.equal(entry.trials,entry.successes) end
		assert.is_true(frequencies >= 48 and frequencies <= 72)
		assert.is_false(pcall(sim.simulate,raw,recipe,{trials=1,maxActions=1,baseCost=2}))
	end)

	it("samples other action odds without skipping an initially matching item",function()
		local model=sim.model(raw);local state=sixAffixes(model);local targets={{anyOf={state.affixes[1].id}}}
		local result=sim.calculate(raw,{method="scour"},targets,state,{trials=12,seed=7})
		assert.is_true(result.sampled);assert.are.equal(12,result.trials);assert.are.equal(0,result.successes)
		assert.are.equal(1,result.meanActions);assert.is_nil(result.exactFor)
		assert.are.equal(6,#state.affixes)
		assert.is_false(pcall(sim.calculate,raw,{method="scour"},targets,state,{trials=2001}))
	end)

end)
