describe("Crafting result provenance",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local recipe={steps={{method="alchemy"}},targets={},requirements={minAffixes=1}}
	local function assertContext(result)
		assert.are.equal("3_29",result.treeVersion);assert.are.equal("build_context_only",result.treeVersionScope)
		assert.are.equal(latestTreeVersion,result.latestAvailableTreeVersion);assert.are.equal(sim.dataPatch,result.dataPatch)
	end
	it("does not invent a selected tree for standalone simulations",function()
		local result=sim.simulate(raw,recipe,{trials=1,maxActions=1})
		assert.is_nil(result.treeVersion);assert.is_nil(result.treeVersionScope)
		assert.are.equal(latestTreeVersion,result.latestAvailableTreeVersion);assert.are.equal(sim.dataPatch,result.dataPatch)
	end)
	it("keeps build tree context separate from crafting data for each operation",function()
		assertContext(sim.simulate(raw,recipe,{trials=1,maxActions=1,treeVersion="3_29"}))
		assertContext(sim.perform(raw,{method="alchemy"},1,nil,"3_29"))
		assertContext(sim.catalog(raw,"life",1,nil,"3_29"))
		assertContext(sim.calculate(raw,{method="socket_bench",count=2},{},nil,{requirements={sockets=2},treeVersion="3_29"}))
		local fossil="Metadata/Items/Currency/CurrencyDelveCraftingLife"
		assertContext(sim.optimizeFossils(raw,{}, {fossils={fossil},maxSockets=1,trials=1,requirements={minAffixes=1},treeVersion="3_29"}))
		assert.is_false(pcall(sim.withTreeContext,{},"not_a_tree"))
	end)
end)
