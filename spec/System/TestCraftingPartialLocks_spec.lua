describe("3.30 partial affix locks",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local id="bench:partial-prefix-1"
	before_each(function() newBuild() end)
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
		assert.is_true(result.sampled);assert.is_true(result.successChance>68 and result.successChance<82,"Observed chance: "..result.successChance)
		assert.are.equal("partial_lock_model",result.warnings[1].code)
		local project={id="partial-lock",title="Partial lock guide",slot="Body Armour",startingItem=sim.toItem(model,state).raw,goals={},steps={},nativeRecipe={steps={{method="bench",modId=id},{method="annul"}},targets={{anyOf={prefixes[1]}}}}}
		local store=build.savers.CraftingProjects;store:Upsert(project);local xml={};store:Save(xml)
		local restored=require("Modules.CraftingProjects").new(build);restored:Load(xml)
		assert.is_nil(restored.warning);assert.are.equal(id,restored.projects[1].nativeRecipe.steps[1].modId)
		local replay=sim.simulate(restored.projects[1].startingItem,restored.projects[1].nativeRecipe,{trials=20,maxActions=2,forceFirstAction=true})
		assert.are.equal("partial_lock_model",replay.warnings[1].code)
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
		end
	end)
end)
