describe("Omen of the Jeweller",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86\nSockets: R-G B"
	local action={method="omen_jeweller"}
	local omen="Metadata/Items/Currency/AncestralOmenOnJewellersMakeFullSockets"
	local jeweller="Metadata/Items/Currency/CurrencyRerollSocketNumbers"
	it("adds white unlinked sockets, retaining existing colours and links",function()
		local before=sim.model(raw).initial;local result=sim.perform(raw,action,1)
		assert.equal(6,#result.state.sockets)
		for i=1,3 do assert.same(before.sockets[i],result.state.sockets[i]) end
		for i=4,6 do assert.equal("W",result.state.sockets[i].color);assert.is_not.equal(result.state.sockets[i-1].group,result.state.sockets[i].group) end
		assert.same(result.state.sockets,new("Item"):Item(result.itemText).sockets)
		assert.same(before,sim.model(raw).initial)
	end)
	it("respects both item level and base limits",function()
		for _,case in ipairs({{1,2},{2,3},{25,4},{35,5},{50,6}}) do
			local text=raw:gsub("Item Level: 86","Item Level: "..case[1]):gsub("Sockets: R%-G B","Sockets: R")
			assert.equal(case[2],#sim.perform(text,action,1).state.sockets)
		end
		local helmet="Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: R"
		assert.equal(4,#sim.perform(helmet,action,1).state.sockets)
	end)
	it("rejects ineligible items and preserves existing bench-crafted extra sockets",function()
		local model=sim.model(raw);local invalid={}
		for _,field in ipairs({"corrupted","mirrored","destroyed"}) do local s=copyTable(model.initial);s[field]=true;invalid[#invalid+1]=s end
		local abyss=copyTable(model.initial);abyss.sockets[1].color="A";invalid[#invalid+1]=abyss
		local full=copyTable(model.initial);for i=4,6 do full.sockets[i]={color="W",group=i} end;invalid[#invalid+1]=full
		for _,state in ipairs(invalid) do assert.is_false(check(action.method,state,model));assert.has_error(function() sim.action(model,state,action,function() return 0 end) end) end
		local low=sim.model(raw:gsub("Item Level: 86","Item Level: 1"));assert.is_false(check(action.method,low.initial,low))
	end)
	it("offers an exact planner action with both ingredient costs",function()
		assert.same({[omen]=1,[jeweller]=1},sim.components(action))
		local entry=sim.catalog(raw,"omen of the jeweller",10).socketCrafts[1]
		assert.is_true(entry.available);assert.is_true(entry.deterministic);assert.same(action,entry.action)
		assert.equal("Sockets",require("Modules.CraftingInspection").category(action.method))
		assert.is_truthy(require("Modules.CraftingWorkbench").icon(action.method))
		local result=sim.calculate(raw,action,{},nil,{requirements={sockets=6}})
		assert.is_false(result.sampled);assert.equal(100,result.successChance)
		local recipe={steps={action},targets={},requirements={sockets=6}}
		local sampled=sim.simulate(raw,recipe,{trials=3,maxActions=1,prices={[omen]=2,[jeweller]=0.25},currency="chaos"})
		assert.equal(3,sampled.successes);assert.equal(2.25,sampled.meanCost)
	end)
end)
