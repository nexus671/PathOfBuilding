-- cspell:ignore RRBG
describe("Offline planning refinements",function()
	local filters=require("Modules.LootFilters")
	local parser=require("Modules.LootFilterParser")
	local atlas=require("Modules.AtlasPlanner")
	local sim=require("Modules.CraftingSimulator")
	local originalGraph
	after_each(function() if originalGraph then atlas.cache["3.27.0"]=originalGraph;originalGraph=nil end;main.popups={} end)
	it("displays arbitrary valid AI appearance values without silently selecting a preset",function()
		newBuild();main.popups={};local p=filters.profile("custom","Custom");p.appearance={minimumFontSize=25,alertVolume=150}
		require("Classes.LootFilterGlobalControl").Open(p,function() end)
		local c=main.popups[1].controls;assert.equal(25,c.minimumFontSize:GetSelValueByKey("val"));assert.equal(150,c.alertVolume:GetSelValueByKey("val"))
	end)
	it("decorates the entire filter without changing matching or imported source",function()
		local p=filters.profile("appearance","Appearance")
		p.template='Show\n BaseType == "Iron Hat"\n SetFontSize 18\n CustomAlertSoundOptional "my # sound.wav" 125\n PlayEffect Red Temp\n Continue\nHide\n BaseType == "Iron Ring"\n SetFontSize 45'
		local source=p.template;local plain=parser.parse(filters.compile(p))
		p.appearance={minimumFontSize=40,alertVolume=0,disableEffects=true}
		local raw=filters.compile(p);local decorated=parser.parse(raw)
		assert.equal(source,p.template);assert.equal(#plain.rules,#decorated.rules)
		for i,r in ipairs(plain.rules) do assert.equal(r.action,decorated.rules[i].action);for j,c in ipairs(r.conditions) do local d=decorated.rules[i].conditions[j];assert.equal(c.keyword,d.keyword);assert.equal(c.operator,d.operator);assert.same(c.values,d.values) end;assert.equal(r.continue,decorated.rules[i].continue) end
		local last=decorated.rules[#decorated.rules-1];assert.same({"40"},last.styles.SetFontSize);assert.same({"my # sound.wav","0"},last.styles.CustomAlertSoundOptional);assert.same({"None"},last.styles.PlayEffect)
		assert.same({"45"},decorated.rules[#decorated.rules].styles.SetFontSize)
		assert.same(p.appearance,filters.validate({schemaVersion=1,activeId=p.id,profiles={p}}).profiles[1].appearance)
		p.appearance=nil;assert.equal(filters.compile(p),filters.compile(filters.validate({schemaVersion=1,activeId=p.id,profiles={p}}).profiles[1]))
		local inherited=parser.parse(require("Modules.LootFilterDecorators").apply('Show\n SetFontSize 45\n Continue\nShow',{minimumFontSize=40}));assert.is_nil(inherited.rules[2].styles.SetFontSize)
	end)
	it("compiles every strictness with personal rules and reversible appearance",function()
		local p=filters.profile("variants","Variants");p.rules={filters.rule("hat","Hat",{'BaseType == "Iron Hat"'})};p.appearance={minimumFontSize=40};local before=copyTable(p)
		local variants=filters.variants(p);assert.equal(7,#variants);assert.same(before,p)
		for i,variant in ipairs(variants) do assert.equal(i-1,variant.strictness);assert.is_truthy(variant.text:find("# PoB rule: Hat",1,true));assert.is_true(#variant.text>100000) end
		assert.is_not.equal(variants[1].text,variants[7].text)
		p.template='Show';assert.is_false(pcall(filters.variants,p))
	end)
	it("keeps imports separate and rejects malformed global settings",function()
		local decorate=require("Modules.LootFilterDecorators").apply
		local parsed=parser.parse(decorate('Show\n BaseType == "Iron Hat"\nImport "shared.filter" Optional\nHide\n BaseType == "Iron Ring"',{minimumFontSize=40}))
		assert.equal(1,#parsed.imports);assert.is_nil(parsed.rules[1].styles.SetFontSize);assert.is_nil(parsed.rules[2].styles.SetFontSize)
		local p=filters.profile("bad","Bad");for _,settings in ipairs({{minimumFontSize=46},{alertVolume=-1},{alertVolume="0"},{disableEffects=1}}) do p.appearance=settings;assert.is_false(pcall(filters.compile,p)) end
	end)
	it("matches exact colour counts with an optional linked-group requirement",function()
		local model=sim.model("Rarity: NORMAL\nIron Hat\nItem Level: 86")
		local state=copyTable(model.initial);state.sockets={{color="R",group=0},{color="R",group=0},{color="G",group=1},{color="W",group=1}}
		assert.is_true(sim.matches(state,{},nil,model,{socketColours="RRG"}))
		assert.is_false(sim.matches(state,{},nil,model,{socketColours="RRG",linkedColours=true}))
		assert.is_true(sim.matches(state,{},nil,model,{socketColours="GW",linkedColours=true}))
		assert.is_false(sim.matches(state,{},nil,model,{socketColours="RGB"}))
		assert.is_false(sim.matches(state,{},nil,model,{socketColours="RRR"}))
		-- White sockets are requested as white, rather than counted as every colour.
		assert.is_false(sim.matches(state,{},nil,model,{socketColours="GB"}))
		state.sockets={};assert.is_false(sim.matches(state,{},nil,model,{socketColours="R"}))
	end)
	it("validates and retains colour targets for recipes and repeated steps",function()
		local recipe={steps={{method="chromatic",maxAttempts=5,untilRequirements={socketColours="RRBG",linkedColours=true}}},targets={},requirements={socketColours="RRBG",linkedColours=true}}
		assert.same(recipe,sim.validateRecipe(recipe))
		for _,conditions in ipairs({{socketColours=""},{socketColours="RRRRRRR"},{socketColours="RGX"},{socketColours="R",linkedColours=1},{linkedColours=true}}) do recipe.requirements=conditions;assert.is_false(pcall(sim.validateRecipe,recipe)) end
	end)
	it("uses property conditions in action odds and fossil comparisons",function()
		local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
		local failed=sim.calculate(raw,{method="alchemy"},{},nil,{trials=8,requirements={socketColours="R"}})
		assert.is_true(failed.sampled);assert.equal(0,failed.successChance)
		local passed=sim.calculate(raw,{method="alchemy"},{},nil,{trials=8,requirements={minAffixes=4}});assert.equal(100,passed.successChance)
		local fossil="Metadata/Items/Currency/CurrencyDelveCraftingPhysical"
		local result=sim.optimizeFossils(raw,{}, {fossils={fossil},maxSockets=1,trials=4,requirements={socketColours="R"}})
		assert.equal(1,#result.combinations);assert.is_nil(result.combinations[1].error);assert.equal(0,result.combinations[1].successChance)
	end)
	it("compares Atlas orders without changing existing allocations or exclusions",function()
		originalGraph=atlas.tree("3.27.0")
		local links={{2,3},{1,4},{1,4,5},{2,3},{3}}
		local tree={start=1,maxPoints=10,nodes={}};for id,list in ipairs(links) do tree.nodes[id]={id=id,links=list} end;atlas.cache["3.27.0"]=tree
		local plan={id="test",title="Test",version="3.27.0",budget=10,nodes={},notes=""};local before=copyTable(plan)
		local baseline=atlas.connect(plan,{4,5});local optimized,added,routing=atlas.connectOptimized(plan,{4,5})
		assert.equal(4,#baseline.nodes);assert.equal(3,#optimized.nodes);assert.equal(1,routing.saved);assert.equal(3,#added);assert.same(before,plan)
		plan.budget=3;assert.is_false(pcall(atlas.connect,plan,{4,5}));assert.equal(3,#atlas.connectOptimized(plan,{4,5}).nodes)
		plan.budget=10;plan.nodes={2};assert.same({2,3,4,5},atlas.connectOptimized(plan,{4,5}).nodes)
		assert.is_false(pcall(atlas.connectOptimized,plan,{4,5},{3}));assert.is_false(pcall(atlas.connectOptimized,plan,{4},{2}))
		assert.same(plan,atlas.connectOptimized(plan,{}));assert.is_false(pcall(atlas.connectOptimized,plan,{99}))
	end)
end)
