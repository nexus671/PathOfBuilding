describe("Guaranteed socket crafts",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86\nQuality: 20\nSockets: R-G B W-W R"
	local omen="Metadata/Items/Currency/AncestralOmenOnFusingMakeFullLinks"
	local fusing="Metadata/Items/Currency/CurrencyRerollSocketLinks"
	it("links every existing socket while preserving colours and item properties",function()
		local m=sim.model(raw);local before=copyTable(m.initial)
		local result=sim.perform(raw,{method="omen_connections"},1)
		assert.is_true(check("omen_connections",m.initial,m));assert.are.equal(6,#result.state.sockets)
		for i,socket in ipairs(result.state.sockets) do assert.are.equal(0,socket.group);assert.are.equal(before.sockets[i].color,socket.color) end
		local expected=copyTable(before);for _,socket in ipairs(expected.sockets) do socket.group=0 end
		assert.are.same(expected,result.state);assert.are.same(before,m.initial)
		local imported=new("Item"):Item(result.itemText);assert.are.same(result.state.sockets,imported.sockets)
		assert.are.same(result.state,sim.perform(raw,{method="omen_connections"},999).state)
	end)
	it("rejects unusable items and fully linked groups without spending randomness",function()
		local m=sim.model(raw);local variants={}
		local function variant(key,value) local state=copyTable(m.initial);state[key]=value;variants[#variants+1]=state end
		variant("sockets",{});variant("sockets",{{color="W",group=0}})
		variant("sockets",{{color="W",group=0},{color="W",group=0}})
		variant("sockets",{{color="A",group=0},{color="W",group=1}})
		variant("corrupted",true);variant("mirrored",true)
		for _,state in ipairs(variants) do
			assert.is_false(check("omen_connections",state,m));local calls=0
			assert.is_false(pcall(sim.action,m,state,{method="omen_connections"},function() calls=calls+1;return 0.5 end));assert.are.equal(0,calls)
		end
	end)
	it("charges the Omen and Fusing once for each completed recipe",function()
		local action={method="omen_connections"};assert.are.same({[omen]=1,[fusing]=1},sim.components(action))
		local catalog=sim.catalog(raw,"connections",5);assert.are.equal(1,#catalog.socketCrafts)
		local choice=catalog.socketCrafts[1];assert.is_true(choice.available);assert.is_true(choice.deterministic)
		assert.are.same(action,choice.action);assert.are.same(sim.components(action),choice.components)
		local linked=sim.perform(raw,action,1).state;choice=sim.catalog(raw,"connections",5,linked).socketCrafts[1]
		assert.is_false(choice.available);assert.is_truthy(choice.unavailableReason)
		assert.are.equal(0,#sim.catalog(raw,"connections",0).socketCrafts)
		local recipe={steps={action},targets={},requirements={links=6}}
		local result=sim.simulate(raw,recipe,{trials=5,maxActions=1,prices={[omen]=2,[fusing]=0.25},currency="chaos"})
		assert.are.equal(5,result.successes);assert.are.equal(2.25,result.meanCost)
		assert.are.equal(5,result.currencySpent[omen]);assert.are.equal(5,result.currencySpent[fusing]);assert.is_nil(next(result.transitionErrors))
		local missing=sim.simulate(raw,recipe,{trials=1,maxActions=1,prices={[omen]=2},currency="chaos"})
		assert.is_true(missing.unpriced[fusing]);assert.is_nil(missing.meanCost)
	end)
	it("calculates deterministic socket outcomes without a sampled confidence interval",function()
		local action={method="omen_connections"};local result=sim.calculate(raw,action,{},nil,{requirements={links=6},trials=2000})
		assert.is_false(result.sampled);assert.are.equal(100,result.successChance);assert.is_nil(result.confidenceLow);assert.are.equal(1,#result.outcomes)
		assert.are.equal(100,result.outcomes[1].chance);assert.is_true(result.outcomes[1].matches)
		local changed=sim.calculate(raw,{method="socket_bench",count=4,linked=true},{},nil,{requirements={links=6}})
		assert.are.equal(0,changed.successChance);assert.is_false(changed.outcomes[1].matches)
		assert.are.equal(4,#changed.sampleState.sockets)
		assert.is_false(pcall(sim.calculate,raw,action,{},result.sampleState,{requirements={links=6}}))
		local m=sim.model(raw);local again=sim.calculate(raw,action,{},m.initial,{requirements={links=6}})
		assert.are.equal(6,#m.initial.sockets);assert.are.same(result.sampleState,again.sampleState)
	end)
end)
