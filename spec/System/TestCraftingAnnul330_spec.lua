describe("3.30 Orb of Annulment",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nDriftwood Wand\nItem Level: 86"
	local pairs={{"LocalAddedChaosDamage1","bench:731"},{"GlobalChaosSpellGemsLevel1","bench:732"}}
	it("can remove attack or caster modifiers despite their roll blocker",function()
		for _,pair in ipairs(pairs) do
			local initial={rarity="RARE",affixes={{id=pair[1],range=0.5},{id=pair[2],range=0.5,crafted=true}}}
			local state=sim.validateState(sim.model(raw),initial);local before=copyTable(state)
			local removed=sim.perform(raw,{method="annul"},1,state)
			assert.are.equal(1,#removed.state.affixes);assert.are.equal(pair[2],removed.state.affixes[1].id)
			local other=sim.perform(raw,{method="annul"},42,state)
			assert.are.equal(pair[1],other.state.affixes[1].id);assert.are.same(before,state)
		end
	end)
	it("continues to protect fractured modifiers and locked prefixes",function()
		local model=sim.model(raw)
		for _,entry in ipairs({{id="LocalAddedChaosDamage1",range=0.5,fractured=true},{id="LocalAddedChaosDamage1",range=0.5}}) do
			local lock=entry.fractured and "bench:731" or "bench:728"
			local state=sim.validateState(model,{rarity="RARE",affixes={entry,{id=lock,range=0.5,crafted=true}}})
			local result=sim.perform(raw,{method="annul"},1,state)
			assert.are.equal(1,#result.state.affixes);assert.are.equal(entry.id,result.state.affixes[1].id)
		end
	end)
	it("enumerates Annulment outcomes with blockers and fractures",function()
		local target="LocalAddedChaosDamage1"
		local state={rarity="RARE",affixes={{id=target,range=0.5},{id="bench:731",range=0.5,crafted=true}}}
		local before=copyTable(state)
		local result=sim.calculate(raw,{method="annul"},{{anyOf={target}}},state)
		assert.is_false(result.sampled);assert.are.equal(50,result.successChance);assert.are.equal(2,#result.outcomes);assert.are.same(before,state)
		assert.are.equal(50,result.outcomes[1].chance);assert.are.equal(50,result.outcomes[2].chance)
		state.affixes[1].fractured=true
		result=sim.calculate(raw,{method="annul"},{{anyOf={target},fractured=true}},state,{requirements={minFractured=1}})
		assert.are.equal(100,result.successChance);assert.are.equal(1,#result.outcomes)
		state.affixes[1].fractured=false;state.affixes[2].id="bench:728"
		result=sim.calculate(raw,{method="annul"},{{anyOf={target}}},state)
		assert.are.equal(100,result.successChance);assert.are.equal(1,#result.outcomes)
		state.affixes[1].fractured=true;table.remove(state.affixes,2)
		assert.is_false(pcall(sim.calculate,raw,{method="annul"},{},state))
	end)
end)
