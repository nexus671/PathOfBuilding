describe("3.30 cluster jewel speed families",function()
	local sim=require("Modules.CraftingSimulator")
	local attack="AfflictionJewelSmallPassivesGrantAttackSpeed"
	local cast="AfflictionJewelSmallPassivesGrantCastSpeed"
	local raw="Rarity: NORMAL\nLarge Cluster Jewel\nItem Level: 86\nCluster Jewel Skill: affliction_axe_and_sword_damage\nCluster Jewel Node Count: 8\nImplicits: 3\n{crafted}Adds 8 Passive Skills\n{crafted}2 Added Passive Skills are Jewel Sockets\n{crafted}Added Small Passive Skills grant: 12% increased Axe and Sword Damage"
	before_each(function() newBuild() end)
	it("matches the complete speed family in the 3.30 client export",function()
		local expected=dofile("../spec/System/Fixtures/ClusterSpeed330.lua")
		local model=sim.model(raw)
		for id in pairs(expected) do
			assert.is_not_nil(model.byId[id],id)
			assert.is_true(sim.isClusterSpeedMod(model,id),id)
		end
		for id in pairs(model.byId) do
			if sim.isClusterSpeedMod(model,id) then assert.is_true(expected[id] or false,id) end
		end
	end)
	local function legacy()
		local base=sim.model(raw)
		local state={rarity="RARE",affixes={{id=attack,range=0.5},{id=cast,range=0.5}}}
		return sim.model(sim.toItem(base,state).raw)
	end
	it("recognizes speed modifiers and rejects newly created family conflicts",function()
		local model=sim.model(raw);assert.is_true(sim.isClusterSpeedMod(model,attack));assert.is_true(sim.isClusterSpeedMod(model,cast))
		assert.is_true(sim.isClusterSpeedMod(model,"AfflictionJewelSmallPassivesGrantMinionAttackAndCastSpeed"))
		assert.is_true(sim.isClusterSpeedMod(model,"AfflictionJewelSmallPassivesGrantFireSkillAttackAndCastSpeed"))
		assert.is_false(sim.isClusterSpeedMod(model,"AfflictionJewelSmallPassivesGrantLife_") or false)
		assert.matches("share a family",table.concat(require("Modules.CraftingInspection").modDetails(model,attack)," "))
		local invalid={rarity="RARE",affixes={{id=attack,range=0.5},{id=cast,range=0.5}}}
		assert.has_error(function() sim.validateState(model,invalid) end,"State has conflicting modifier groups")
	end)
	it("retains existing legacy combinations without allowing new speed rolls",function()
		local model=legacy();assert.equal(2,#model.initial.affixes);assert.is_truthy(sim.validateState(model,model.initial))
		local retained=copyTable(model.initial);retained.affixes={{id=cast,range=0.5}};retained=sim.validateState(model,retained)
		local empty=copyTable(retained);empty.affixes={};local before,after=sim.pool(model,empty),sim.pool(model,retained)
		local function has(pool,id) for _,entry in ipairs(pool) do if entry.id==id then return true end end;return false end
		assert.is_true(has(before,attack));assert.is_false(has(after,attack))
		local rows=require("Modules.CraftingModifiers").inspect(model,retained).rows;local found=false
		for _,row in ipairs(rows) do if row.id==attack then found=true;assert.is_false(row.eligible);assert.matches("Conflicts with",table.concat(row.reasons," ")) end end
		assert.is_true(found)
		local catalog=sim.catalog(model.raw,attack,20,retained);assert.equal(sim.clusterSpeedGroup,catalog.modifiers[1].group)
		local targets={{anyOf={attack}}};local odds=sim.calculate(model.raw,{method="exalt"},targets,retained)
		assert.equal(0,odds.successChance)
		local sampled=sim.simulate(model.raw,{steps={{method="exalt"}},targets=targets,initialState=retained},{trials=10,maxActions=1})
		assert.equal(0,sampled.successes)
		local extra=copyTable(model.initial);extra.affixes[#extra.affixes+1]={id="AfflictionJewelSmallPassivesGrantFireSkillAttackAndCastSpeed",range=0.5}
		assert.has_error(function() sim.validateState(model,extra) end,"State has conflicting modifier groups")
	end)
end)
