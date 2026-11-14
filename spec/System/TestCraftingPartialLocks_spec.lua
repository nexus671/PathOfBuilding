describe("3.30 partial affix locks",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local id="bench:partial-prefix-1"
	before_each(function() newBuild() end)
	it("rechecks attack protection after its blocker is removed",function()
		local model=sim.model(raw)
		model.byId.testAttackA={type="Prefix",group="testA",modTags={"attack"}}
		model.byId.testAttackB={type="Prefix",group="testB",modTags={"attack"}}
		model.byId.testBlocker={"Cannot roll Attack Modifiers",type="Suffix",group="testBlock"}
		local state={rarity="RARE",affixes={{id="testAttackA"},{id="testAttackB"},{id="testBlocker"}}}
		assert.is_true(sim.benchRerollChoices(model,state)[3])
		state.affixes[3].fractured=true;assert.is_nil(sim.benchRerollChoices(model,state)[3])
	end)
	it("keeps the selected partial-lock prefix through one and three modifier bench rerolls",function()
		local model=sim.model(raw);local selected={Prefix={},Suffix={}};local groups={}
		for _,entry in ipairs(model.mods) do local side=entry.mod.type
			if #selected[side]<(side=="Prefix" and 3 or 2) and not groups[entry.mod.group] then
				selected[side][#selected[side]+1]=entry.id;groups[entry.mod.group]=true
			end
		end
		assert.are.equal(3,#selected.Prefix);assert.are.equal(2,#selected.Suffix)
		local affixes={};for _,side in ipairs({"Prefix","Suffix"}) do for _,modId in ipairs(selected[side]) do affixes[#affixes+1]={id=modId,range=0.1234} end end
		local state=sim.validateState(model,{rarity="RARE",affixes=affixes})
		local locked=sim.perform(raw,{method="bench",modId=id},1,state).state
		local options=sim.actionOptions(model,locked,"bench_reroll");assert.are.equal(2,#options)
		for _,count in ipairs({1,3}) do for seed=1,10 do
			local result=sim.perform(raw,{method="bench_reroll",count=count},seed,locked)
			local preserved=false
			for _,entry in ipairs(result.state.affixes) do for _,modId in ipairs(selected.Prefix) do
				if entry.id==modId and entry.range==0.1234 then preserved=true end
			end end
			assert.is_true(preserved);assert.are.equal(6,#result.state.affixes)
			assert.are.equal("partial_lock_model",result.warnings[1].code)
		end end
	end)
	it("offers the lock and charges the published Divine Orb cost",function()
		local model=sim.model(raw);local mod=assert(model.byId[id])
		assert.are.equal("Suffix",mod.type);assert.are.equal("1 Prefix Modifier cannot be changed",mod[1])
		local cost,sources=require("Modules.CraftingBenchCosts").cost(model,id)
		assert.are.same({["Metadata/Items/Currency/CurrencyModValues"]=1},cost)
		assert.are.same({"GGG 3.30 patch notes"},sources)
		assert.are.equal("Prefix",model.byId["bench:partial-suffix-2"].type)
		assert.are.same({["Metadata/Items/Currency/CurrencyModValues"]=2},require("Modules.CraftingBenchCosts").cost(model,"bench:partial-suffix-2"))
		local prefix;for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" then prefix=entry.id;break end end
		local magic=sim.validateState(model,{rarity="MAGIC",affixes={{id=prefix,range=0.5}}})
		local locked=sim.perform(raw,{method="bench",modId=id},1,magic)
		local rare=copyTable(locked.state);rare.rarity="RARE"
		local options=sim.actionOptions(model,rare,"bench_reroll");assert.are.equal(1,#options);assert.are.equal(1,options[1].action.count)
		local costs=sim.catalog(raw,"bench_reroll",10,rare).benchServiceCosts
		assert.is_true(costs[1].available);assert.is_false(costs[2].available);assert.matches("reroll 3",costs[2].unavailableReason)
		local altered=sim.perform(raw,{method="alteration"},2,locked.state)
		local found=false;for _,entry in ipairs(altered.state.affixes) do if entry.id==prefix then found=true end end
		assert.is_true(found)
	end)
	it("preserves a randomly selected prefix and rejects unsupported operations",function()
		local model=sim.model(raw);local prefixes,groups={},{}
		for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" and not groups[entry.mod.group] then
			prefixes[#prefixes+1]=entry.id;groups[entry.mod.group]=true;if #prefixes==2 then break end
		end end
		assert.are.equal(2,#prefixes)
		local state=sim.validateState(model,{rarity="RARE",affixes={{id=prefixes[1],range=0.5},{id=prefixes[2],range=0.5}}})
		local locked=sim.perform(raw,{method="bench",modId=id},1,state)
		assert.are.equal("partial_lock_model",locked.warnings[1].code)
		local imported=sim.model(locked.itemText);assert.is_true(sim.hasPartialLock(imported,imported.initial))
		local before=copyTable(locked.state)
		local socketed=sim.perform(raw,{method="socket_bench",count=4},3,locked.state)
		assert.are.same(before.affixes,socketed.state.affixes);assert.are.equal(4,#socketed.state.sockets)
		local linked=sim.perform(raw,{method="omen_connections"},4,socketed.state)
		assert.are.same(before.affixes,linked.state.affixes);assert.are.equal(0,linked.state.sockets[4].group)
		local coloured=sim.perform(raw,{method="chromatic"},5,linked.state)
		local whitened=sim.perform(raw,{method="socket_white_bench"},6,coloured.state)
		assert.are.same(before.affixes,whitened.state.affixes);for _,socket in ipairs(whitened.state.sockets) do assert.are.equal("W",socket.color) end
		local quality=sim.perform(raw,{method="quality"},7,whitened.state)
		assert.are.same(before.affixes,quality.state.affixes);assert.is_true(quality.state.quality>0)
		local enchanted=sim.perform(raw,{method="harvest_enchant",enchantId="LifeBodyEnchant"},8,quality.state)
		assert.are.same(before.affixes,enchanted.state.affixes);assert.are.equal("LifeBodyEnchant",enchanted.state.harvestEnchant)
		local exarch=sim.perform(raw,{method="eldritch_implicit",side="Exarch",tier=2},9,enchanted.state)
		local eater=sim.perform(raw,{method="eldritch_implicit",side="Eater",tier=1},10,exarch.state)
		local conflict=sim.perform(raw,{method="conflict"},11,eater.state)
		assert.are.same(before.affixes,conflict.state.affixes);assert.is_true(#conflict.state.implicits>=1 and #conflict.state.implicits<=2)
		local hits=0
		for _,first in ipairs({0.25,0.75}) do for _,second in ipairs({0.25,0.75}) do
			local draws=0;local outcome=sim.action(model,locked.state,{method="annul"},function() draws=draws+1;return draws==1 and first or second end)
			if sim.matches(outcome,{{anyOf={prefixes[1]}}},nil,model) then hits=hits+1 end
			assert.are.equal(2,draws)
		end end
		assert.are.equal(3,hits)
		local scoured=sim.perform(raw,{method="scour"},1,locked.state)
		assert.are.equal(1,#scoured.state.affixes);assert.is_true(scoured.state.affixes[1].id==prefixes[1] or scoured.state.affixes[1].id==prefixes[2])
		assert.is_nil(scoured.state.affixes[1].partialProtected);assert.are.same(before,locked.state)
		local allowed,reason=require("Modules.CraftingAvailability").check("fossil",locked.state,model)
		assert.is_false(allowed);assert.matches("not yet modeled",reason)
		assert.is_false(pcall(sim.perform,raw,{method="fossil",fossils={"Metadata/Items/Currency/CurrencyDelveCraftingLife"}},1,locked.state))
		local result=sim.calculate(raw,{method="annul"},{{anyOf={prefixes[1]}}},locked.state,{trials=1000})
		assert.is_false(result.sampled);assert.are.near(75,result.successChance,1e-9);assert.are.equal(3,#result.outcomes)
		local chances={};for _,outcome in ipairs(result.outcomes) do chances[outcome.id]=outcome.chance end
		assert.are.near(25,chances[prefixes[1]],1e-9);assert.are.near(25,chances[prefixes[2]],1e-9);assert.are.near(50,chances[id],1e-9)
		assert.are.equal("partial_lock_model",result.warnings[1].code)
		local fractured=copyTable(locked.state);fractured.affixes[1].fractured=true
		local fracturedRaw=sim.toItem(model,fractured).raw;local fracturedModel=sim.model(fracturedRaw)
		local fracturedOdds=sim.calculate(fracturedRaw,{method="annul"},{{anyOf={prefixes[1]},fractured=true}},fracturedModel.initial)
		assert.is_false(fracturedOdds.sampled);assert.are.near(100,fracturedOdds.successChance,1e-9)
		local fracturedChances={};for _,outcome in ipairs(fracturedOdds.outcomes) do fracturedChances[outcome.id]=outcome.chance end
		assert.is_nil(fracturedChances[prefixes[1]]);assert.are.near(25,fracturedChances[prefixes[2]],1e-9);assert.are.near(75,fracturedChances[id],1e-9)
		local project={id="partial-lock",title="Partial lock guide",slot="Body Armour",startingItem=sim.toItem(model,state).raw,goals={},steps={},nativeRecipe={steps={{method="bench",modId=id},{method="annul"}},targets={{anyOf={prefixes[1]}}}}}
		local store=build.savers.CraftingProjects;store:Upsert(project);local xml={};store:Save(xml)
		local restored=require("Modules.CraftingProjects").new(build);restored:Load(xml)
		assert.is_nil(restored.warning);assert.are.equal(id,restored.projects[1].nativeRecipe.steps[1].modId)
		local replay=sim.simulate(restored.projects[1].startingItem,restored.projects[1].nativeRecipe,{trials=20,maxActions=2,forceFirstAction=true})
		assert.are.equal("partial_lock_model",replay.warnings[1].code)
	end)
	it("does not invent an outcome when every modifier may be protected",function()
		local model=sim.model(raw);local multi
		for _,entry in ipairs(model.bench) do if entry.mod[1]=="Can have up to 3 Crafted Modifiers" then multi=entry.id;break end end
		assert.is_not_nil(multi)
		local state={rarity="RARE",affixes={{id="bench:partial-suffix-2",crafted=true,range=0.5},{id="bench:partial-prefix-1",crafted=true,range=0.5},{id=multi,crafted=true,range=0.5}}}
		assert.is_nil(sim.partialAnnulBranches(model,state))
		local choices,reason=sim.harvestChoices(model,state,"harvest_augment")
		assert.are.equal(0,#choices);assert.matches("modifier that can be removed",reason)
		local allowed=require("Modules.CraftingAvailability").check("harvest_augment",state,model);assert.is_false(allowed)
		local ok,reason=pcall(sim.perform,raw,{method="bench_reroll",count=1},1,state)
		assert.is_false(ok);assert.matches("removable modifier",tostring(reason))
		allowed,reason=require("Modules.CraftingAvailability").check("bench_reroll",state,model);assert.is_false(allowed);assert.matches("removable modifier",reason)
		assert.are.equal(0,#sim.actionOptions(model,state,"bench_reroll"))
		local costs=sim.catalog(raw,"bench_reroll",10,state).benchServiceCosts
		assert.are.equal(2,#costs);for _,entry in ipairs(costs) do assert.is_false(entry.available);assert.is_truthy(entry.unavailableReason) end
	end)
	it("does not offer a reforge tag blocked in every partial-lock selection",function()
		local hat="Rarity: NORMAL\nIron Hat\nItem Level: 86";local model=sim.model(hat)
		local state=sim.validateState(model,{rarity="RARE",affixes={{id="AttackerTakesDamage1",range=0.5}}})
		local locked=sim.perform(hat,{method="bench",modId=id},1,state).state;local before=copyTable(locked)
		local choices=sim.harvestChoices(model,locked,"harvest_reforge");local found={}
		for _,choice in ipairs(choices) do found[choice.label]=true end
		assert.is_nil(found.physical);assert.is_true(found.life);assert.are.same(before,locked)
		assert.is_false(pcall(sim.perform,hat,{method="harvest_reforge",tag="physical"},1,locked))
	end)
	it("counts failed Harvest transitions as failures even when the input already matches",function()
		local model=sim.model(raw);local prefix
		for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" then prefix=entry.id;break end end
		local state=sim.validateState(model,{rarity="RARE",affixes={{id=prefix,range=0.5}}})
		local locked=sim.perform(raw,{method="bench",modId=id},1,state).state
		local original=sim.action;local calls=0
		sim.action=function(modelArg,stateArg,craftArg,randomArg)
			if craftArg.method=="harvest_reforge" then calls=calls+1;if calls==1 then error("modeled selection unavailable") end end
			return original(modelArg,stateArg,craftArg,randomArg)
		end
		local ok,result=pcall(sim.calculate,raw,{method="harvest_reforge",tag="fire"},{{anyOf={prefix}}},locked,{trials=10})
		sim.action=original;assert.is_true(ok,tostring(result))
		assert.are.equal(9,result.successes);assert.is_truthy(next(result.transitionErrors));assert.is_true(result.sampled)
	end)
	it("reports real branch-dependent Harvest failures without rejecting valid branches",function()
		local model=sim.model(raw);local ids,groups={},{}
		for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" and not groups[entry.mod.group] then
			ids[#ids+1]=entry.id;groups[entry.mod.group]=true;if #ids==3 then break end
		end end
		local input={rarity="RARE",affixes={{id=ids[1],range=0.5,fractured=true},{id=ids[2],range=0.5},{id=ids[3],range=0.5}}}
		local fracturedRaw=sim.toItem(model,input).raw;local fracturedModel=sim.model(fracturedRaw)
		local locked=sim.perform(fracturedRaw,{method="bench",modId="bench:partial-prefix-2"},1,fracturedModel.initial).state
		local choices=sim.harvestChoices(fracturedModel,locked,"harvest_reforge");local possible=false
		for _,choice in ipairs(choices) do if choice.label=="defences" then possible=true end end;assert.is_true(possible)
		local seed;local encounter=require("Modules.CalcEncounter")
		for candidate=1,1000 do
			local value=encounter.seed(candidate,1,31);value=value*16807%2147483647;local first=value/2147483647
			value=value*16807%2147483647;local second=value/2147483647
			if first>=1/3 and second>=1/2 then seed=candidate;break end
		end
		assert.is_not_nil(seed)
		assert.is_false(pcall(sim.perform,fracturedRaw,{method="harvest_reforge",tag="defences"},seed,locked))
		local result=sim.calculate(fracturedRaw,{method="harvest_reforge",tag="defences"},{{anyOf={ids[1]},fractured=true}},locked,{trials=100,seed=seed})
		assert.is_true(result.successes>0 and result.successes<100);assert.is_truthy(next(result.transitionErrors))
		local failures=0;for _,count in pairs(result.transitionErrors) do failures=failures+count end
		assert.are.equal(100-failures,result.successes)
		assert.are.equal(result.successes*75,result.currencySpent.primal_lifeforce)
	end)
	it("enumerates two-lock selections without counting permutations twice",function()
		local model=sim.model(raw);local ids,groups={},{}
		for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" and not groups[entry.mod.group] then
			ids[#ids+1]=entry.id;groups[entry.mod.group]=true;if #ids==3 then break end
		end end
		local initial=sim.validateState(model,{rarity="RARE",affixes={{id=ids[1],range=0.5},{id=ids[2],range=0.5},{id=ids[3],range=0.5}}})
		local locked=sim.perform(raw,{method="bench",modId="bench:partial-prefix-2"},1,initial)
		local odds=sim.calculate(raw,{method="annul"},{{anyOf={ids[1]}}},locked.state)
		assert.is_false(odds.sampled);assert.are.near(100*5/6,odds.successChance,1e-9)
		local sum=0;for _,outcome in ipairs(odds.outcomes) do sum=sum+outcome.chance end;assert.are.near(100,sum,1e-9)
	end)
	it("preserves partial locks through jewellery quality and implicit rolls",function()
		local ring="Rarity: NORMAL\nGold Ring\nItem Level: 86";local model=sim.model(ring);local prefix
		for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" then prefix=entry.id;break end end
		local state=sim.validateState(model,{rarity="RARE",affixes={{id=prefix,range=0.5}}})
		local locked=sim.perform(ring,{method="bench",modId=id},1,state)
		local catalyst=sim.perform(ring,{method="catalyst",catalyst=8},2,locked.state)
		local blessed=sim.perform(ring,{method="blessed"},3,catalyst.state)
		assert.are.same(locked.state.affixes,blessed.state.affixes);assert.is_true(blessed.state.catalystQuality>0)
	end)
	it("protects two modifiers on either side through removal and value rerolls",function()
		local model=sim.model(raw)
		for _,side in ipairs({"Prefix","Suffix"}) do
			local ids,groups={},{}
			for _,entry in ipairs(model.mods) do if entry.mod.type==side and not groups[entry.mod.group] then
				ids[#ids+1]=entry.id;groups[entry.mod.group]=true;if #ids==2 then break end
			end end
			local initial=sim.validateState(model,{rarity="RARE",affixes={{id=ids[1],range=0.1},{id=ids[2],range=0.2}}})
			local lock="bench:partial-"..side:lower().."-2"
			local item=sim.perform(raw,{method="bench",modId=lock},9,initial)
			local rerolled=sim.perform(raw,{method="divine"},17,item.state)
			assert.are.equal(0.1,rerolled.state.affixes[1].range);assert.are.equal(0.2,rerolled.state.affixes[2].range)
			local annulled=sim.perform(raw,{method="annul"},17,item.state)
			assert.are.equal(2,#annulled.state.affixes);assert.are.equal(ids[1],annulled.state.affixes[1].id);assert.are.equal(ids[2],annulled.state.affixes[2].id)
			local scoured=sim.perform(raw,{method="scour"},17,item.state)
			assert.are.equal(2,#scoured.state.affixes)
			local rerolledItem=sim.perform(raw,{method="chaos"},17,item.state)
			local kept={};for _,entry in ipairs(rerolledItem.state.affixes) do kept[entry.id]=true end
			assert.is_true(kept[ids[1]]);assert.is_true(kept[ids[2]])
			if side=="Prefix" then
				local before=copyTable(item.state)
				for _,method in ipairs({"harvest_reforge","harvest_augment"}) do
					local result=sim.perform(raw,{method=method,tag="fire"},19,item.state)
					local remaining={};for _,entry in ipairs(result.state.affixes) do remaining[entry.id]=true end
					assert.is_true(remaining[ids[1]]);assert.is_true(remaining[ids[2]])
					assert.are.equal("partial_lock_model",result.warnings[1].code);assert.are.same(before,item.state)
					assert.is_truthy(result.warnings[1].message:find("before adding",1,true))
					assert.are.equal(#result.state.affixes,#sim.annulCandidates(model,result.state))
				end
			end
		end
	end)
end)
