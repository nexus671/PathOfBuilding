describe("3.30 full meta-craft costs",function()
	local sim=require("Modules.CraftingSimulator")
	local bench=require("Modules.CraftingBenchCosts")
	local divine="Metadata/Items/Currency/CurrencyModValues"
	local sacred="Metadata/Items/Currency/CurrencyRerollDefences"
	local blessed="Metadata/Items/Currency/CurrencyRerollImplicit"
	local exalt="Metadata/Items/Currency/CurrencyAddModToRare"
	local function raw(base) return "Rarity: NORMAL\n"..base.."\nItem Level: 86" end
	it("uses both documented currencies for each supported item class and lock",function()
		for _,case in ipairs({{"Rusted Sword",sacred,1},{"Crude Bow",sacred,1},{"Plate Vest",blessed,4},{"Goathide Buckler",blessed,4},{"Cured Quiver",blessed,4},{"Iron Ring",exalt,8},{"Gold Amulet",exalt,8},{"Leather Belt",exalt,8}}) do
			local model=sim.model(raw(case[1]));local found=0
			for _,entry in ipairs(model.bench) do if entry.mod[1]=="Prefixes Cannot Be Changed" or entry.mod[1]=="Suffixes Cannot Be Changed" then
				local cost,sources=bench.cost(model,entry.id);assert.are.same({[divine]=4,[case[2]]=case[3]},cost)
				assert.are.same({"GGG 3.30 patch notes"},sources);assert.are.same(cost,sim.components({method="bench",modId=entry.id},model.initial,model));found=found+1
			end end
			assert.are.equal(2,found,case[1])
		end
	end)
	it("uses the updated ingredients in estimates, provenance and resource quotes",function()
		local text=raw("Plate Vest");local model=sim.model(text);local action={method="bench",modId="bench:728"}
		local prefix;for _,entry in ipairs(model.mods) do if entry.mod.type=="Prefix" then prefix=entry.id;break end end;assert.is_truthy(prefix)
		local initial=sim.validateState(model,{rarity="RARE",affixes={{id=prefix,range=0.5}}})
		local recipe={initialState=initial,steps={action},targets={},requirements={minAffixes=2}}
		local result=sim.simulate(text,recipe,{trials=2,maxActions=1,prices={[divine]=10,[blessed]=2},currency="chaos"})
		assert.are.equal(2,result.successes);assert.are.equal(48,result.meanCost);assert.are.equal(8,result.currencySpent[divine]);assert.are.equal(8,result.currencySpent[blessed])
		local missing=sim.simulate(text,recipe,{trials=1,maxActions=1,prices={[divine]=10},currency="chaos"})
		assert.is_true(missing.unpriced[blessed]);assert.is_nil(missing.meanCost)
		local entries=require("Modules.CraftingPrices").entries(model,initial,{action});local required={};for _,entry in ipairs(entries) do if entry.required then required[entry.key]=true end end
		assert.is_true(required[divine]);assert.is_true(required[blessed]);assert.is_nil(required[action.modId])
		local catalog=sim.catalog(text,"Prefixes Cannot Be Changed",10);local found
		for _,entry in ipairs(catalog.bench) do if entry.id==action.modId then found=entry end end
		assert.is_true(found.ingredientCostsKnown);assert.are.same({[divine]=4,[blessed]=4},found.components);assert.are.same({"GGG 3.30 patch notes"},found.costSources)
		assert.are.equal("3.30",catalog.benchCostOverlays[1].patch)
	end)
end)
