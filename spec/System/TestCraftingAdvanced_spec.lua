describe("Advanced native crafting", function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local random=function() return 0.42 end
	local function rare() return sim.perform(raw,{method="alchemy"},12).state end
	local function tag(model,id,wanted) for _,value in ipairs(model.byId[id].modTags or {}) do if value == wanted then return true end end;return nil end
	it("resolves plain tincture and multi-line flask values without losing their rolls", function()
		local tincture="Rarity: MAGIC\nPersevering Prismatic Tincture of Mastery\nItem Level: 85\nQuality: 20\nImplicits: 1\n100% increased Elemental Damage with Melee Weapons\n26% reduced Mana Burn rate\n29% increased Melee Weapon Attack Speed"
		local model=sim.model(tincture)
		assert.are.equal(2,#model.initial.affixes)
		local found={};for _,entry in ipairs(model.initial.affixes) do found[entry.id]=entry end
		assert.is_truthy(found.TinctureToxicityRate4)
		assert.is_truthy(found.TinctureIncreasedAttackSpeed3)
		assert.is_truthy(sim.toItem(model,model.initial).raw:find("29%% increased Melee Weapon Attack Speed"))
		local flask="Rarity: MAGIC\nPanicked Divine Life Flask of Assuaging\nItem Level: 81\nQuality: 20\nImplicits: 0\n11% reduced Amount Recovered\nInstant Recovery when on Low Life\nGrants Immunity to Bleeding for 17 seconds if used while Bleeding\nGrants Immunity to Corrupted Blood for 17 seconds if used while affected by Corrupted Blood"
		local life=sim.model(flask)
		assert.are.equal(2,#life.initial.affixes)
		assert.are.equal(2,#sim.model(sim.toItem(life,life.initial).raw).initial.affixes)
		local impossible=tincture:gsub("29%% increased Melee Weapon Attack Speed","999% increased Melee Weapon Attack Speed")
		assert.are.equal(false,pcall(sim.model,impossible))
	end)
	it("offers independent Allflame outcomes and charges currency and Sulphur once", function()
		local state=copyTable(sim.model(raw).initial);state.rarity="RARE";state.affixes={{id="IncreasedLife1",range=0.5}}
		local craft={method="exalt",allflame={outcomes=4,gainMin=5,gainMax=5,sulphur=100}}
		local result=sim.perform(raw,craft,88,state)
		assert.are.equal(4,#result.choices)
		for _,choice in ipairs(result.choices) do
			assert.are.equal(2,#choice.state.affixes)
			assert.are.equal(5,choice.state.intangibility)
			assert.are.equal("IncreasedLife1",choice.state.affixes[1].id)
			assert.is_truthy(choice.itemText)
		end
		craft.allflame.choiceIndex=4
		local selected=sim.perform(raw,craft,88,state)
		assert.are.equal(result.choices[4].itemText,selected.itemText)
		assert.are.equal(0,state.intangibility)
		local recipe={steps={craft},targets={},requirements={minAffixes=2}}
		local trials=sim.simulate(raw,recipe,{initialState=state,trials=10,maxActions=1,prices={exalt=2,dead_mans_sulphur=0.01},currency="chaos"})
		assert.are.equal(10,trials.successes)
		assert.are.equal(3,trials.meanCost)
		assert.are.equal(10,trials.currencySpent.exalt)
		assert.are.equal(1000,trials.currencySpent.dead_mans_sulphur)
		assert.is_truthy(sim.calculate(raw,craft,{{anyOf={"FireResist1"}}},state).allflameProfile)
		local free=copyTable(craft);free.allflame.sulphur=0
		local noSulphur=sim.simulate(raw,{steps={free},targets={},requirements={minAffixes=2}},{initialState=state,trials=1,maxActions=1,prices={exalt=2},currency="chaos"})
		assert.are.equal(2,noSulphur.meanCost)
		assert.is_nil(noSulphur.currencySpent.dead_mans_sulphur)
	end)
	it("collapses Allflame at full Intangibility without increasing it or blocking ordinary crafting", function()
		local model=sim.model(raw.."\nIntangibility: 100%")
		assert.are.equal(100,model.initial.intangibility)
		local craft={method="alchemy",allflame={outcomes=4,gainMin=5,gainMax=10,sulphur=30,choiceIndex=4}}
		local result=sim.perform(raw.."\nIntangibility: 100%",craft,12)
		assert.are.equal(1,#result.choices)
		assert.is_true(result.allflame.collapsed)
		assert.are.equal(100,result.state.intangibility)
		local ordinary=sim.perform(raw.."\nIntangibility: 100%",{method="alchemy"},12)
		assert.are.equal(100,ordinary.state.intangibility)
		assert.is_nil(ordinary.choices)
		assert.are.equal(false,pcall(sim.perform,raw,{method="bench",modId="bench:1",allflame=craft.allflame},12))
	end)
	it("adds a weighted Rotmother modifier and preserves it through native item import", function()
		local belt="Rarity: NORMAL\nLeather Belt\nItem Level: 86"
		local model=sim.model(belt);local state=copyTable(model.initial);state.rarity="RARE"
		local result=sim.perform(belt,{method="ducat_rotmother"},12,state)
		assert.are.equal(1,#result.state.affixes)
		assert.is_truthy(data.itemMods.Ducat[result.state.affixes[1].id])
		assert.are.equal(result.state.affixes[1].id,sim.model(result.itemText).initial.affixes[1].id)
		assert.are.equal(false,pcall(sim.perform,belt,{method="ducat_rotmother"},12,result.state))
		assert.are.equal(false,pcall(sim.perform,raw,{method="ducat_rotmother"},12,rare()))
		local natural=sim.pool(model,model.initial)
		for _,entry in ipairs(natural) do assert.is_nil(data.itemMods.Ducat[entry.id]) end
	end)
	it("calibrates predictable recombination to observed odds and retains the chosen host level", function()
		local model=sim.model(raw);local donorModel=sim.model("Rarity: NORMAL\nCone Helmet\nItem Level: 70")
		local input=copyTable(model.initial);input.rarity="MAGIC";input.affixes={{id="IncreasedLife1",range=0.75}}
		local donor=copyTable(donorModel.initial);donor.rarity="MAGIC";donor.affixes={{id="FireResist1",range=0.25}}
		local craft={method="recombine_predictable",donorItem=sim.toItem(donorModel,donor).raw,selectedMods={left={"IncreasedLife1"},right={"FireResist1"}},reportedSuccessChance=40}
		local targets={{anyOf={"IncreasedLife1"}},{anyOf={"FireResist1"}}}
		local odds=sim.calculate(raw,craft,targets,input)
		assert.are.near(40,odds.successChance,1e-8)
		assert.are.near(60,odds.destructionChance,1e-8)
		assert.are.near(40,odds.outcomes[1].chance+odds.outcomes[2].chance,1e-8)
		local rightPick=(odds.outcomes[1].chance+odds.outcomes[2].chance/2)/100
		local result=sim.action(model,input,craft,function() return rightPick end)
		assert.are.equal("Cone Helmet",sim.toItem(model,result).baseName)
		assert.are.equal(70,sim.toItem(model,result).itemLevel)
		assert.are.equal("RARE",result.rarity)
		assert.are.equal(2,#result.affixes)
		sim.validateState(model,result)
		local added=sim.perform(raw,{method="exalt"},44,result)
		assert.are.equal(3,#added.state.affixes)
		assert.are.equal("Cone Helmet",new("Item"):Item(added.itemText).baseName)
		local failed=sim.action(model,input,craft,function() return 0.99 end)
		assert.is_true(failed.destroyed)
		local trial=sim.simulate(raw,{steps={craft},targets=targets},{initialState=input,trials=40,maxActions=1,seed=11})
		assert.are.equal(40,trial.successes+trial.destroyedTrials)
		assert.are.equal(false,pcall(sim.action,model,input,{method=craft.method,donorItem=craft.donorItem,selectedMods=craft.selectedMods},random))
		local duplicate=copyTable(craft);duplicate.selectedMods.left={"IncreasedLife1","IncreasedLife1"}
		assert.are.equal(false,pcall(sim.action,model,input,duplicate,random))
		local invalid=copyTable(craft);invalid.reportedSuccessChance=101
		assert.are.equal(false,pcall(sim.action,model,input,invalid,random))
	end)
	it("stops inside a repeated step as soon as a partial final goal is achieved", function()
		local model=sim.model(raw);local first=sim.perform(raw,{method="alchemy"},777).state.affixes[1].id
		local alternative
		for _,entry in ipairs(model.mods) do if entry.id ~= first and entry.mod.group == model.byId[first].group then alternative=entry.id;break end end
		assert.is_truthy(alternative)
		local targets={{anyOf={first}},{anyOf={alternative}}}
		local result=sim.simulate(raw,{steps={{method="alchemy",maxAttempts=3,untilTargets=targets}},targets=targets,requiredGroups=1},{seed=777,trials=1,maxActions=3})
		assert.are.equal(1,result.successes)
		assert.are.equal(1,result.meanActions)
	end)
	it("applies Foulborn tier bias without changing the currency's rarity transition", function()
		local model=sim.model(raw);local state=copyTable(model.initial);state.rarity="RARE"
		local ordinary=sim.calculate(raw,{method="exalt"},{{anyOf={"FireResist1"}}},state)
		local biased=sim.calculate(raw,{method="foulborn_exalt"},{{anyOf={"FireResist1"}}},state)
		assert.is_true(ordinary.successChance > 0)
		assert.are.equal(0,biased.successChance)
		local magic=sim.perform(raw,{method="transmute"},1)
		local upgraded=sim.perform(raw,{method="foulborn_regal"},2,magic.state)
		assert.are.equal("RARE",upgraded.state.rarity)
		assert.are.equal(#magic.state.affixes+1,#upgraded.state.affixes)
		assert.is_nil(upgraded.state.memoryFoulborn)
		assert.is_nil(upgraded.state.memoryActive)
	end)
	it("matches independently published native side weights and refactors retained memory tiers", function()
		local model=sim.model(raw);local full=sim.pool(model,model.initial);local totals={Prefix=0,Suffix=0}
		local oldWeight
		for _,entry in ipairs(full) do local kind=model.byId[entry.id].type;totals[kind]=totals[kind]+entry.weight;if entry.id == "FireResist8" then oldWeight=entry.weight end end
		assert.are.equal(39275,totals.Prefix)
		assert.are.equal(78400,totals.Suffix)
		local active=copyTable(model.initial);active.memoryActive=82
		local cut=sim.pool(model,active);local found
		for _,entry in ipairs(cut) do if entry.id == "FireResist8" then found=entry.weight end end
		assert.are.equal(oldWeight*4,found)
	end)
	it("uses the measured memory tier boundary and consumes strands only on relevant currency", function()
		local model=sim.model(raw.."\nMemory Strands: 82")
		assert.are.equal(82,model.initial.memoryStrands)
		local active=copyTable(model.initial);active.memoryActive=82
		local pool=sim.pool(model,active);local fire={}
		for _,entry in ipairs(pool) do if model.byId[entry.id].group == "FireResistance" then fire[#fire+1]=entry.id;assert.is_true(model.byId[entry.id].level >= 72) end end
		assert.are.equal(2,#fire)
		local rolled=sim.perform(raw.."\nMemory Strands: 82",{method="alchemy"},77)
		assert.is_true(rolled.state.memoryStrands >= 32 and rolled.state.memoryStrands <= 82)
		assert.is_nil(rolled.state.memoryActive)
		local reforged=sim.perform(raw.."\nMemory Strands: 82",{method="harvest_reforge",tag="life"},78,rolled.state)
		assert.are.equal(rolled.state.memoryStrands,reforged.state.memoryStrands)
	end)
	it("samples the published Remembrance observations and independently upgrades an Unravelling affix", function()
		local result=sim.perform(raw,{method="remembrance"},123)
		assert.is_true(result.state.memoryStrands >= 10 and result.state.memoryStrands <= 100)
		assert.is_true(sim.matches(result.state,{},nil,sim.model(raw),{minMemoryStrands=10,maxMemoryStrands=100}))
		local ring="Rarity: NORMAL\nAmber Amulet\nItem Level: 86"
		local state=copyTable(sim.model(ring).initial);state.rarity="RARE";state.memoryStrands=100;state.affixes={{id="Strength1",range=0.5}}
		local upgraded=sim.perform(ring,{method="unravelling"},124,state)
		assert.are.equal(0,upgraded.state.memoryStrands)
		assert.is_true(upgraded.state.affixes[1].id ~= "Strength1")
		assert.are.equal(1,#upgraded.state.affixes)
		sim.validateState(sim.model(ring),upgraded.state)
	end)
	it("models Locus destruction as a terminal paid outcome and pairs distinct corruption groups", function()
		local model=sim.model(raw)
		local destroyed=sim.action(model,model.initial,{method="locus"},function() return 0.99 end)
		assert.is_true(destroyed.destroyed)
		assert.are.equal(false,pcall(sim.toItem,model,destroyed))
		assert.are.equal(false,pcall(sim.action,model,destroyed,{method="alchemy"},random))
		local pair=sim.action(model,model.initial,{method="locus"},function() return 0.01 end)
		assert.are.equal(2,#pair.corruptedImplicits)
		assert.is_true(pair.corruptedImplicits[1].id ~= pair.corruptedImplicits[2].id)
		sim.validateState(model,pair)
		local id=pair.corruptedImplicits[1].id
		local result=sim.simulate(raw,{steps={{method="locus"}},targets={{anyOf={id},scope="implicit"}}},{trials=200,maxActions=1,seed=99,prices={locus=1},currency="chaos"})
		assert.is_true(result.destroyedTrials > 0)
		assert.are.equal(0,result.budgetExhausted)
		assert.are.equal(200,result.currencySpent.locus)
		assert.are.equal(1,result.meanCost)
	end)
	it("preserves existing socket colours and includes corrupted bench surcharges", function()
		local state=copyTable(sim.model(raw).initial);state.corrupted=true;state.sockets={{color="B",group=0},{color="R",group=0}}
		local result=sim.perform(raw,{method="socket_bench",count=4,linked=true},1,state)
		assert.are.equal("B",result.state.sockets[1].color)
		assert.are.equal("R",result.state.sockets[2].color)
		assert.are.equal("W",result.state.sockets[3].color)
		local costs=sim.components({method="socket_bench",count=4,linked=true},state)
		assert.are.equal(10,costs["Metadata/Items/Currency/CurrencyRerollSocketNumbers"])
		assert.are.equal(5,costs["Metadata/Items/Currency/CurrencyRerollSocketLinks"])
		assert.are.equal(15,costs["Metadata/Items/Currency/CurrencyCorrupt"])
		assert.are.equal(false,pcall(sim.perform,raw,{method="socket_bench",count=1},1))
	end)
	it("keeps the exact influence family when Dominance upgrades a shared modifier group", function()
		local state=copyTable(sim.model(raw).initial)
		state.rarity="RARE";state.influences={"basilisk"}
		state.affixes={{id="IgnitingConfluxInfluence1",range=0.5},{id="SpellAddedChaosDamageInfluence1",range={0.5,0.5}}}
		local result=sim.perform(raw,{method="dominance"},1,state)
		assert.are.equal(1,#result.state.affixes)
		assert.are.equal("IgnitingConfluxInfluenceMaven",result.state.affixes[1].id)
		sim.validateState(sim.model(raw),result.state)
	end)
	it("forces the only open meta-modifier side with the Bestiary craft", function()
		local model=sim.model(raw);local state=copyTable(model.initial);state.rarity="RARE"
		local used={};for _,entry in ipairs(model.mods) do if entry.mod.type == "Suffix" and not used[entry.mod.group] and #state.affixes < 3 then state.affixes[#state.affixes+1]={id=entry.id,range=0.5};used[entry.mod.group]=true end end
		local result=sim.perform(raw,{method="beast_meta"},20,state)
		local last=result.state.affixes[4]
		assert.is_true(last.crafted)
		assert.are.equal("Suffixes Cannot Be Changed",model.byId[last.id][1])
	end)
	it("uses native Ducat pools and keeps Pantheon skills out of Bestiary options", function()
		local model=sim.model(raw)
		local cyaxan=sim.perform(raw,{method="ducat_cyaxan"},99,rare())
		local found=false;for _,entry in ipairs(cyaxan.state.affixes) do if data.itemMods.Mercenary[entry.id] then found=true end end
		assert.is_true(found)
		local pantheon=sim.perform(raw,{method="ducat_brinehook"},100)
		assert.is_truthy(data.beastCraft[pantheon.state.affixes[1].id])
		assert.are.equal(false,pcall(sim.perform,raw,{method="beast_aspect",modId=pantheon.state.affixes[1].id},100))
		assert.are.equal(8,#sim.actionOptions(model,model.initial,"beast_aspect"))
		local jewel="Rarity: NORMAL\nMurderous Eye Jewel\nItem Level: 86"
		local rolled=sim.perform(jewel,{method="alchemy"},101)
		local augmented=sim.perform(jewel,{method="ducat_merrick"},102,rolled.state)
		assert.are.equal(5,#augmented.state.affixes)
		assert.is_true(augmented.state.corrupted)
		sim.validateState(sim.model(jewel),augmented.state)
	end)
	it("keeps generated Eldritch tier identities on reimport and rerolls a blank base implicit", function()
		local result=sim.perform(raw,{method="eldritch_implicit",side="Exarch",tier=4},97)
		local imported=sim.model(result.itemText)
		assert.is_nil(imported.unresolvedEldritch)
		assert.are.equal(result.state.implicits[1].id,imported.initial.implicits[1].id)
		local both=sim.perform(result.itemText,{method="eldritch_implicit",side="Eater",tier=4},98)
		assert.are.equal(2,#both.state.implicits)
		local ring="Rarity: NORMAL\nGold Ring\nItem Level: 86"
		local blessed=sim.perform(ring,{method="blessed"},3)
		local item=new("Item"):Item(blessed.itemText)
		assert.are.equal(1,#item.implicitModLines)
		assert.is_truthy(item.implicitModLines[1].line:find("Rarity",1,true))
	end)
	it("forces current non-white colours and keeps tainted socket changes independent of affixes", function()
		local model=sim.model(raw)
		local sockets=sim.perform(raw,{method="socket_bench",count=4,linked=true},11).state
		local coloured=sim.perform(raw,{method="socket_colour_bench",count=3},12,sockets)
		local count=0;for _,socket in ipairs(coloured.state.sockets) do if socket.color ~= "W" then count=count+1 end end
		assert.is_true(count >= 3)
		assert.are.equal(0,#coloured.state.affixes)
		sockets.corrupted=true
		local fewer=sim.action(model,sockets,{method="tainted_jeweller"},function() return 0.9 end)
		assert.are.equal(3,#fewer.sockets)
		local more=sim.action(model,fewer,{method="tainted_jeweller"},function() return 0.1 end)
		assert.are.equal(4,#more.sockets)
		assert.are.equal("W",more.sockets[4].color)
		assert.is_true(more.sockets[4].group ~= more.sockets[3].group)
		local linked=sim.action(model,more,{method="tainted_fusing"},function() return 0.1 end)
		assert.is_true(sim.matches(linked,{},nil,model,{links=4}))
		assert.are.equal(false,pcall(sim.action,model,sockets,{method="chromatic"},random))
	end)
	it("applies current special fossil outcomes and requires a revealed Tangled effect", function()
		local fractured=sim.perform(raw,{method="fossil",fossils={"Metadata/Items/Currency/CurrencyDelveCraftingMirror"}},80)
		local count=0;for _,entry in ipairs(fractured.state.affixes) do if entry.fractured then count=count+1 end end
		assert.are.equal(1,count)
		local corrupted=sim.perform(raw,{method="fossil",fossils={"Metadata/Items/Currency/CurrencyDelveCraftingVaal"}},81)
		assert.is_true(corrupted.state.corrupted)
		assert.are.equal(1,#corrupted.state.corruptedImplicits)
		assert.is_true(new("Item"):Item(corrupted.itemText).corrupted)
		local fossil={method="fossil",fossils={"Metadata/Items/Currency/CurrencyDelveCraftingRandom"}}
		assert.are.equal(false,pcall(sim.perform,raw,fossil,1))
		fossil.tangledOutcome="Metadata/Items/Currency/RandomFossilOutcome1"
		local result=sim.perform(raw,fossil,82)
		local model=sim.model(raw)
		for _,entry in ipairs(result.state.affixes) do assert.are.equal(nil,tag(model,entry.id,"resistance")) end
	end)
	it("corrupts equipment and keeps tainted affix currency restricted to corrupted rares", function()
		local model=sim.model(raw)
		local corrupted=sim.action(model,rare(),{method="vaal"},function() return 0.01 end)
		assert.is_true(corrupted.corrupted)
		assert.are.equal(1,#corrupted.corruptedImplicits)
		sim.validateState(model,corrupted)
		assert.is_true(sim.matches(corrupted,{{anyOf={corrupted.corruptedImplicits[1].id},scope="implicit"}},nil,model))
		assert.are.equal(false,pcall(sim.action,model,rare(),{method="tainted_chaos"},random))
		local scoured=sim.action(model,corrupted,{method="tainted_chaos"},function() return 0.9 end)
		assert.are.equal("NORMAL",scoured.rarity)
		assert.is_true(scoured.corrupted)
		assert.are.equal(false,pcall(sim.action,model,scoured,{method="tainted_exalt"},random))
		local brick=sim.action(model,model.initial,{method="vaal"},function() return 0.6 end)
		assert.are.equal(6,#brick.affixes)
		assert.is_true(brick.corrupted)
	end)
	it("recombines onto either base and continues the chosen base through later currency", function()
		local model=sim.model(raw)
		local donorModel=sim.model("Rarity: NORMAL\nCone Helmet\nItem Level: 70")
		local prefix,suffix
		for _,entry in ipairs(model.mods) do if entry.mod.type == "Prefix" and entry.mod.group == "IncreasedLife" then prefix=entry.id end end
		for _,entry in ipairs(donorModel.mods) do if entry.mod.type == "Suffix" and entry.mod.group == "FireResistance" then suffix=entry.id end end
		assert.is_truthy(prefix);assert.is_truthy(suffix)
		local input=copyTable(model.initial);input.rarity="MAGIC";input.affixes={{id=prefix,range=0.75}}
		local donor=copyTable(donorModel.initial);donor.rarity="MAGIC";donor.affixes={{id=suffix,range=0.25}}
		local result=sim.action(model,input,{method="recombine",donorItem=sim.toItem(donorModel,donor).raw},function() return 0.8 end)
		assert.are.equal("Cone Helmet",sim.toItem(model,result).baseName)
		assert.are.equal(80,sim.toItem(model,result).itemLevel)
		assert.are.equal(2,#result.affixes)
		sim.validateState(model,result)
		local next=sim.perform(raw,{method="regal"},55,result)
		assert.are.equal("Cone Helmet",new("Item"):Item(next.itemText).baseName)
		assert.are.equal(3,#next.state.affixes)
		assert.are.equal(1,#input.affixes)
		assert.are.equal(false,pcall(sim.action,model,input,{method="recombine",donorItem="Rarity: NORMAL\nGold Ring\nItem Level: 80"},random))
	end)
	it("uses item-level quality gains and replaces catalyst types without keeping old quality", function()
		local low="Rarity: NORMAL\nIron Hat\nItem Level: 1"
		assert.are.equal(20,sim.perform(low,{method="quality"},1).state.quality)
		local ring="Rarity: NORMAL\nGold Ring\nItem Level: 1"
		local first=sim.perform(ring,{method="catalyst",catalyst=8},2)
		assert.are.equal(20,first.state.catalystQuality)
		assert.are.equal(8,new("Item"):Item(first.itemText).catalyst)
		local changed=sim.perform(ring,{method="catalyst",catalyst=4},2,first.state)
		assert.are.equal(4,changed.state.catalyst)
		assert.are.equal(20,changed.state.catalystQuality)
		assert.are.equal(false,pcall(sim.perform,raw,{method="catalyst",catalyst=1},1))
	end)
	it("requires corruption for tainted quality and continues a corrupted hypothetical item", function()
		assert.are.equal(false,pcall(sim.perform,raw,{method="tainted_quality"},1))
		local state=copyTable(sim.model(raw).initial);state.corrupted=true
		local result=sim.perform(raw,{method="tainted_quality"},12,state)
		assert.is_true(result.state.quality >= 0 and result.state.quality <= 29)
		assert.is_true(new("Item"):Item(result.itemText).corrupted)
		assert.are.equal(false,pcall(sim.perform,raw,{method="quality"},1,state))
	end)
	it("raises and lowers adjacent Eldritch tiers through Conflict", function()
		local left=sim.perform(raw,{method="eldritch_implicit",side="Exarch",tier=4},123)
		local both=sim.perform(raw,{method="eldritch_implicit",side="Eater",tier=4},124,left.state)
		local next=sim.action(sim.model(raw),both.state,{method="conflict"},random)
		assert.are.equal(5,next.implicits[1].tier)
		assert.are.equal(3,next.implicits[2].tier)
		sim.validateState(sim.model(raw),next)
		assert.are.equal(false,pcall(sim.perform,raw,{method="conflict"},1,left.state))
	end)
	it("reports bounded-trial distributions, spending quantiles and route visits", function()
		local result=sim.simulate(raw,{steps={{method="socket_bench",count=4,linked=true}},targets={},requirements={links=4}},{trials=10,maxActions=2,prices={["socket_bench:4:true"]=3},currency="chaos"})
		assert.are.equal(10,result.successes)
		assert.are.equal(10,result.actionDistribution[1].trials)
		assert.are.equal(1,result.successfulActionQuantiles.p95)
		assert.are.equal(3,result.spendingQuantiles.p50)
		assert.are.equal(10,result.routeCounts[1].executed)
		assert.are.equal(0,result.budgetExhausted)
	end)
	it("pins supplemental game data and exposes native advanced options", function()
		local data=require("Modules.CraftingAdvanced").data()
		assert.are.equal("3.29.3.6",data.patch)
		local model=sim.model(raw)
		assert.is_true(#model.fossils >= 20)
		assert.is_true(#sim.actionOptions(model,model.initial,"eldritch_implicit") == 8)
		assert.is_true(#sim.actionOptions(model,model.initial,"harvest_reforge") >= 10)
	end)
	it("supports ordinary jewels and flask affix limits", function()
		for _,base in ipairs({"Cobalt Jewel","Small Life Flask"}) do
			local text="Rarity: NORMAL\n"..base.."\nItem Level: 86"
			local model=sim.model(text)
			local result=sim.perform(text,{method=base == "Cobalt Jewel" and "alchemy" or "transmute"},123)
			assert.is_true(#result.state.affixes <= sim.capacities(model,result.state).total)
			assert.is_truthy(new("Item"):Item(result.itemText).baseName)
			if base == "Small Life Flask" then assert.are.equal(false,pcall(sim.perform,text,{method="alchemy"},123)) end
		end
	end)
	it("blocks a fossil's forbidden modifier tags and preserves fractures", function()
		local model=sim.model(raw)
		local fossil="Metadata/Items/Currency/CurrencyDelveCraftingLife"
		for seed=1,30 do
			local result=sim.perform(raw,{method="fossil",fossils={fossil}},seed)
			for _,entry in ipairs(result.state.affixes) do assert.are.equal(nil,tag(model,entry.id,"defences")) end
		end
		assert.are.equal(false,pcall(sim.perform,raw,{method="fossil",fossils={fossil,fossil}},1))
	end)
	it("guarantees a requested Harvest tag and removes one original affix on augment", function()
		local model=sim.model(raw); local state=rare()
		local result=sim.action(model,state,{method="harvest_reforge",tag="life"},random)
		local found=false; for _,entry in ipairs(result.affixes) do if tag(model,entry.id,"life") then found=true end end
		assert.is_true(found)
		local start={rarity="RARE",affixes={state.affixes[1]},influences={}}
		local augmented=sim.action(model,start,{method="harvest_augment",tag="life"},random)
		assert.are.equal(1,#augmented.affixes)
		assert.is_true(tag(model,augmented.affixes[1].id,"life"))
	end)
	it("fractures a rare affix and continues the returned state through chaos and scour", function()
		local result=sim.perform(raw,{method="fracture"},100,rare())
		local id; for _,entry in ipairs(result.state.affixes) do if entry.fractured then id=entry.id end end
		assert.is_truthy(id)
		local next=sim.perform(raw,{method="chaos"},101,result.state)
		local found=false; for _,entry in ipairs(next.state.affixes) do if entry.id == id and entry.fractured then found=true end end
		assert.is_true(found)
		local scoured=sim.perform(raw,{method="scour"},102,next.state)
		assert.are.equal(1,#scoured.state.affixes)
	end)
	it("adds an influence and one influenced affix without changing the source", function()
		local model=sim.model(raw)
		local input={rarity="RARE",affixes={},influences={}}
		local result=sim.perform(raw,{method="influence_exalt",influence="crusader"},43,input)
		assert.are.equal("crusader",result.state.influences[1])
		assert.are.equal(1,#result.state.affixes)
		assert.is_true(new("Item"):Item(result.itemText).crusader)
		assert.are.equal(0,#input.affixes)
		assert.are.equal(false,pcall(sim.action,model,result.state,{method="influence_exalt",influence="elder"},random))
	end)
	it("presents bounded unveil choices and can keep a selected offered modifier", function()
		local model=sim.model(raw)
		local veiled=sim.perform(raw,{method="veiled_orb"},19,rare())
		assert.is_truthy(veiled.state.veil)
		assert.is_true(#veiled.state.veil.choices >= 1 and #veiled.state.veil.choices <= 3)
		local selected=veiled.state.veil.choices[1]
		local unveiled=sim.perform(raw,{method="unveil",modId=selected},20,veiled.state)
		assert.is_nil(unveiled.state.veil)
		local found=false; for _,entry in ipairs(unveiled.state.affixes) do if entry.id == selected then found=true end end
		assert.is_true(found)
		assert.are.equal(false,pcall(sim.action,model,veiled.state,{method="chaos"},random))
	end)
	it("creates an imprint, applies a Regal Orb and restores the exact magic state", function()
		local magic=sim.perform(raw,{method="transmute"},22)
		local imprint=sim.perform(raw,{method="beast_imprint"},23,magic.state)
		local regaled=sim.perform(raw,{method="regal"},24,imprint.state)
		local restored=sim.perform(raw,{method="restore_imprint"},25,regaled.state)
		assert.are.equal("MAGIC",restored.state.rarity)
		assert.is_true(tableDeepEquals(magic.state.affixes,restored.state.affixes))
		assert.is_nil(restored.state.imprint)
	end)
	it("applies Eldritch dominance to the correct affix side", function()
		local model=sim.model(raw)
		local state=sim.perform(raw,{method="eldritch_implicit",side="Exarch",tier=2},11,rare()).state
		state=sim.perform(raw,{method="eldritch_implicit",side="Eater",tier=1},12,state).state
		assert.are.equal(2,#state.implicits)
		local suffixes={}; for _,entry in ipairs(state.affixes) do if model.byId[entry.id].type == "Suffix" then suffixes[#suffixes+1]=entry.id end end
		local rerolled=sim.perform(raw,{method="eldritch_chaos"},13,state)
		local actual={}; for _,entry in ipairs(rerolled.state.affixes) do if model.byId[entry.id].type == "Suffix" then actual[#actual+1]=entry.id end end
		assert.is_true(tableDeepEquals(suffixes,actual))
		assert.are.equal(2,#rerolled.state.implicits)
	end)
	it("uses white sockets and deterministic links for current bench crafts", function()
		local result=sim.perform(raw,{method="socket_bench",count=4,linked=true},1)
		local item=new("Item"):Item(result.itemText)
		assert.are.equal(4,#item.sockets)
		for _,socket in ipairs(item.sockets) do assert.are.equal("W",socket.color); assert.are.equal(item.sockets[1].group,socket.group) end
		local bound=sim.perform(raw,{method="binding"},2)
		assert.are.equal("RARE",bound.state.rarity)
		assert.are.equal(4,#bound.state.sockets)
	end)
	it("refuses essence use with meta modifiers instead of silently consuming them", function()
		local model=sim.model(raw); local lock
		for _,entry in ipairs(model.bench) do if entry.mod[1] == "Prefixes Cannot Be Changed" then lock=entry.id end end
		local state=sim.action(model,{rarity="RARE",affixes={}},{method="bench",modId=lock},random)
		assert.are.equal(false,pcall(sim.action,model,state,{method="essence",essenceId=model.essences[#model.essences].id},random))
	end)
	it("enumerates next-mod weights and normalizes the full outcome distribution", function()
		local model=sim.model(raw);local targets={}
		for _,entry in ipairs(model.mods) do if tag(model,entry.id,"life") then targets[#targets+1]=entry.id end end
		local state={rarity="RARE",affixes={},influences={}}
		local pool,total=sim.pool(model,state);local wanted=0
		for _,entry in ipairs(pool) do for _,id in ipairs(targets) do if id == entry.id then wanted=wanted+entry.weight end end end
		local result=sim.calculate(raw,{method="exalt"},{{anyOf=targets}},state)
		assert.are.near(wanted/total*100,result.successChance,1e-10)
		local sum=0;for _,entry in ipairs(result.outcomes) do sum=sum+entry.chance end
		assert.are.near(100,sum,1e-8)
	end)
	it("compares all supplied fossil subsets and prices their components", function()
		local model=sim.model(raw);local id
		for _,entry in ipairs(model.mods) do if tag(model,entry.id,"life") then id=entry.id;break end end
		local a,b="Metadata/Items/Currency/CurrencyDelveCraftingLife","Metadata/Items/Currency/CurrencyDelveCraftingDefences"
		local result=sim.optimizeFossils(raw,{{anyOf={id}}},{fossils={a,b},maxSockets=2,trials=10,seed=10,prices={[a]=1,[b]=2,["resonator:1"]=1,["resonator:2"]=2},currency="chaos"})
		assert.are.equal(3,#result.combinations)
		for _,entry in ipairs(result.combinations) do
			assert.is_nil(entry.error)
			assert.are.equal(#entry.fossils == 2 and 5 or entry.fossils[1] == a and 2 or 3,entry.meanCost)
		end
		assert.are.equal(false,pcall(sim.optimizeFossils,raw,{{anyOf={id}}},{fossils={a,b},maxSockets=2,trials=10000}))
	end)
	it("evaluates roll thresholds, exclusions, group counts and open affix conditions", function()
		local model=sim.model(raw);local id=model.mods[1].id
		local state={rarity="RARE",affixes={{id=id,range=0.8}}}
		assert.is_true(sim.matches(state,{{anyOf={id},minRoll=0.75}},nil,model,{openPrefixes=1,openSuffixes=1}))
		assert.are.equal(false,sim.matches(state,{{anyOf={id},minRoll=0.9}},nil,model))
		assert.are.equal(false,sim.matches(state,{{anyOf={id},negate=true}},nil,model))
		assert.is_true(sim.matches(state,{{anyOf={id}},{anyOf={"missing"}}},nil,model,nil,1))
		assert.are.equal(false,sim.matches(state,{{anyOf={id},atLeast=2}},nil,model))
		local recipe={steps={{method="socket_bench",count=4,linked=true}},targets={},requirements={links=4}}
		local result=sim.simulate(raw,recipe,{trials=2,maxActions=1,seed=1})
		assert.are.equal(2,result.successes)
	end)
	it("runs a veiled sequence through a complete recipe without counting an unfinished choice as success", function()
		local model=sim.model(raw);local targets={}
		for _,entry in ipairs(model.veiled) do targets[#targets+1]=entry.id;if #targets == 30 then break end end
		local recipe={steps={{method="alchemy"},{method="veiled_orb"},{method="unveil",preferredMods=targets}},targets={{anyOf=targets}}}
		local result=sim.simulate(raw,recipe,{trials=20,maxActions=3,seed=2})
		assert.is_true(result.successes > 0)
		assert.is_nil(result.sampleState.veil)
		assert.is_nil(result.unpriced.unveil)
	end)
	it("yields background work and cancels it without applying any state", function()
		local tasks=require("Modules.CraftingTasks");tasks.cancel()
		local originalClock=os.clock;local time=0;local done,failed,progress
		os.clock=function() time=time+0.01;return time end
		tasks.start(build,function(checkpoint) checkpoint({trial=1,trials=2});checkpoint({trial=2,trials=2});return "finished" end,function(value) done=value end,function(value) failed=value end,function(value) progress=value end)
		tasks.tick(build);os.clock=originalClock
		assert.is_truthy(tasks.job);assert.is_truthy(progress);assert.is_nil(done)
		tasks.cancel();assert.is_nil(tasks.job);assert.is_truthy(failed)
	end)
	it("edits native recipe routes and keeps a validated bounded loop", function()
		local panel=require("Classes.CraftingRecipeControl");local kept
		local model=sim.model(raw);local id=model.mods[1].id
		local controls=panel.Open({steps={{method="alchemy"}},targets={{anyOf={id}}}},{method="scour"},function(recipe) kept=recipe end)
		controls.add:Click();controls.step.selIndex=1;controls.step.selFunc(1,{val=1})
		controls.attempts:SetText("3");controls.condition:SelByValue("Until final targets and properties match")
		controls.failure:SelByValue(2,"val");controls.success:SelByValue(3,"val");controls.update:Click();controls.keep:Click()
		assert.is_truthy(kept);assert.are.equal(3,kept.steps[1].maxAttempts);assert.are.equal(2,kept.steps[1].onFailure);assert.are.equal(3,kept.steps[1].onSuccess)
		assert.is_truthy(kept.steps[1].untilTargets)
		main.popups={}
	end)
end)
