describe("State-aware crafting choices",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	local function model(base) return sim.model("Rarity: NORMAL\n"..(base or "Iron Hat").."\nItem Level: 86") end
	local function natural(m,group)
		for _,entry in ipairs(m.mods) do if entry.mod.group==group then return entry.id end end
		error("Missing fixture modifier group "..group)
	end
	local function state(m,rarity,affixes) local s=copyTable(m.initial);s.rarity=rarity;s.affixes=affixes or {};return sim.validateState(m,s) end
	it("offers bench crafts only on open sides and respects the crafted limit",function()
		local m=model();local input=state(m,"MAGIC",{{id=natural(m,"FireResistance"),range=0.5}})
		local before=copyTable(input);local choices=sim.actionOptions(m,input,"bench");assert.is_true(#choices>0)
		for _,choice in ipairs(choices) do
			assert.are.equal("Prefix",m.byId[choice.action.modId].type)
			assert.is_true(pcall(sim.action,m,input,choice.action,function() return 0.5 end))
		end
		local crafted=sim.perform(m.raw,choices[1].action,1,input).state
		assert.is_false(check("bench",crafted,m));assert.are.equal(0,#sim.actionOptions(m,crafted,"bench"))
		local removed=sim.perform(m.raw,{method="remove_crafted"},1,crafted).state
		assert.is_true(check("bench",removed,m));assert.are.same(before,input)
		local catalog=sim.catalog(m.raw,"",#m.bench,input);assert.are.equal(#m.bench,#catalog.bench)
		local legal,blocked=0,0
		for _,entry in ipairs(catalog.bench) do
			if entry.available then legal=legal+1;assert.is_nil(entry.unavailableReason);assert.is_true(pcall(sim.perform,m.raw,{method="bench",modId=entry.id},1,input))
			else blocked=blocked+1;assert.is_truthy(entry.unavailableReason) end
		end
		assert.is_true(legal>0 and blocked>0)
		for _,entry in ipairs(catalog.essences) do assert.is_false(entry.available);assert.is_truthy(entry.unavailableReason) end
		assert.is_false(catalog.harvestOptions[1].available);assert.is_false(catalog.harvestOptions[2].available)
		assert.is_true(catalog.harvestOptions[3].available);assert.are.equal(2,#catalog.harvestOptions[3].options)
	end)
	it("filters Essence rarity and fractured-group conflicts before selection",function()
		local m=model();local magic=sim.perform(m.raw,{method="transmute"},1).state
		assert.is_false(check("essence",magic,m));assert.are.equal(0,#sim.actionOptions(m,magic,"essence"))
		assert.is_true(#sim.actionOptions(m,m.initial,"essence")>0)
		local rare=state(m,"RARE");local low,greed
		for _,entry in ipairs(m.essences) do if entry.tier<5 and entry.type==0 then low=entry end;if entry.name=="Deafening Essence of Greed" then greed=entry end end
		assert.is_truthy(low);assert.is_truthy(greed)
		for _,choice in ipairs(sim.actionOptions(m,rare,"essence")) do assert.are_not.equal(low.id,choice.action.essenceId) end
		assert.is_false(pcall(sim.perform,m.raw,{method="essence",essenceId=low.id},1,rare))
		local fractured=state(m,"RARE",{{id=natural(m,m.byId[greed.modId].group),range=0.5,fractured=true}})
		for _,choice in ipairs(sim.actionOptions(m,fractured,"essence")) do assert.are_not.equal(greed.id,choice.action.essenceId) end
		assert.is_false(pcall(sim.perform,m.raw,{method="essence",essenceId=greed.id},1,fractured))
	end)
	it("offers only possible resistance swaps and rerolls within the replacement tier",function()
		local m=model();local fire=natural(m,"FireResistance")
		local input=state(m,"MAGIC",{{id=fire,range=0.73}});local before=copyTable(input)
		local choices=sim.actionOptions(m,input,"harvest_resistance");assert.are.equal(2,#choices)
		for _,choice in ipairs(choices) do
			assert.are.equal("fire",choice.action.from)
			local changed=sim.perform(m.raw,choice.action,1,input).state
			assert.are.equal(choice.action.to:gsub("^%l",string.upper).."Resistance",m.byId[changed.affixes[1].id].group)
			local low=sim.action(m,input,choice.action,function() return 0 end)
			local high=sim.action(m,input,choice.action,function() return 0.999999 end)
			assert.are.equal(0,low.affixes[1].range);assert.are.equal(1,high.affixes[1].range)
		end
		input.affixes[1].fractured=true
		assert.is_false(check("harvest_resistance",input,m));assert.are.equal(0,#sim.actionOptions(m,input,"harvest_resistance"))
		local full=state(m,"RARE",{{id=fire,range=0.5},{id=natural(m,"ColdResistance"),range=0.5},{id=natural(m,"LightningResistance"),range=0.5}})
		assert.is_false(check("harvest_resistance",full,m));assert.are.equal(0,#sim.actionOptions(m,full,"harvest_resistance"))
		input.affixes[1].fractured=nil;assert.are.same(before,input)
	end)
	it("swaps regular and maximum jewel resistances while respecting fractures and groups",function()
		local m=model("Cobalt Jewel")
		for _,prefix in ipairs({"","Maximum"}) do for _,from in ipairs({"Fire","Cold","Lightning"}) do
			local id=prefix..from.."ResistanceJewel";assert.is_truthy(m.byId[id])
			local input=state(m,"MAGIC",{{id=id,range=0.5}});local choices=sim.actionOptions(m,input,"harvest_resistance");assert.equal(2,#choices)
			for _,choice in ipairs(choices) do
				local result=sim.action(m,input,choice.action,function() return 0 end)
				local destination=choice.action.to:gsub("^%l",string.upper)
				assert.equal(prefix..destination.."ResistanceJewel",result.affixes[1].id)
				assert.equal(0,result.affixes[1].range)
			end
			input.affixes[1].fractured=true;assert.equal(0,#sim.actionOptions(m,input,"harvest_resistance"))
		end end
		local both=state(m,"RARE",{{id="FireResistanceJewel",range=0.5},{id="ColdResistanceJewel",range=0.5}})
		local reason=sim.resistanceReason(m,both,"fire","cold");assert.is_truthy(reason)
	end)
	it("swaps ordinary resistance on each Abyss jewel base",function()
		for _,base in ipairs({"Ghastly Eye Jewel","Hypnotic Eye Jewel","Murderous Eye Jewel","Searching Eye Jewel","Assembled Eye Jewel"}) do
			local m=model(base)
			for _,from in ipairs({"Fire","Cold","Lightning"}) do
				local input=state(m,"MAGIC",{{id="Abyss"..from.."ResistanceJewel1",range=0.5}})
				local choices=sim.actionOptions(m,input,"harvest_resistance");assert.equal(2,#choices)
				for _,choice in ipairs(choices) do local result=sim.action(m,input,choice.action,function() return 0 end);assert.equal("Abyss"..choice.action.to:gsub("^%l",string.upper).."ResistanceJewel1",result.affixes[1].id) end
				input.affixes[1].fractured=true;assert.equal(0,#sim.actionOptions(m,input,"harvest_resistance"))
			end
		end
	end)
	it("maps shield maximum resistances between equal tiers",function()
		local m=model("Pinnacle Tower Shield")
		local ids={fire={"MaximumFireResist1","MaximumFireResist2_","MaximumFireResist3"},cold={"MaximumColdResist1","MaximumColdResist2","MaximumColdResist3"},lightning={"MaximumLightningResist1","MaximumLightningResist2___","MaximumLightningResist3"}}
		for from,tiers in pairs(ids) do for tier,id in ipairs(tiers) do
			local input=state(m,"MAGIC",{{id=id,range=0.5}});local choices=sim.actionOptions(m,input,"harvest_resistance");assert.equal(2,#choices)
			for _,choice in ipairs(choices) do local result=sim.action(m,input,choice.action,function() return 0 end);assert.equal(ids[choice.action.to][tier],result.affixes[1].id) end
			input.affixes[1].fractured=true;assert.equal(0,#sim.actionOptions(m,input,"harvest_resistance"))
		end end
		local both=state(m,"RARE",{{id=ids.fire[1],range=0.5},{id=ids.cold[1],range=0.5}})
		assert.is_truthy(sim.resistanceReason(m,both,"fire","cold"))
	end)
	it("requires rare Harvest inputs and excludes tags absent from the eligible pool",function()
		local m=model("Plate Vest");local magic=sim.perform(m.raw,{method="transmute"},1).state
		for _,method in ipairs({"harvest_reforge","harvest_augment"}) do
			for _,input in ipairs({m.initial,magic}) do assert.is_false(check(method,input,m));assert.are.equal(0,#sim.actionOptions(m,input,method)) end
		end
		local rare=sim.perform(m.raw,{method="alchemy"},104729).state;local before=copyTable(rare);local life=false
		for _,choice in ipairs(sim.actionOptions(m,rare,"harvest_reforge")) do
			assert.are_not.equal("attack",choice.action.tag);life=life or choice.action.tag=="life"
			assert.is_true(pcall(sim.action,m,rare,choice.action,function() return 0.5 end))
		end
		assert.is_true(life);assert.are.same(before,rare)
		local empty=state(m,"RARE");assert.is_false(check("harvest_augment",empty,m))
		local influenced=copyTable(rare);influenced.influences={"shaper"};assert.is_false(check("harvest_augment",influenced,m))
	end)
	it("keeps offered first choices executable across equipment, jewels and flasks",function()
		local attempted=0
		for _,base in ipairs({"Iron Hat","Plate Vest","Rusted Sword","Cobalt Jewel","Small Life Flask","Coral Ring","Leather Belt"}) do
			local m=model(base);local states={m.initial,sim.perform(m.raw,{method="transmute"},104729).state}
			if base~="Small Life Flask" then states[#states+1]=sim.perform(m.raw,{method="alchemy"},104729).state end
			for _,input in ipairs(states) do for _,method in ipairs(sim.methods) do if check(method,input,m) then
				local options=sim.actionOptions(m,input,method)
				if method~="awakener" and method~="recombine" and method~="recombine_predictable" then local ok,message=pcall(sim.action,m,input,options[1] and options[1].action or {method=method},function() return 0.5 end);assert.is_true(ok,base.." / "..input.rarity.." / "..method..": "..tostring(message));attempted=attempted+1 end
			end end end
		end
		assert.is_true(attempted>=300)
	end)
	it("rejects missing state prerequisites before consuming randomness",function()
		local m=model();local rare=sim.perform(m.raw,{method="alchemy"},104729).state
		local cases={{"unravelling",m.initial},{"remembrance",rare},{"dominance",rare},{"beast_influence",rare},{"ducat_rotmother",rare},{"ducat_merrick",rare},{"ducat_genteel",m.initial},{"beast_prefix_suffix",m.initial},{"beast_suffix_prefix",m.initial},{"veiled_orb",state(m,"RARE")}}
		for _,case in ipairs(cases) do
			local before=copyTable(case[2]);local available,reason=check(case[1],case[2],m)
			assert.is_false(available);assert.is_truthy(reason)
			local calls=0;local ok,message=pcall(sim.action,m,case[2],{method=case[1]},function() calls=calls+1;return 0.5 end)
			assert.is_false(ok);assert.is_truthy(tostring(message):find(reason,1,true));assert.are.equal(0,calls);assert.are.same(before,case[2])
		end
		local ring=model("Coral Ring");assert.is_false(check("binding",ring.initial,ring))
	end)
	it("retains eligible memory, Ducat and influenced armour crafts",function()
		local m=model();assert.is_true(check("remembrance",m.initial,m))
		local strands=copyTable(m.initial);strands.memoryStrands=50
		assert.is_true(check("unravelling",strands,m));assert.is_true(pcall(sim.perform,m.raw,{method="unravelling"},1,strands))
		local belt=model("Leather Belt");local rare=sim.perform(belt.raw,{method="alchemy"},12).state
		assert.is_true(check("ducat_rotmother",rare,belt));assert.is_true(pcall(sim.perform,belt.raw,{method="ducat_rotmother"},12,rare))
		local abyss=model("Murderous Eye Jewel");local jewel=sim.perform(abyss.raw,{method="alchemy"},12).state
		assert.is_true(check("ducat_merrick",jewel,abyss));assert.is_true(pcall(sim.perform,abyss.raw,{method="ducat_merrick"},12,jewel))
		local armour=state(m,"RARE",{{id="IgnitingConfluxInfluence1",range=0.5},{id="SpellAddedChaosDamageInfluence1",range={0.5,0.5}}});armour.influences={"basilisk"}
		assert.is_true(check("dominance",armour,m));assert.is_true(pcall(sim.perform,m.raw,{method="dominance"},1,armour))
	end)
	it("preserves locked source affixes during Bestiary conversion",function()
		local m=model();local lock
		for _,entry in ipairs(m.bench) do if entry.mod[1]=="Prefixes Cannot Be Changed" then lock=entry.id end end
		local input=state(m,"RARE",{{id=natural(m,"IncreasedLife"),range=0.5}})
		input=sim.perform(m.raw,{method="bench",modId=lock},1,input).state
		assert.is_true(check("beast_prefix_suffix",input,m))
		local result=sim.perform(m.raw,{method="beast_prefix_suffix"},1,input).state
		assert.are.equal(#input.affixes+1,#result.affixes);assert.are.same(input.affixes[1],result.affixes[1])
	end)
	it("materializes independent implicit ranges without changing their saved rolls",function()
		local lines=sim.rolledLines({"Adds (1-3) to (4-6) Fire Damage","+(10-20) to maximum Life"},{0,1,0.5})
		assert.are.same({"Adds 1 to 6 Fire Damage","+15 to maximum Life"},lines)
		local ring=model("Steel Ring");local blessed=sim.perform(ring.raw,{method="blessed"},1)
		assert.are.equal("table",type(blessed.state.baseImplicitRanges[1]));assert.is_truthy(sim.toItem(ring,blessed.state).raw)
		for _,invalid in ipairs({{{-0.1,0.5}},{{0.5,1.1}},{{}},{{"invalid"}}}) do
			local state=copyTable(blessed.state);state.baseImplicitRanges=invalid;assert.is_false(pcall(sim.validateState,ring,state))
		end
		local m=model("Rusted Sword")
		for _,method in ipairs({"vaal","locus"}) do for seed=1,10 do
			local result=sim.perform(m.raw,{method=method},seed)
			if result.state.corruptedImplicits then
				local before=copyTable(result.state);local expected={}
				for _,entry in ipairs(result.state.corruptedImplicits) do for _,line in ipairs(sim.rolledLines(m.byId[entry.id],entry.range)) do expected[#expected+1]=line end end
				local item=new("Item"):Item(result.itemText);assert.are.equal(#expected,#item.implicitModLines)
				for i,line in ipairs(expected) do assert.are.equal(line,item.implicitModLines[i].line) end
				assert.are.same(before,result.state)
			end
		end end
	end)
	it("keeps a valid selected option when the emulator changes to a shorter list",function()
		newBuild();local m=model("Plate Vest")
		require("Classes.CraftingSimulatorControl").Open(build,{id="option-refresh",title="Changed bench options",slot="Body Armour",startingItem=m.raw,goals={},steps={}})
		local panel=main.popups[1];local c=panel.controls
		c.method:SelByValue("bench","val");c.method.selFunc();local previous=#c.option.list
		assert.is_true(previous>1);c.option:SetSel(previous)
		local selected=c.option:GetSelValue().action.modId
		c.currency_transmute:Click();c.method:SelByValue("bench","val");c.method.selFunc()
		assert.are.equal(selected,c.option:GetSelValue().action.modId)
		c.currency_transmute:Click();c.apply:Click()
		c.method:SelByValue("bench","val");c.method.selFunc()
		assert.is_true(#c.option.list>0 and #c.option.list<previous)
		assert.is_truthy(c.option:GetSelValue());assert.is_true(c.apply:IsEnabled());c.apply:Click()
		assert.are.equal(panel,main.popups[1]);assert.is_truthy(c.intro.label:find("Applied Crafting bench",1,true))
		main.popups={}
	end)
end)
