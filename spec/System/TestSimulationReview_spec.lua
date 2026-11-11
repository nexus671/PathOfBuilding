describe("Simulation review regressions", function()
	local time = require("Modules.CalcTime")
	local encounter = require("Modules.CalcEncounter")
	before_each(function() newBuild() end)

	local function calculate(mods, config)
		local input = build.configTab.input
		input.simulateRecovery = true
		input.recoverySimulationTrials = 1
		input.recoverySimulationWindow = 10
		input.enemySpeed = 1000
		input.enemyDamageType = "Melee"
		input.enemyIsBoss = "None"
		input.enemyCritChance = 0
		for _,kind in ipairs({ "Physical", "Lightning", "Cold", "Fire", "Chaos" }) do
			input["enemy"..kind.."Damage"] = kind == "Cold" and "100" or "0"
		end
		input.customMods = "+1000 to maximum Life\n+60% to Cold Resistance\n"..(mods or "")
		for key,value in pairs(config or { }) do input[key] = value end
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg, __mainObject__.promptMsg)
		return build.calcsTab.calcsOutput, build.calcsTab.calcsEnv.player
	end

	local function equip(raw, slot)
		local item = new("Item"):Item(raw)
		build.itemsTab:AddItem(item)
		build.itemsTab.slots[slot].selItemId = item.id
		build.itemsTab.slots[slot].active = true
		return item
	end

	it("preserves fractional expected recovery near the sustainable threshold", function()
		local out = calculate("75% chance to Block Attack Damage\n33 Life gained when you Block", { enemyColdDamage="100", simulateRecovery=false })
		local nonlethal = math.ceil((out.LifeRecoverable - 25) / 0.25)
		local expected = nonlethal + (out.LifeRecoverable - nonlethal * 0.25) / 25
		assert.are.near(expected, out.NumberOfMitigatedDamagingHits, 1e-6)
	end)

	it("ends ordinary leech before damage at the same full-pool boundary", function()
		local leech = time.leech({ Life={ duration=10, rate=60, cap=60, full=100 } })
		local result = time.survival({ pools={Life=100,Mana=0,EnergyShield=0}, caps={Life=100,Mana=0,EnergyShield=0},
			window=3, interval=1, step=math.huge, leech=leech, hit=function(p,t)
				p.Life = p.Life - 60
				if t == 0 then leech:add("Life", t) end
				return p
			end })
		assert.are.equal(false, result.survived)
		assert.are.equal(2, result.time)
	end)

	it("does not start Wicked Ward protection while Energy Shield is full", function()
		local result = time.survival({ pools={Life=100,Mana=0,EnergyShield=100}, caps={Life=100,Mana=0,EnergyShield=100},
			window=3.5, interval=3, step=math.huge, wickedWard=true, rechargeDelay=2, recharge=100,
			hit=function(p,t) if t > 0 then p.EnergyShield = 50; return p, {}, true end; return p end })
		assert.are.near(50, result.pools.EnergyShield, 1e-8)
	end)

	it("requires the full upfront cost before admitting repeated hits", function()
		local use = time.skillUses()
		local pools = { Life=100, Mana=10, EnergyShield=0 }
		assert.are.equal(false, use(0, pools, {Mana=30}, 1))
		pools.Mana = 40
		assert.are.equal(false, use(1/3, pools, {Mana=30}, 1))
		assert.are.equal(true, use(1, pools, {Mana=30}, 1))
		assert.are.equal(10, pools.Mana)
		assert.are.equal(true, use(4/3, pools, {Mana=30}, 1))
		assert.are.equal(10, pools.Mana)
	end)

	it("uses Mana after Eldritch Battery exhausts ES for an upfront use", function()
		local pools = { Life=100, Mana=25, EnergyShield=5 }
		assert.are.equal(true, time.skillUses()(0, pools, {Mana=30}, 1, true))
		assert.are.equal(0, pools.Mana)
		assert.are.equal(0, pools.EnergyShield)
	end)

	it("rejects poison applications at the stack limit instead of extending their tail", function()
		local poison = encounter.poison()
		local profiles = {{ slope=100, applications=1, duration=2, stackLimit=2 }}
		for _,t in ipairs({0,0.1,0.2,0.3}) do poison:hit(t, profiles, 1) end
		local dps, damage = poison:advance(2.2)
		assert.are.equal(0, dps)
		assert.are.near(400, damage, 1e-8)
		poison:hit(3, profiles, 1)
		assert.are.equal(100, poison:advance(3))
	end)

	it("refreshes charge rates without retroactively changing accrued generation", function()
		local bank = encounter.charges({charges=100,used=100,generation=1,gain=1}, function() return 1 end)
		assert.are.equal(true, bank:use(0))
		bank:update(2, 3, 2)
		assert.are.equal(2, bank.charges)
		bank:gain(3, 4)
		assert.are.equal(13, bank.charges)
		bank:update(4, 1, 1)
		bank:advance(5)
		assert.are.equal(17, bank.charges)
	end)

	it("retains imported tincture quality when the item editor changes quality", function()
		local item = new("Item"):Item("Item Class: Tinctures\nRarity: Magic\nTest Tincture\nPrismatic Tincture\nQuality: +0%\nImplicits: 0\n29% increased Attack Speed")
		assert.are.equal(0, item.tinctureImportedQuality)
		equip("Rarity: Normal\nImperial Claw", "Weapon 1")
		build.itemsTab:AddItem(item)
		build.itemsTab.slots["Flask 1"].selItemId = item.id
		build.itemsTab.slots["Flask 1"].active = true
		local before = calculate("").Speed
		item.quality = 20
		item:BuildAndParseRaw()
		assert.are.equal(20, item.quality)
		assert.are.equal(0, item.tinctureImportedQuality)
		local roundtrip = new("Item"):Item(item.raw)
		assert.are.equal(0, roundtrip.tinctureImportedQuality)
		assert.is_true(calculate("").Speed > before)
	end)

	it("rejects partial Ward avoidance using its parsed modifier", function()
		local out = calculate("Ward has a 50% chance to not Break")
		assert.are.equal(true, out.RecoverySimulationUnsupported)
	end)

	it("restores Ward when an Iron Flask is reused before its restoration delay", function()
		equip("Rarity: Normal\nIron Flask", "Flask 1")
		local _,actor = calculate("+1000 to Ward\n50% reduced Restoration of Ward\n100% chance for Flasks you use to not consume Charges", { recoverySimulationWindow=12 })
		local restores = 0
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.event == "Iron Flask restored Ward" and row.time > 0 then restores = restores + 1; assert.is_true(row.ward > 0) end
		end
		assert.is_true(restores > 0)
	end)

	it("suppresses manual flask recovery when flasks do not apply to the player", function()
		equip("Rarity: Normal\nDivine Life Flask", "Flask 1")
		local mods = "Life Regeneration has no effect\nFlasks do not apply to you"
		local excluded = calculate(mods, { recoverySimulationWindow=60 }).RecoverySimulationTime
		calculate(mods, { recoverySimulationWindow=60, recoverySimulationEquippedFlasks=false })
		build.itemsTab.slots["Flask 1"].active = false
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.are.near(excluded, build.calcsTab.calcsOutput.RecoverySimulationTime, 1e-8)
	end)

	it("does not stack gradual recovery from identical Life flasks", function()
		equip("Rarity: Normal\nDivine Life Flask", "Flask 1")
		local one = calculate("Life Regeneration has no effect", { enemyColdDamage="900", recoverySimulationWindow=10, recoverySimulationFlaskReaction=0 }).RecoverySimulationTime
		equip("Rarity: Normal\nDivine Life Flask", "Flask 2")
		local two = calculate("Life Regeneration has no effect", { enemyColdDamage="900", recoverySimulationWindow=10, recoverySimulationFlaskReaction=0 }).RecoverySimulationTime
		assert.are.near(one, two, 1e-8)
	end)

	it("refreshes Mana recovery permission when Soul Catcher expires", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		equip("Rarity: Unique\nSoul Catcher\nQuartz Flask\nImplicits: 0\nCannot gain Mana during Effect", "Flask 1")
		local out,actor = calculate("+75% chance to Block Attack Damage\n100 Mana gained when you Block\n100% less Mana Regeneration Rate", { recoverySimulationWindow=20, recoverySimulationAttacking=true })
		assert.is_true(actor.modDB:Flag(nil, "CannotGainMana"))
		assert.are.equal(100, out.ManaOnBlock)
		local minimum, later = out.ManaUnreserved, 0
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.time < 10 then minimum = math.min(minimum, row.Mana)
			elseif row.time > 12 then later = math.max(later, row.Mana) end
		end
		assert.is_true(minimum < out.ManaUnreserved)
		assert.is_true(later > minimum)
	end)

	it("honors the selected Calcs skill in temporary-effect projections", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.skillsTab:PasteSocketGroup("Arc 20/0  1")
		for _,group in ipairs(build.skillsTab.socketGroupList) do build.skillsTab:ProcessSocketGroup(group) end
		build.mainSocketGroup = 1
		build.calcsTab.input.skill_number = 2
		equip("Rarity: Normal\nGranite Flask", "Flask 1")
		local config = { recoverySimulationAttacking=true, recoverySimulationWindow=20 }
		local mods = "+10000 to maximum Life\n+1000 to maximum Mana\nRegenerate 1000 Mana per second"
		local _,actor = calculate(mods, config)
		local selected = actor.recoverySimulationResults[1].directDamage
		build.mainSocketGroup = 2
		local _,same = calculate(mods, config)
		assert.are.near(selected, same.recoverySimulationResults[1].directDamage, 1e-8)
	end)

	it("uses simulated low Life for conditional flask recovery", function()
		equip("Rarity: Normal\nDivine Life Flask", "Flask 1")
		local config = { enemyColdDamage="900", recoverySimulationFlaskReaction=0 }
		local ordinary = calculate("Life Regeneration has no effect", config).RecoverySimulationTime
		local lowLife = calculate("Life Regeneration has no effect\n100% more Recovery if used while on Low Life", config).RecoverySimulationTime
		assert.is_true(lowLife > ordinary)
		assert.is_true(not build.configTab.input.conditionLowLife)
	end)

	it("applies Mana-flask charge generation to Hybrid flasks", function()
		equip("Rarity: Normal\nHallowed Hybrid Flask", "Flask 1")
		local config = { enemyColdDamage="400", recoverySimulationWindow=30, recoverySimulationFlaskReaction=0 }
		local ordinary = calculate("+10000 to maximum Life\nLife Regeneration has no effect", config).RecoverySimulationFlaskUses
		local generated = calculate("+10000 to maximum Life\nLife Regeneration has no effect\nMana Flasks gain 60 Charges every 3 seconds", config).RecoverySimulationFlaskUses
		assert.is_true(generated > ordinary)
	end)

	it("converts physical-prevention Life regeneration with Zealot's Oath", function()
		local _,actor = calculate("+100 to maximum Energy Shield\n+2000 to Armour\n100% less Energy Shield Recharge Rate\nZealot's Oath\n30% of Physical Damage prevented from Hits in the past 4 seconds is Regenerated as Life per second",
			{ enemyColdDamage="0", enemyPhysicalDamage="1000", recoverySimulationSingleHit=true, recoverySimulationWindow=3 })
		local hit, last
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.event:find("Melee hit", 1, true) then hit = row end
			last = row
		end
		assert.is_truthy(hit)
		assert.are.near(hit.Life, last.Life, 1e-8)
		assert.is_true(last.EnergyShield > hit.EnergyShield)
	end)

	it("recasts Arcane Cloak by spending current Mana", function()
		build.skillsTab:PasteSocketGroup("Arcane Cloak 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		local out,actor = calculate("+1000 to maximum Mana\n100% less Mana Regeneration Rate", { recoverySimulationRecastGuard=true, recoverySimulationWindow=20 })
		local uses, mana = 0, out.ManaUnreserved
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.event == "Guard recast; costs paid" then
				uses = uses + 1
				assert.is_true(row.Mana < mana)
				mana = row.Mana
			end
		end
		assert.is_true(uses > 1)
	end)

	it("redirects Safeguarding Golem damage only for melee outcomes in Average", function()
		build.skillsTab:PasteSocketGroup("Summon Stone Golem of Safeguarding 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		local _,actor = calculate("", { enemyDamageType="Average" })
		local melee, other = false, false
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.event:match("^%a+ hit") then
				local damage = tonumber(row.event:match(": (%d+) Cold"))
				if row.event:find("Melee hit", 1, true) then melee = true; assert.are.equal(85, damage)
				else other = true; assert.are.equal(100, damage) end
			end
		end
		assert.is_true(melee and other)
	end)

	it("rejects sustained skill self-damage instead of granting free attack recovery", function()
		build.skillsTab:PasteSocketGroup("Fireball 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		equip("Rarity: Unique\nScold's Bridle\nMind Cage\nImplicits: 0\nYour Skills deal you 400% of Mana Cost as Physical Damage", "Helmet")
		local out = calculate("", { recoverySimulationAttacking=true })
		assert.is_true(out.SelfHitDamage > 0)
		assert.are.equal(true, out.RecoverySimulationUnsupported)
	end)

	it("routes blocked Emperor's Vigilance hits to ES unless an independent bypass applies", function()
		local mods = "+1000 to maximum Energy Shield\n100% less Energy Shield Recharge Rate\n75% chance to Block Attack Damage\nGlancing Blows\nDamage taken from blocked Hits cannot bypass Energy Shield\nDamage taken from unblocked Hits always bypasses Energy Shield"
		local out,actor = calculate(mods)
		assert.is_true(actor.modDB:Flag(nil, "BlockedDamageDoesntBypassES"))
		assert.is_true(actor.modDB:Flag(nil, "UnblockedDamageDoesBypassES"))
		local blocked = false
		for _,row in ipairs(actor.recoverySimulationTrace.rows) do
			if row.event:find("(blocked)", 1, true) then blocked = true; assert.is_true(row.EnergyShield < out.EnergyShield) end
		end
		assert.is_true(blocked)
		local _,bypass = calculate(mods.."\nAll Damage taken bypasses Energy Shield")
		for _,row in ipairs(bypass.recoverySimulationTrace.rows) do assert.are.equal(out.EnergyShield, row.EnergyShield) end
	end)
end)
