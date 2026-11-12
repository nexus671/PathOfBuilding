describe("Crafting action preconditions",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	before_each(function() newBuild() end)
	it("explains missing rarities, implicit states, imprints, sockets and fractures",function()
		local model=sim.model("Rarity: NORMAL\nIron Hat\nItem Level: 86");local state=model.initial
		for _,method in ipairs({"chaos","fracture","conflict","restore_imprint","unveil","chromatic","remove_crafted"}) do local ok,why=check(method,state,model);assert.is_false(ok,method);assert.is_truthy(why,method) end
		assert.is_true(check("alchemy",state,model));assert.is_true(check("quality",state,model))
		state=sim.perform(model.raw or "Rarity: NORMAL\nIron Hat\nItem Level: 86",{method="alchemy"},104729).state;assert.is_true(check("fracture",state,model));state.affixes[1].fractured=true;assert.is_false(check("fracture",state,model))
	end)
	it("keeps valid corrupted and unfinished-state exceptions available",function()
		local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: R-G-B";local model=sim.model(raw);local state=sim.perform(raw,{method="alchemy"},104729).state
		state.corrupted=true;assert.is_false(check("chaos",state,model));assert.is_true(check("tainted_chaos",state,model));assert.is_true(check("socket_bench",state,model))
		state.intangibility=50;assert.is_true(check("ducat_tzamoto",state,model));state.corrupted=false
		state=sim.perform(raw,{method="veiled_orb"},104729,state).state;assert.is_true(check("unveil",state,model));assert.is_false(check("annul",state,model))
	end)
	it("uses the proper class restrictions and bundled quality currency artwork",function()
		local model=sim.model("Rarity: NORMAL\nSmall Life Flask\nItem Level: 20");assert.is_true(check("quality",model.initial,model));assert.is_false(check("alchemy",model.initial,model));assert.is_false(check("catalyst",model.initial,model))
		local art=require("Modules.CraftingWorkbench");local path=art.icon("quality",{},model);local file=assert(io.open("Assets/Crafting/currencies.json"));local manifest=assert(require("dkjson").decode(file:read("*a")));file:close();local expected
		for _,entry in pairs(manifest.items) do if entry.name=="Glassblower's Bauble" then expected=entry.path end end;assert.is_truthy(expected);assert.equal(expected,path)
	end)
end)
