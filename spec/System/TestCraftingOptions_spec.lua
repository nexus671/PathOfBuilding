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
	it("offers only possible resistance swaps and retains their rolled value",function()
		local m=model();local fire=natural(m,"FireResistance")
		local input=state(m,"MAGIC",{{id=fire,range=0.73}});local before=copyTable(input)
		local choices=sim.actionOptions(m,input,"harvest_resistance");assert.are.equal(2,#choices)
		for _,choice in ipairs(choices) do
			assert.are.equal("fire",choice.action.from)
			local changed=sim.perform(m.raw,choice.action,1,input).state
			assert.are.equal(choice.action.to:gsub("^%l",string.upper).."Resistance",m.byId[changed.affixes[1].id].group)
			assert.are.equal(0.73,changed.affixes[1].range)
		end
		input.affixes[1].fractured=true
		assert.is_false(check("harvest_resistance",input,m));assert.are.equal(0,#sim.actionOptions(m,input,"harvest_resistance"))
		local full=state(m,"RARE",{{id=fire,range=0.5},{id=natural(m,"ColdResistance"),range=0.5},{id=natural(m,"LightningResistance"),range=0.5}})
		assert.is_false(check("harvest_resistance",full,m));assert.are.equal(0,#sim.actionOptions(m,full,"harvest_resistance"))
		input.affixes[1].fractured=nil;assert.are.same(before,input)
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
				if #options>0 then local ok,message=pcall(sim.action,m,input,options[1].action,function() return 0.5 end);assert.is_true(ok,base.." / "..input.rarity.." / "..method..": "..tostring(message));attempted=attempted+1 end
			end end end
		end
		assert.is_true(attempted>=100)
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
