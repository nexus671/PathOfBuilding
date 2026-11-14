describe("Harvest cluster-jewel resistance conversions",function()
	local sim=require("Modules.CraftingSimulator")
	local large={fire={"AfflictionJewelSmallPassivesGrantFireRes","AfflictionJewelSmallPassivesGrantFireRes2","AfflictionJewelSmallPassivesGrantFireRes3"},
		cold={"AfflictionJewelSmallPassivesGrantColdRes_","AfflictionJewelSmallPassivesGrantColdRes2","AfflictionJewelSmallPassivesGrantColdRes3"},
		lightning={"AfflictionJewelSmallPassivesGrantLightningRes","AfflictionJewelSmallPassivesGrantLightningRes2_","AfflictionJewelSmallPassivesGrantLightningRes3"}}
	local small={fire={"AfflictionJewelSmallPassivesGrantFireResSmall","AfflictionJewelSmallPassivesGrantFireResSmall2","AfflictionJewelSmallPassivesGrantFireResSmall3_","AfflictionJewelSmallPassivesGrantFireResSmall4","AfflictionJewelSmallPassivesGrantFireResSmall5"},
		cold={"AfflictionJewelSmallPassivesGrantColdResSmall","AfflictionJewelSmallPassivesGrantColdResSmall2","AfflictionJewelSmallPassivesGrantColdResSmall3","AfflictionJewelSmallPassivesGrantColdResSmall4","AfflictionJewelSmallPassivesGrantColdResSmall5_"},
		lightning={"AfflictionJewelSmallPassivesGrantLightningResSmall","AfflictionJewelSmallPassivesGrantLightningResSmall2__","AfflictionJewelSmallPassivesGrantLightningResSmall3","AfflictionJewelSmallPassivesGrantLightningResSmall4_","AfflictionJewelSmallPassivesGrantLightningResSmall5"}}
	local function raw(base,count,skill,enchant)
		return "Rarity: NORMAL\n"..base.."\nItem Level: 86\nCluster Jewel Skill: "..skill.."\nCluster Jewel Node Count: "..count.."\nImplicits: 2\n{crafted}Adds "..count.." Passive Skills\n{crafted}"..enchant
	end
	local cases={
		{raw("Large Cluster Jewel",8,"affliction_axe_and_sword_damage","Added Small Passive Skills grant: 12% increased Axe and Sword Damage"),large},
		{raw("Medium Cluster Jewel",4,"affliction_fire_damage_over_time_multiplier","Added Small Passive Skills grant: 12% increased Burning Damage"),large},
		{raw("Small Cluster Jewel",2,"affliction_maximum_life","Added Small Passive Skills grant: 4% increased maximum Life"),small},
	}
	it("uses matching destination size and tier for all three elements",function()
		for _,case in ipairs(cases) do
			local model=sim.model(case[1]);local ids=case[2]
			for from,tiers in pairs(ids) do for tier,id in ipairs(tiers) do for to,destinations in pairs(ids) do if from~=to then
				local state=copyTable(model.initial);state.rarity="MAGIC";state.affixes={{id=id,range=0.5}};state=sim.validateState(model,state)
				assert.is_nil(sim.resistanceReason(model,state,from,to),id.." to "..to)
				local result=sim.action(model,state,{method="harvest_resistance",from=from,to=to},function() return 0.5 end)
				assert.equal(destinations[tier],result.affixes[1].id)
			end end end end
		end
	end)
	it("prevents conflicts and preserves the cluster enchant in a rendered result",function()
		local model=sim.model(cases[1][1]);local state=copyTable(model.initial)
		state.rarity="MAGIC";state.affixes={{id=large.fire[2],range=0.5}}
		local result=sim.perform(model.raw,{method="harvest_resistance",from="fire",to="cold"},17,state)
		assert.equal(large.cold[2],result.state.affixes[1].id)
		assert.matches("Added Small Passive Skills grant: 12%% increased Axe and Sword Damage",result.itemText)
		local conflict=copyTable(state);conflict.rarity="RARE";conflict.affixes[2]={id=large.cold[1],range=0.5}
		assert.matches("already present",sim.resistanceReason(model,conflict,"fire","cold"))
		state.affixes[1].fractured=true;assert.matches("No ",sim.resistanceReason(model,state,"fire","cold"))
	end)
end)
