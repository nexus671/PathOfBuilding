describe("Socket bench preparation costs",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local numbers="Metadata/Items/Currency/CurrencyRerollSocketNumbers"
	local links="Metadata/Items/Currency/CurrencyRerollSocketLinks"
	local vaal="Metadata/Items/Currency/CurrencyCorrupt"
	it("charges linking alone when the input already has the requested count",function()
		local state=sim.perform(raw,{method="socket_bench",count=6},1).state
		local craft={method="socket_bench",count=6,linked=true}
		assert.are.same({[links]=1500},sim.components(craft,state))
		state.corrupted=true;assert.are.same({[links]=1500,[vaal]=1500},sim.components(craft,state))
		state.sockets[6]=nil
		assert.are.same({[links]=1500,[numbers]=350,[vaal]=1850},sim.components(craft,state))
	end)
	it("prices each successful transition from its input rather than its result",function()
		local recipe={steps={{method="socket_bench",count=6},{method="socket_bench",count=6,linked=true}},targets={},requirements={links=6}}
		local result=sim.simulate(raw,recipe,{trials=10,maxActions=2,prices={[numbers]=1,[links]=1},currency="units"})
		assert.are.equal(10,result.successes);assert.are.equal(3500,result.currencySpent[numbers]);assert.are.equal(15000,result.currencySpent[links])
		assert.are.equal(1850,result.meanCost)
		local state=sim.perform(raw,{method="socket_bench",count=6},1).state
		recipe.steps={recipe.steps[2]};recipe.initialState=state
		result=sim.simulate(raw,recipe,{trials=10,maxActions=1,prices={[numbers]=1,[links]=1},currency="units"})
		assert.is_nil(result.currencySpent[numbers]);assert.are.equal(1500,result.meanCost)
	end)
end)
