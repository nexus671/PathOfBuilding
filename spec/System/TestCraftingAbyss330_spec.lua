describe("3.30 Abyss jewel modifier weights",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nAssembled Eye Jewel\nItem Level: 86"
	it("uses the pinned weights for every affected native modifier without changing shared data",function()
		local file=assert(io.open("Data/Crafting/3.30-abyss-weights.json","rb"));local fixture=assert(require("dkjson").decode(file:read("*a")));file:close()
		local model=sim.model(raw);local count=0
		for id,weights in pairs(fixture.weights) do
			local native=assert(data.itemMods.JewelAbyss[id],id);local mod=assert(model.byId[id],id)
			assert.is_not.equal(native,mod)
			for i,entry in ipairs(weights) do assert.equal(entry.tag,mod.weightKey[i]);assert.equal(entry.weight,mod.weightVal[i]) end
			assert.equal(#weights,#mod.weightKey);count=count+1
		end
		assert.equal(446,count)
		local id="AbyssAccuracyRatingJewel3";assert.equal(0,model.item:GetModSpawnWeight(data.itemMods.JewelAbyss[id]));assert.equal(750,model.item:GetModSpawnWeight(model.byId[id]))
		assert.is_true(#model.mods>100)
	end)
	it("makes the new shared pool available to ordinary crafting and inspection",function()
		local target="AbyssAccuracyRatingJewel3";local original=copyTable(data.itemMods.JewelAbyss[target]);local model=sim.model(raw);local found
		for _,entry in ipairs(model.mods) do if entry.id==target then found=entry end end
		assert.equal(750,assert(found).weight)
		local result=sim.perform(raw,{method="transmute"},42);assert.is_true(#result.state.affixes>0)
		assert.same(original,data.itemMods.JewelAbyss[target])
		local catalog=sim.catalog(raw,"AbyssAccuracyRatingJewel3",10);assert.equal(750,catalog.modifiers[1].weight)
		local ordinary=sim.model("Rarity: NORMAL\nSearching Eye Jewel\nItem Level: 86")
		assert.equal(1000,ordinary.item:GetModSpawnWeight(ordinary.byId[target]))
	end)
	it("keeps legacy removed modifiers on imported jewels but does not roll new copies",function()
		local base="Rarity: NORMAL\nSearching Eye Jewel\nItem Level: 86";local model=sim.model(base)
		local id="AbyssAvoidElementalAilmentsWhileElusiveJewel1"
		assert.is_true(model.legacyAbyss[id]);assert.equal(0,model.item:GetModSpawnWeight(model.byId[id]))
		for _,entry in ipairs(model.mods) do assert.is_not.equal(id,entry.id) end
		local text=sim.toItem(model,{rarity="MAGIC",affixes={{id=id,range=0.5}}}).raw
		local imported=sim.model(text);assert.equal(id,imported.initial.affixes[1].id);assert.matches("15%% chance to Avoid Elemental Ailments while you have Elusive",sim.toItem(imported,imported.initial).raw)
		local plain="Rarity: MAGIC\nSearching Eye Jewel\nItem Level: 86\n15% chance to Avoid Elemental Ailments while you have Elusive"
		local ok,why=pcall(sim.model,plain);assert.is_false(ok);assert.matches("several modifier identities",tostring(why))
		local forged=copyTable(model.initial);forged.rarity="MAGIC";forged.affixes={{id=id,range=0.5}}
		assert.has_error(function() sim.validateState(model,forged) end)
		local divined=sim.perform(text,{method="divine"},3);assert.equal(id,divined.state.affixes[1].id)
		for seed=1,20 do local result=sim.perform(text,{method="alteration"},seed);for _,entry in ipairs(result.state.affixes) do assert.is_not.equal(id,entry.id) end end
	end)
	it("excludes all seven removed modifiers on each ordinary Abyss base",function()
		local removed={"AbyssAvoidElementalAilmentsWhileElusiveJewel1","AbyssBlindedEnemiesCriticalStrikeChanceJewel1","AbyssHinderedEnemiesLifeRegenerationRateJewel1","AbyssIntimidatedEnemiesStunDurationJewel1","AbyssMaimedEnemiesDamageOverTimeJewel1","AbyssSelfCurseEffectOnConsecratedGroundJewel1__","AbyssWitheredEnemiesAllResistanceJewel1___"}
		for _,base in ipairs({"Murderous Eye Jewel","Searching Eye Jewel","Hypnotic Eye Jewel","Ghastly Eye Jewel"}) do
			local model=sim.model("Rarity: NORMAL\n"..base.."\nItem Level: 86");local pool={};for _,entry in ipairs(model.mods) do pool[entry.id]=true end
			for _,id in ipairs(removed) do
				assert.is_true(model.legacyAbyss[id]);assert.is_nil(pool[id]);assert.equal(0,model.item:GetModSpawnWeight(model.byId[id]))
				assert.is_true(data.itemMods.JewelAbyss[id]~=model.byId[id]);assert.is_true(model.item:GetModSpawnWeight(data.itemMods.JewelAbyss[id])>0)
			end
		end
	end)
end)
