describe("3.30 unveiled jewel modifiers",function()
	local sim=require("Modules.CraftingSimulator")
	local regular="Rarity: NORMAL\nCobalt Jewel\nItem Level: 86"
	local abyss="Rarity: NORMAL\nSearching Eye Jewel\nItem Level: 86"
	it("loads the eligible special modifiers without adding them to natural rolls",function()
		local jewel=sim.model(regular);local eye=sim.model(abyss);local regularCount,abyssCount=0,0
		for _ in pairs(jewel.unveiledJewels) do regularCount=regularCount+1 end
		for _ in pairs(eye.unveiledJewels) do abyssCount=abyssCount+1 end
		assert.equal(30,regularCount);assert.is_true(abyssCount>10)
		assert.is_truthy(jewel.byId.JunMasterVeiledJewelElusiveEffect);assert.is_nil(eye.unveiledJewels.JunMasterVeiledJewelElusiveEffect)
		for _,model in ipairs({jewel,eye}) do for _,entry in ipairs(model.mods) do assert.is_nil(model.unveiledJewels[entry.id]) end end
		assert.is_nil(sim.model("Rarity: NORMAL\nCobalt Jewel\nItem Level: 67").unveiledJewels.JunMasterVeiledJewelElusiveEffect)
	end)
	it("imports and preserves an unveiled jewel through crafting and reopening",function()
		local text="Rarity: MAGIC\nCobalt Jewel\nItem Level: 86\n4% increased Elusive Effect"
		local model=sim.model(text);local id="JunMasterVeiledJewelElusiveEffect"
		assert.equal(id,model.initial.affixes[1].id)
		local recreated=sim.toItem(model,model.initial).raw;assert.matches("4%% increased Elusive Effect",recreated)
		local reopened=sim.model(recreated);assert.equal(id,reopened.initial.affixes[1].id)
		local divined=sim.perform(text,{method="divine"},7);assert.equal(id,divined.state.affixes[1].id);assert.matches("[345]%% increased Elusive Effect",divined.itemText)
	end)
	it("exposes new modifiers as special rather than as ordinary or orb-generated outcomes",function()
		local model=sim.model(regular);local id="JunMasterVeiledJewelLifeCost"
		assert.is_true(model.special[id]);assert.equal("Skills Cost Life instead of (3-5)% of Mana Cost",model.byId[id][1])
		assert.is_false(require("Modules.CraftingAvailability").check("veiled_orb",model.initial,model))
		local found;for _,row in ipairs(require("Modules.CraftingModifiers").catalog(model)) do if row.id==id then found=row end end
		assert.equal("Special",assert(found).source)
		local regen=model.byId.JunMasterVeiledJewelMineRegen
		assert.equal(0.5,sim.rollRange(regen,function() return 0.51 end))
	end)
	it("lets a user build a hypothetical unveiled jewel explicitly",function()
		newBuild();main.popups={}
		local model=sim.model(regular);local id="JunMasterVeiledJewelElusiveEffect";local saved
		local editor=require("Classes.CraftingItemEditorControl").Open(model,model.initial,function(state) saved=state end)
		editor.modifier:SelByValue(id,"val");editor.roll:SetText("50");editor.rarity:SelByValue("MAGIC");editor.properties:Click();editor.add:Click();editor.keep:Click()
		assert.is_truthy(saved);assert.equal(id,saved.affixes[1].id);assert.matches("4%% increased Elusive Effect",sim.toItem(model,saved).raw)
		main.popups={}
	end)
	it("distinguishes identical unveiled descriptions in the editor",function()
		newBuild();main.popups={}
		local model=sim.model(abyss);local first="JunMasterVeiledAbyssMurderousImpaleEffect";local second="JunMasterVeiledAbyssSearchingImpaleEffect"
		assert.is_truthy(model.unveiledJewels[first]);assert.is_truthy(model.unveiledJewels[second])
		local saved;local editor=require("Classes.CraftingItemEditorControl").Open(model,model.initial,function(state) saved=state end)
		local labels={};for _,entry in ipairs(editor.modifier.list) do if entry.val==first or entry.val==second then labels[entry.val]=entry.label end end
		assert.matches("Unveiled %(Murderous%)",assert(labels[first]));assert.matches("Unveiled %(Searching%)",assert(labels[second]))
		editor.modifier:SelByValue(second,"val");editor.rarity:SelByValue("MAGIC");editor.properties:Click();editor.add:Click()
		assert.matches("Unveiled %(Searching%)",editor.current:GetSelValue().label);editor.keep:Click()
		assert.equal(second,saved.affixes[1].id);assert.equal(second,sim.model(sim.toItem(model,saved).raw).initial.affixes[1].id)
		main.popups={}
	end)
	it("retains a selected unveiled modifier in a saved crafting inventory",function()
		newBuild();local model=sim.model(regular);local id="JunMasterVeiledJewelElusiveEffect"
		local state=sim.validateState(model,{rarity="MAGIC",affixes={{id=id,range=0.5}}})
		local slot;local item=require("Modules.CraftingProjects").item(regular)
		for name in pairs(build.itemsTab.slots) do if name:match("^Jewel %d+$") and build.itemsTab:IsItemValidForSlot(item,name) then slot=name;break end end
		assert.is_truthy(slot)
		local project={id="unveiled-jewel",title="Unveiled jewel",slot=slot,startingItem=regular,goals={},steps={}}
		project.inventory={require("Modules.CraftingInventory").capture(project,state,"Selected jewel")};build.savers.CraftingProjects:Upsert(project)
		local xml=build:SaveDB("Unveiled jewel");loadBuildFromXML(xml,"Unveiled jewel")
		local restored=build.savers.CraftingProjects.projects[1].inventory[1].state
		assert.equal(id,restored.affixes[1].id);assert.matches("4%% increased Elusive Effect",sim.toItem(sim.model(regular),restored).raw)
	end)
	it("preserves the two-line Abyss modifiers on the proper base",function()
		local raw="Rarity: NORMAL\nHypnotic Eye Jewel\nItem Level: 86";local model=sim.model(raw)
		local id="JunMasterVeiledAbyssHypnoticDaggerDamageAsSpellDamage";assert.equal(2,#model.byId[id])
		local text=sim.toItem(model,{rarity="MAGIC",affixes={{id=id,range=0.5}}}).raw
		assert.matches("Gain Added Spell Damage",text);assert.matches("If two Daggers are Equipped",text)
		local reopened=sim.model(text);assert.equal(id,reopened.initial.affixes[1].id)
		assert.is_nil(sim.model(abyss).unveiledJewels[id])
	end)
	it("round trips every source modifier on a compatible jewel",function()
		local models={};for _,base in ipairs({"Cobalt Jewel","Searching Eye Jewel","Murderous Eye Jewel","Hypnotic Eye Jewel","Ghastly Eye Jewel"}) do models[#models+1]=sim.model("Rarity: NORMAL\n"..base.."\nItem Level: 86") end
		local file=assert(io.open("Data/Crafting/3.30-unveiled-jewels.json","rb"));local source=assert(require("dkjson").decode(file:read("*a")));file:close();local count=0
		local ids={};for id in pairs(source.mods) do ids[#ids+1]=id end;table.sort(ids)
		for _,id in ipairs(ids) do
			local model;for _,candidate in ipairs(models) do if candidate.unveiledJewels[id] then model=candidate;break end end
			assert.is_truthy(model,id);local item=sim.toItem(model,{rarity="MAGIC",affixes={{id=id,range=0.5}}}).raw
			local ok,reopened=pcall(sim.model,item);assert.is_true(ok,id..": "..tostring(reopened).."\n"..item);assert.equal(id,reopened.initial.affixes[1].id);count=count+1
		end
		assert.equal(53,count)
	end)
end)
