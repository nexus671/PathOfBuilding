describe("Twice Corrupted item fidelity",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: W-W-W\nTwice Corrupted"
	before_each(function() newBuild();main.popups={} end)
	after_each(function() main.popups={} end)
	it("recognises both corruption markers without treating them as modifiers",function()
		for _,marker in ipairs({"Corrupted","Twice Corrupted"}) do
			local item=new("Item"):Item(raw:gsub("Twice Corrupted",marker))
			assert.is_true(item.corrupted);assert.are.equal(marker=="Twice Corrupted" and true or nil,item.twiceCorrupted)
			assert.are.equal(0,#item.explicitModLines);item:BuildAndParseRaw()
			assert.is_truthy(item.raw:find("\n"..marker,1,true))
		end
	end)
	it("preserves twice corruption through tainted crafting and rejects ordinary currency",function()
		local r=sim.perform(raw,{method="tainted_chromatic"},1)
		assert.is_true(r.state.corrupted);assert.is_true(r.state.twiceCorrupted)
		assert.is_true(new("Item"):Item(r.itemText).twiceCorrupted)
		assert.is_false(pcall(sim.perform,raw,{method="chromatic"},1))
	end)
	it("inherits omitted source markers without mutating caller state and honours explicit overrides",function()
		local model=sim.model(raw);local state=copyTable(model.initial);state.corrupted=nil;state.twiceCorrupted=nil
		local original=copyTable(state);local restored=sim.validateState(model,state)
		assert.is_true(restored.corrupted);assert.is_true(restored.twiceCorrupted);assert.are.same(original,state)
		for _,corrupted in ipairs({true,false}) do
			state.corrupted=corrupted;state.twiceCorrupted=false;local item=sim.toItem(model,sim.validateState(model,state))
			assert.is_nil(item.twiceCorrupted);assert.are.equal(corrupted,item.corrupted)
		end
	end)
	it("rejects malformed and inconsistent twice-corruption flags",function()
		local model=sim.model(raw)
		for _,flag in ipairs({"true",1,{}}) do local state=copyTable(model.initial);state.twiceCorrupted=flag;assert.is_false(pcall(sim.validateState,model,state)) end
		local state=copyTable(model.initial);state.corrupted=false;assert.is_false(pcall(sim.validateState,model,state))
	end)
	it("saves and reloads both preserved and manually downgraded working items",function()
		for i,flag in ipairs({true,false}) do
			local state=copyTable(sim.model(raw).initial);state.twiceCorrupted=flag
			local p={id="twice-"..i,title="Corruption fidelity",slot="Helmet",startingItem=raw,goals={},steps={},run=require("Modules.CraftingInventory").run(state)}
			p.inventory={require("Modules.CraftingInventory").capture(p,state,"Saved item")};build.savers.CraftingProjects:Upsert(p)
		end
		local xml=build:SaveDB("Corruption fidelity");loadBuildFromXML(xml,"Corruption fidelity")
		for i,p in ipairs(build.savers.CraftingProjects.projects) do
			assert.are.equal(i==1,p.run.state.twiceCorrupted);assert.are.equal(i==1,p.inventory[1].state.twiceCorrupted)
		end
	end)
	it("supports staged marker editing without inventing second-corruption outcomes",function()
		local model=sim.model(raw);local kept
		for _,marker in ipairs({"Twice Corrupted","Corrupted","Uncorrupted"}) do
			local c=require("Classes.CraftingItemEditorControl").Open(model,model.initial,function(state) kept=state end)
			c.corrupted:SelByValue(marker);c.keep:Click()
			assert.are.equal(marker=="Twice Corrupted",kept.twiceCorrupted)
			assert.are.equal(marker~="Uncorrupted",kept.corrupted);assert.are.equal(0,#main.popups)
		end
	end)
end)
