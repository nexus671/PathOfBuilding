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
	it("keeps every socket partition valid through tainted socket and link changes",function()
		local model=sim.model(raw:gsub("W W W","W W W W W W"));local exercised=0
		for count=1,6 do for mask=0,2^(count-1)-1 do
			local state=copyTable(model.initial);state.corrupted=true;state.sockets={};local group=0
			for i=1,count do
				if i>1 and math.floor(mask/2^(i-2))%2==1 then group=group+1 end
				state.sockets[i]={color="W",group=group}
			end
			for _,method in ipairs({"tainted_jeweller","tainted_fusing"}) do for _,draw in ipairs({0.1,0.9}) do
				local ok,result=pcall(sim.action,model,state,{method=method},function() return draw end)
				if method=="tainted_fusing" and (count==1 or group==0) then assert.is_false(ok)
				else
					assert.is_true(ok);result=sim.validateState(model,result);local item=new("Item"):Item(sim.toItem(model,result).raw)
					assert.are.equal(#result.sockets,#item.sockets)
					for i=2,#result.sockets do assert.are.equal(result.sockets[i].group==result.sockets[i-1].group,item.sockets[i].group==item.sockets[i-1].group) end
					exercised=exercised+1
				end
			end end
		end end
		assert.are.equal(240,exercised)
	end)
	it("does not count Abyss sockets as links or bridge colours across them",function()
		local model=sim.model(raw);local state=copyTable(model.initial)
		state.sockets={{color="R",group=0},{color="A",group=0},{color="G",group=0}}
		assert.has_error(function() sim.validateState(model,state) end,"Abyssal sockets cannot be linked")
		assert.is_false(sim.matches(state,{},nil,model,{links=2}))
		assert.is_false(sim.matches(state,{},nil,model,{socketColours="RG",linkedColours=true}))
		assert.is_true(sim.matches(state,{},nil,model,{socketColours="RG"}))
		state.sockets={{color="R",group=0},{color="R",group=0},{color="A",group=1},{color="G",group=2}}
		state=sim.validateState(model,state);assert.is_true(sim.matches(state,{},nil,model,{links=2,socketColours="RR",linkedColours=true}))
		assert.is_false(sim.matches(state,{},nil,model,{links=3}))
	end)
	it("disables unsupported Abyss socket changes before drawing randomness",function()
		local model=sim.model(raw);local state=copyTable(model.initial)
		state.sockets={{color="R",group=0},{color="A",group=1}}
		for _,method in ipairs({"socket_bench","binding"}) do
			local available,reason=require("Modules.CraftingAvailability").check(method,state,model)
			assert.is_false(available);assert.is_truthy(reason:find("Abyssal",1,true))
			local draws=0;assert.is_false(pcall(sim.action,model,state,{method=method,count=2,linked=true},function() draws=draws+1;return 0.5 end));assert.are.equal(0,draws)
		end
	end)
	it("retains a Stygian Vise Abyss socket through crafting and inventory",function()
		for _,implicit in ipairs({"","\nImplicits: 1\nHas 1 Abyssal Socket"}) do
			local text="Rarity: NORMAL\nStygian Vise\nItem Level: 86\nSockets: A"..implicit
			local model=sim.model(text);local initial=sim.validateState(model,model.initial)
			local result=sim.perform(text,{method="alchemy"},1,initial);assert.are.equal("A",result.state.sockets[1].color)
			local project={id="stygian",title="Stygian",slot="Belt",startingItem=text,goals={},steps={}}
			local saved=require("Modules.CraftingInventory").capture(project,result.state,"Abyss belt")
			assert.are.equal("A",saved.state.sockets[1].color)
		end
	end)
end)
