describe("Crafting modifier explanations",function()
	local sim=require("Modules.CraftingSimulator")
	local modifiers=require("Modules.CraftingModifiers")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	before_each(function() newBuild();main.popups={} end)
	after_each(function() main.popups={} end)
	it("reports the actual conditional pool and keeps source/level exclusions visible",function()
		local model=sim.model(raw);local result=modifiers.inspect(model,model.initial);local weight,chance=0,0;local bench=false
		for _,row in ipairs(result.rows) do weight=weight+row.weight;chance=chance+(row.chance or 0);if row.source=="Bench" then bench=true;assert.is_false(row.eligible);assert.is_true(#row.reasons>0) end end
		assert.is_true(#result.rows>100);assert.equal(result.totalWeight,weight);assert.is_true(math.abs(chance-100)<1e-6);assert.is_true(bench)
		local low=sim.model("Rarity: NORMAL\nIron Hat\nItem Level: 10");local found=false
		for _,row in ipairs(modifiers.inspect(low,low.initial).rows) do if row.level>10 then found=true;assert.equal(0,row.weight);assert.is_true(#row.reasons>0) end end;assert.is_true(found)
	end)
	it("explains occupied modifier groups and supports literal search",function()
		local model=sim.model(raw);local state=sim.perform(raw,{method="alchemy"},104729).state;local result=modifiers.inspect(model,state);local existing=state.affixes[1].id;local found
		for _,row in ipairs(result.rows) do if row.id==existing then found=row end end
		assert.is_truthy(found);assert.equal(0,found.weight);assert.is_true(table.concat(found.reasons," "):find("Conflicts",1,true)~=nil)
		assert.is_true(#modifiers.filter(result,"maximum Life","All affixes","All sources","All modifiers","Tier")>0)
		assert.same({},modifiers.filter(result,"[not-a-pattern]"))
	end)
	it("edits the selected target group's properties without changing another group",function()
		local groups={{anyOf={"first"}},{anyOf={"second"}}};local kept
		local c=require("Classes.CraftingTargetControl").Open(groups,nil,nil,function(result) kept=result end,1)
		c.roll:SetText("80");c.keep:Click();assert.is_truthy(kept);assert.equal(0.8,kept[1].minRoll);assert.is_nil(kept[2].minRoll);assert.is_nil(groups[1].minRoll)
	end)
	it("exposes the same state-aware explanations to native AI inspection",function()
		local state=sim.perform(raw,{method="alchemy"},104729).state;local id=state.affixes[1].id;local catalog=sim.catalog(raw,id,20,state)
		assert.same(state,catalog.initialState);assert.is_true(#catalog.modifierTable.rows>0)
		local found;for _,row in ipairs(catalog.modifierTable.rows) do if row.id==id then found=row end end
		assert.is_truthy(found);assert.equal(0,found.weight);assert.is_true(#found.reasons>0)
	end)
end)
