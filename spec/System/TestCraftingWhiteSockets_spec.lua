describe("3.30 white socket bench craft",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86\nQuality: 20\nSockets: R-G B W-W R"
	local action={method="socket_white_bench"}
	local scour="Metadata/Items/Currency/CurrencyConvertToNormal"
	local vaal="Metadata/Items/Currency/CurrencyCorrupt"
	it("changes only socket colours, keeps links and supports corrupted items",function()
		local model=sim.model(raw)
		for _,corrupted in ipairs({false,true}) do
			local before=copyTable(model.initial);before.corrupted=corrupted
			assert.is_true(check(action.method,before,model))
			local result=sim.perform(raw,action,1,before);local expected=copyTable(before)
			for _,socket in ipairs(expected.sockets) do socket.color="W" end
			assert.are.same(expected,result.state);assert.are.same(result.state.sockets,new("Item"):Item(result.itemText).sockets)
			assert.are.same(corrupted and {[scour]=1,[vaal]=1} or {[scour]=1},sim.components(action,before,model))
		end
	end)
	it("rejects unsupported inputs before consuming randomness",function()
		local model=sim.model(raw);local variants={}
		for _,change in ipairs({{key="sockets",value={}},{key="mirrored",value=true},{key="destroyed",value=true}}) do local state=copyTable(model.initial);state[change.key]=change.value;variants[#variants+1]=state end
		local abyss=copyTable(model.initial);abyss.sockets[1].color="A";variants[#variants+1]=abyss
		for _,state in ipairs(variants) do
			assert.is_false(check(action.method,state,model));local draws=0
			assert.is_false(pcall(sim.action,model,state,action,function() draws=draws+1;return 0.5 end));assert.are.equal(0,draws)
		end
	end)
	it("provides an exact result and accounts for both resources in a saved recipe",function()
		local model=sim.model(raw);local state=copyTable(model.initial);state.corrupted=true
		local catalog=sim.catalog(raw,"white sockets",10,state);assert.are.equal(action.method,catalog.socketCrafts[1].method)
		assert.is_true(catalog.socketCrafts[1].deterministic);assert.are.same({[scour]=1,[vaal]=1},catalog.socketCrafts[1].components)
		local requirements={socketColours="WWWWWW"};local calculated=sim.calculate(raw,action,{},state,{requirements=requirements})
		assert.is_false(calculated.sampled);assert.are.equal(100,calculated.successChance);assert.is_nil(calculated.confidenceLow)
		local recipe={initialState=state,steps={action},targets={},requirements=requirements}
		local result=sim.simulate(raw,recipe,{trials=2,maxActions=1,prices={[scour]=2,[vaal]=3},currency="chaos"})
		assert.are.equal(2,result.successes);assert.are.equal(5,result.meanCost);assert.are.equal(2,result.currencySpent[scour]);assert.are.equal(2,result.currencySpent[vaal])
	end)
end)
