describe("Native crafting simulator", function()
	local simulator=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local function countTypes(model,state)
		local prefixes,suffixes=0,0
		local groups={ }
		for _,entry in ipairs(state.affixes) do
			local mod=model.byId[entry.id]
			if mod.type == "Prefix" then prefixes=prefixes+1 else suffixes=suffixes+1 end
			assert.is_nil(groups[mod.group]); groups[mod.group]=true
		end
		return prefixes,suffixes
	end
	local function lifeTargets(model)
		local ids={ }
		for _,entry in ipairs(model.mods) do if entry.mod.group == "IncreasedLife" then ids[#ids+1]=entry.id end end
		assert.is_true(#ids > 0)
		return {{anyOf=ids}}
	end

	it("rolls reproducible magic and rare items within affix and group limits", function()
		local model=simulator.model(raw)
		local magic=simulator.perform(raw,{method="transmute"},123)
		assert.are.equal("MAGIC",magic.state.rarity)
		local prefixes,suffixes=countTypes(model,magic.state)
		assert.is_true(prefixes <= 1 and suffixes <= 1 and prefixes+suffixes >= 1)
		local rare=simulator.perform(raw,{method="alchemy"},123)
		prefixes,suffixes=countTypes(model,rare.state)
		assert.is_true(prefixes <= 3 and suffixes <= 3 and prefixes+suffixes >= 4 and prefixes+suffixes <= 6)
		assert.are.equal(rare.itemText,simulator.perform(raw,{method="alchemy"},123).itemText)
		assert.are.equal(0,#model.initial.affixes)
	end)

	it("round trips generated modifier identities through native item text", function()
		local result=simulator.perform(raw,{method="alchemy"},456)
		local loaded=simulator.model(result.itemText)
		assert.are.equal(#result.state.affixes,#loaded.initial.affixes)
		local found={ }
		for _,entry in ipairs(loaded.initial.affixes) do found[entry.id]=true end
		for _,entry in ipairs(result.state.affixes) do assert.is_true(found[entry.id]) end
	end)

	it("rejects incompatible rarity, unresolved imports and unsupported methods", function()
		assert.are.equal(false,pcall(simulator.perform,raw,{method="chaos"},1))
		assert.are.equal(false,pcall(simulator.perform,raw,{method="harvest"},1))
		assert.are.equal(false,pcall(simulator.model,"Rarity: RARE\nUnresolved Hat\nIron Hat\nItem Level: 86\n+100 to maximum Life"))
		assert.are.equal(false,pcall(simulator.model,"Rarity: NORMAL\nIron Hat"))
	end)

	it("guarantees the selected essence modifier and obeys remaining affix limits", function()
		local model=simulator.model(raw)
		local selected
		for _,entry in ipairs(model.essences) do if entry.name == "Deafening Essence of Greed" then selected=entry end end
		assert.is_truthy(selected)
		local result=simulator.perform(raw,{method="essence",essenceId=selected.id},321)
		local found=false
		for _,entry in ipairs(result.state.affixes) do if entry.id == selected.modId then found=true end end
		assert.is_true(found)
		countTypes(model,result.state)
	end)

	it("respects crafted modifier limits and allows explicit bench removal", function()
		local model=simulator.model(raw)
		local selected
		for _,entry in ipairs(model.bench) do if entry.mod[1]:find("maximum Life",1,true) then selected=entry; break end end
		assert.is_truthy(selected)
		local state=simulator.action(model,model.initial,{method="bench",modId=selected.id},function() return 0.5 end)
		assert.are.equal("MAGIC",state.rarity)
		assert.is_true(state.affixes[1].crafted)
		assert.are.equal(false,pcall(simulator.action,model,state,{method="bench",modId=selected.id},function() return 0.5 end))
		state=simulator.action(model,state,{method="remove_crafted"},function() return 0.5 end)
		assert.are.equal(0,#state.affixes)
	end)

	it("measures bounded outcomes with confidence intervals and complete cost accounting", function()
		local targets=lifeTargets(simulator.model(raw))
		local recipe={steps={{method="alchemy"}},targets=targets}
		local result=simulator.simulate(raw,recipe,{trials=200,maxActions=1,seed=123,prices={alchemy=2},currency="chaos"})
		assert.is_true(result.successes > 0 and result.successes < 200)
		assert.is_true(result.confidenceLow < result.successChance and result.confidenceHigh > result.successChance)
		assert.are.equal(2,result.meanCost)
		assert.are.equal(200,result.currencySpent.alchemy)
		assert.are.near(400/result.successes,result.costPerSuccess,0.00001)
		assert.are.equal("chaos",result.costCurrency)
		local repeated=simulator.simulate(raw,recipe,{trials=200,maxActions=1,seed=123})
		assert.are.equal(result.successes,repeated.successes)
		assert.is_nil(repeated.meanCost)
		assert.is_true(repeated.unpriced.alchemy)
	end)

	it("bounds failed loops and rejects excessive workloads instead of hanging", function()
		local targets=lifeTargets(simulator.model(raw))
		assert.are.equal(false,pcall(simulator.simulate,raw,{steps={{method="chaos",onFailure=1}},targets=targets},{trials=2,maxActions=3}))
		assert.are.equal(false,pcall(simulator.simulate,raw,{steps={{method="alchemy"}},targets=targets},{trials=2000,maxActions=2000}))
	end)

	it("preserves fractured modifiers through rerolls, annulment and scouring", function()
		local model=simulator.model(raw)
		local id=lifeTargets(model)[1].anyOf[1]
		local item=new("Item"):Item("Rarity: RARE\nFractured Hat\nIron Hat\nItem Level: 86\nCrafted: true\nPrefix: {fractured}"..id)
		item:Craft()
		model=simulator.model(item.raw)
		local result=simulator.perform(item.raw,{method="chaos"},42)
		local found=false
		for _,entry in ipairs(result.state.affixes) do if entry.id == id then found=entry.fractured end end
		assert.is_true(found)
		assert.are.equal(false,pcall(simulator.action,model,model.initial,{method="annul"},function() return 0.5 end))
		local scoured=simulator.action(model,model.initial,{method="scour"},function() return 0.5 end)
		assert.are.equal(1,#scoured.affixes)
		assert.is_true(scoured.affixes[1].fractured)
	end)

	it("honors prefix locks and attack blocking while consuming rerolled metamods", function()
		local model=simulator.model(raw)
		local id=lifeTargets(model)[1].anyOf[1]
		local prefixLock,noAttack
		for _,entry in ipairs(model.bench) do
			if entry.mod[1] == "Prefixes Cannot Be Changed" then prefixLock=entry.id end
			if entry.mod[1] == "Cannot roll Attack Modifiers" then noAttack=entry.id end
		end
		assert.is_truthy(prefixLock); assert.is_truthy(noAttack)
		local state={rarity="RARE",affixes={{id=id,range=0.5}}}
		local locked=simulator.action(model,state,{method="bench",modId=prefixLock},function() return 0.5 end)
		local scoured=simulator.action(model,locked,{method="scour"},function() return 0.5 end)
		assert.are.equal(id,scoured.affixes[1].id)
		assert.are.equal(1,#scoured.affixes)
		local blocked=simulator.action(model,state,{method="bench",modId=noAttack},function() return 0.5 end)
		local rerolled=simulator.action(model,blocked,{method="chaos"},function() return 0.5 end)
		for _,entry in ipairs(rerolled.affixes) do
			assert.are_not.equals(noAttack,entry.id)
			for _,tag in ipairs(model.byId[entry.id].modTags or {}) do assert.are_not.equals("attack",tag) end
		end
	end)

	it("samples a known one-to-three weighted pool without uniform selection bias", function()
		local model=simulator.model(raw)
		local a,b
		for _,entry in ipairs(model.mods) do if entry.mod.type == "Suffix" then if not a then a=entry elseif entry.mod.group ~= a.mod.group then b=entry; break end end end
		assert.is_truthy(a); assert.is_truthy(b)
		model.mods={{id=a.id,mod=a.mod,weight=1},{id=b.id,mod=b.mod,weight=3}}
		local value,selected=12345,0
		local function random() value=value*16807%2147483647; return value/2147483647 end
		for _=1,4000 do
			local state=simulator.action(model,{rarity="MAGIC",affixes={}},{method="augmentation"},random)
			if state.affixes[1].id == b.id then selected=selected+1 end
		end
		assert.is_true(selected > 2800 and selected < 3200)
	end)

	it("runs multi-step recipes and enforces a final rarity requirement", function()
		local targets=lifeTargets(simulator.model(raw))
		local result=simulator.simulate(raw,{steps={{method="transmute"},{method="regal"},{method="exalt"}},targets=targets,rarity="RARE"},{trials=100,maxActions=3,seed=876})
		assert.are.equal(100,result.currencySpent.transmute)
		assert.are.equal(100,result.currencySpent.regal)
		assert.are.equal("RARE",result.sampleState.rarity)
	end)
end)
