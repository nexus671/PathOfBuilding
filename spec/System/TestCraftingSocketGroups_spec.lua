describe("Crafting socket group validation",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86\nSockets: W W W"
	before_each(function() newBuild() end)
	it("rejects separated groups before they can claim a linked-colour goal",function()
		local model=sim.model(raw);local state=copyTable(model.initial)
		state.sockets={{color="R",group=0},{color="G",group=1},{color="B",group=0}}
		assert.has_error(function() sim.validateState(model,state) end,"Linked sockets must form a contiguous group")
		assert.is_false(pcall(sim.calculate,raw,{method="chromatic"},{},state,{requirements={socketColours="RB",linkedColours=true},trials=2}))
	end)
	it("accepts contiguous groups even when their labels are not consecutive",function()
		local model=sim.model(raw);local state=copyTable(model.initial)
		state.sockets={{color="R",group=2},{color="G",group=2},{color="B",group=5}}
		local checked=sim.validateState(model,state);assert.is_true(sim.matches(checked,{},nil,model,{socketColours="RG",linkedColours=true}))
		assert.is_false(sim.matches(checked,{},nil,model,{socketColours="RB",linkedColours=true}))
		local item=new("Item"):Item(sim.toItem(model,checked).raw)
		assert.are.equal(item.sockets[1].group,item.sockets[2].group);assert.are_not.equal(item.sockets[2].group,item.sockets[3].group)
	end)
end)
