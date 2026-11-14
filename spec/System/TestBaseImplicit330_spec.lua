describe("3.30 base implicits",function()
	local sim=require("Modules.CraftingSimulator")
	before_each(function() newBuild() end)
	it("uses the announced defaults and parses the changed modifier meanings",function()
		local expected={
			["Apothecary's Gloves"]="+(14-18)% to Damage over Time Multiplier",
			["Fingerless Silk Gloves"]="(20-26)% increased Spell Damage",
			["Gripped Gloves"]="(22-28)% increased Projectile Attack Damage",
			["Spiked Gloves"]="(24-30)% increased Melee Damage",
			["Fugitive Boots"]="+(17-23)% to Chaos Resistance",
			["Two-Toned Boots (Armour/Evasion)"]="+(16-20)% to Fire and Cold Resistances",
			["Two-Toned Boots (Armour/Energy Shield)"]="+(16-20)% to Fire and Lightning Resistances",
			["Two-Toned Boots (Evasion/Energy Shield)"]="+(16-20)% to Cold and Lightning Resistances",
			["Bone Helmet"]="Minions deal (20-30)% increased Damage",
			["Marble Amulet"]="Regenerate (1.4-2)% of Life per second",
			["Seaglass Amulet"]="(20-30)% faster start of Energy Shield Recharge",
			["Vanguard Belt"]="+(260-480) to Armour and Evasion Rating",
			["Crystal Belt"]="+(60-100) to maximum Energy Shield",
			["Amethyst Ring"]="+(13-19)% to Chaos Resistance",
			["Artillery Quiver"]="Attack Skills have +1 to maximum number of Summoned Totems",
		}
		for name,line in pairs(expected) do assert.equal(line,data.itemBases[name].implicit,name) end
		local dot,extra=modLib.parseMod("+18% to Damage over Time Multiplier");assert.is_nil(extra);assert.equal("DotMultiplier",dot[1].name)
		local totem;totem,extra=modLib.parseMod(expected["Artillery Quiver"]);assert.is_nil(extra)
		assert.equal("ActiveTotemLimit",totem[1].name);assert.equal(KeywordFlag.Attack,totem[1].keywordFlags)
	end)
	it("preserves legacy lines until Blessed and then uses current ranges",function()
		for name,base in pairs(data.itemBases) do if base.blessed330 then
			local legacy=itemLib.applyRange(base.blessed330.old,0)
			local raw="Rarity: NORMAL\n"..name.."\nItem Level: 86\nImplicits: 1\n"..legacy
			local model=sim.model(raw);assert.is_truthy(model.blessed330,name)
			assert.is_truthy(sim.toItem(model,model.initial).raw:find(legacy,1,true),name)
			for _,sample in ipairs({0,0.99999}) do
				local state=sim.action(model,model.initial,{method="blessed"},function() return sample end)
				state=sim.validateState(model,state)
				local text=sim.toItem(model,state).raw;local expected=itemLib.applyRange(base.blessed330.current,sample==0 and 0 or 1)
				assert.is_truthy(text:find(expected,1,true),name.." expected "..expected)
			end
		end end
	end)
	it("keeps the legacy Artillery Quiver implicit on existing items",function()
		local raw="Rarity: NORMAL\nArtillery Quiver\nItem Level: 86\nImplicits: 1\n25% increased Totem Placement speed"
		local model=sim.model(raw);assert.is_nil(model.blessed330)
		assert.is_truthy(sim.toItem(model,model.initial).raw:find("25% increased Totem Placement speed",1,true))
	end)
	it("does not guess an unrecognized implicit when using a Blessed Orb",function()
		local raw="Rarity: NORMAL\nFingerless Silk Gloves\nItem Level: 86\nImplicits: 1\n+10% to Fire Resistance"
		local model=sim.model(raw);assert.is_true(model.blessed330Unresolved)
		local available,reason=require("Modules.CraftingAvailability").check("blessed",model.initial,model)
		assert.is_false(available);assert.matches("could not be identified",reason)
		assert.has_error(function() sim.perform(raw,{method="blessed"},1) end,reason)
	end)
	it("keeps the Blessed result through inventory serialization",function()
		local raw="Rarity: NORMAL\nFingerless Silk Gloves\nItem Level: 86\nImplicits: 1\n12% increased Spell Damage"
		local result=sim.perform(raw,{method="blessed"},17)
		local project={id="legacy-gloves",title="Legacy gloves",slot="Gloves",startingItem=raw,goals={},steps={}}
		local saved=require("Modules.CraftingInventory").capture(project,result.state)
		local json=require("dkjson");local decoded=assert(json.decode(json.encode({saved})))
		local restored=require("Modules.CraftingInventory").validate(decoded)[1]
		assert.equal(result.itemText,sim.toItem(sim.model(raw),restored.state).raw)
	end)
	it("keeps an updated implicit valid through recombination and later crafting",function()
		local raw="Rarity: NORMAL\nFingerless Silk Gloves\nItem Level: 86\nImplicits: 1\n12% increased Spell Damage"
		local model=sim.model(raw);local random=function() return 0.1 end
		local updated=sim.action(model,model.initial,{method="blessed"},random)
		local magic=sim.action(model,updated,{method="transmute"},random)
		local donor=sim.toItem(model,magic).raw
		local recombined=sim.action(model,magic,{method="recombine",donorItem=donor},random)
		assert.is_truthy(sim.validateState(model,recombined))
		assert.is_truthy(sim.toItem(model,recombined).raw:find("increased Spell Damage",1,true))
		local rerolled=sim.action(model,recombined,{method="blessed"},random)
		assert.is_truthy(sim.validateState(model,rerolled))
	end)
end)
