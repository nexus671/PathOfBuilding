describe("3.30 Light Radius modifier ranges",function()
	local sim=require("Modules.CraftingSimulator")
	local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
	local id="LightRadiusAndAccuracy3"
	it("rolls the current range while preserving and updating legacy items",function()
		local model=sim.model(raw)
		assert.equal("(21-30)% increased Light Radius",model.byId[id][2])
		local legacy={rarity="MAGIC",affixes={{id=id,range=0.5,legacyLightRadius=true}}}
		local oldText=sim.toItem(model,legacy).raw;assert.matches("15%% increased Light Radius",oldText)
		local old=sim.model(oldText);assert.is_true(old.initial.affixes[1].legacyLightRadius)
		assert.matches("15%% increased Light Radius",sim.toItem(old,old.initial).raw)
		local updated=sim.perform(oldText,{method="divine"},1)
		assert.is_nil(updated.state.affixes[1].legacyLightRadius)
		assert.matches("2%d%% increased Light Radius",updated.itemText)
		local reopened=sim.model(updated.itemText);assert.is_nil(reopened.initial.affixes[1].legacyLightRadius)
		assert.equal(updated.itemText,sim.toItem(reopened,reopened.initial).raw)
	end)
	it("uses current ranges in ordinary and influenced pools",function()
		local model=sim.model(raw);local found={}
		for _,pool in ipairs({model.mods,model.influencePool}) do
			local present=false;for _,entry in ipairs(pool) do if entry.id==id then present=true;assert.equal("(21-30)% increased Light Radius",entry.mod[2]) end end
			found[#found+1]=present
		end
		assert.same({true,true},found)
		local low=sim.rolledLines(model.byId[id],sim.rollRange(model.byId[id],function() return 0 end))
		local high=sim.rolledLines(model.byId[id],sim.rollRange(model.byId[id],function() return 0.999999 end))
		assert.equal("21% increased Light Radius",low[2]);assert.equal("30% increased Light Radius",high[2])
	end)
	it("updates every affected native range without modifying shared item data",function()
		local values=require("Modules.CraftingLightRadius330").ranges
		local helmet=sim.model(raw);local weapon=sim.model("Rarity: NORMAL\nRusted Sword\nItem Level: 86");local count=0
		for key,range in pairs(values) do
			local model=key:match("^Local") and weapon or helmet;local current=assert(model.byId[key]);local legacy=assert(model.legacyLightRadius[key])
			assert.equal("("..range..")% increased Light Radius",current[2]);assert.matches("^%d+%% increased Light Radius$",legacy[2])
			assert.equal(legacy[2],data.itemMods.Explicit[key][2]);count=count+1
		end
		assert.equal(10,count)
	end)
	it("does not allow a new state to fabricate legacy values",function()
		local model=sim.model(raw);local state=copyTable(model.initial)
		state.rarity="MAGIC";state.affixes={{id=id,range=0.5,legacyLightRadius=true}}
		assert.has_error(function() sim.validateState(model,state) end)
		local legacy=sim.toItem(model,{rarity="MAGIC",affixes={{id=id,range=0.5,legacyLightRadius=true}}}).raw
		local imported=sim.model(legacy);local modified=copyTable(imported.initial);modified.affixes[1].range=0.8
		assert.has_error(function() sim.validateState(imported,modified) end)
	end)
	it("does not update a fractured legacy modifier with a Divine Orb",function()
		local model=sim.model(raw);local text=sim.toItem(model,{rarity="MAGIC",affixes={{id=id,range=0.5,fractured=true,legacyLightRadius=true}}}).raw
		local result=sim.perform(text,{method="divine"},7)
		assert.is_true(result.state.affixes[1].legacyLightRadius);assert.matches("15%% increased Light Radius",result.itemText)
	end)
	it("clears the legacy marker when Unravelling upgrades a modifier",function()
		local model=sim.model(raw)
		local text=sim.toItem(model,{rarity="MAGIC",affixes={{id="LightRadiusAndAccuracy1",range=0.5,legacyLightRadius=true}}}).raw
		local old=sim.model(text);local state=copyTable(old.initial);state.memoryStrands=100
		local upgraded=sim.action(old,state,{method="unravelling"},function() return 0 end)
		assert.is_not.equal("LightRadiusAndAccuracy1",upgraded.affixes[1].id)
		assert.is_nil(upgraded.affixes[1].legacyLightRadius)
		assert.has_no.errors(function() sim.toItem(old,upgraded) end)
	end)
	it("imports plain copied old and current rolls without changing their values",function()
		for _,value in ipairs({15,25}) do
			local text="Rarity: MAGIC\nIron Hat\nItem Level: 86\n18% increased Global Accuracy Rating\n"..value.."% increased Light Radius"
			local model=sim.model(text);local rendered=sim.toItem(model,model.initial).raw
			assert.matches("18%% increased Global Accuracy Rating",rendered)
			assert.matches(value.."%% increased Light Radius",rendered)
			assert.equal(value==15,model.initial.affixes[1].legacyLightRadius or false)
		end
	end)
	it("reopens an item containing both legacy and current Light Radius modifiers",function()
		local sword="Rarity: NORMAL\nRusted Sword\nItem Level: 86";local model=sim.model(sword)
		local state={rarity="RARE",affixes={{id="LocalLightRadiusAndAccuracy1",range=0.5,legacyLightRadius=true},
			{id="LocalLightRadiusAndAccuracyNew2",range={0.5,0.5}}}}
		local text=sim.toItem(model,state).raw;local reopened=sim.model(text)
		assert.equal(text,sim.toItem(reopened,reopened.initial).raw)
	end)
end)
