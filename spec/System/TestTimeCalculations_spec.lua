describe("Finite combat windows", function()
	local time = require("Modules.CalcTime")
	before_each(function() newBuild() end)

	it("integrates poison before and after its duration limit", function()
		local early = time.poisonWindow({{ slope = 100, ceiling = 400 }}, 2)
		assert.are.near(200, early.dps, 1e-8)
		assert.are.near(200, early.damage, 1e-8)
		assert.are.near(100, early.average, 1e-8)
		local late = time.poisonWindow({{ slope = 100, ceiling = 400 }}, 6)
		assert.are.near(1600, late.damage, 1e-8)
		assert.are.near(4, late.ramp, 1e-8)
	end)

	it("integrates separate poison streams and a shared DoT cap", function()
		local result = time.poisonWindow({{ slope = 100, ceiling = 100 }, { slope = 100, ceiling = 400 }}, 4, 300)
		-- 0..1: 0->200; 1..2: 200->300; 2..4: capped at 300.
		assert.are.near(950, result.damage, 1e-8)
		assert.are.near(300, result.dps, 1e-8)
		assert.are.equal(0, time.poisonWindow({}, 0).average)
	end)

	local function simulate(options)
		options.pools = options.pools or { Life = 100, Mana = 0, EnergyShield = 0 }
		options.caps = options.caps or { Life = 100, Mana = 0, EnergyShield = 0 }
		options.interval = options.interval or 1
		options.window = options.window or 10
		return time.survival(options)
	end

	it("does not recover before a lethal first hit", function()
		local result = simulate({ rates = { Life = 1000 }, hit = function(p) p.Life = p.Life - 100; return p end })
		assert.are.equal(false, result.survived)
		assert.are.equal(0, result.time)
	end)

	it("caps recovery and reports bounded survival", function()
		local result = simulate({ rates = { Life = 1000 }, hit = function(p) p.Life = p.Life - 60; return p end })
		assert.are.equal(true, result.survived)
		assert.are.equal(10, result.time)
		assert.is_true(result.pools.Life <= 100)
	end)

	it("ramps recoup cohorts and expires them", function()
		local result = simulate({ interval = 20, hit = function(p, t)
			p.Life = p.Life - 80
			return p, {{ Life = 20, expires = t + 4 }}
		end })
		assert.are.near(100, result.pools.Life, 1e-7)
	end)

	it("detects delayed death between hits independently of step size", function()
		for _, step in ipairs({0.02, 0.01}) do
			local result = simulate({ step = step, interval = 20, hit = function(p, t)
				p.Life = 10
				return p, {{ Life = -20, expires = t + 4 }}
			end })
			assert.are.equal(false, result.survived)
			assert.are.near(0.5, result.time, 1e-8)
		end
	end)

	it("starts ES recharge after its delay and respects every pool cap", function()
		local result = simulate({ window = 3, interval = 20, recharge = 10, rechargeDelay = 2,
			pools = { Life = 100, Mana = 10, EnergyShield = 50 }, caps = { Life = 100, Mana = 20, EnergyShield = 50 },
			rates = { Mana = 100 }, hit = function(p) p.EnergyShield = 0; return p end })
		assert.are.near(10, result.pools.EnergyShield, 1e-7)
		assert.are.equal(20, result.pools.Mana)
	end)

	it("interrupts recharge when on-block recovery hides ES damage", function()
		local result = simulate({ window = 3, recharge = 10, rechargeDelay = 2,
			pools = { Life = 100, Mana = 0, EnergyShield = 25 }, caps = { Life = 100, Mana = 0, EnergyShield = 50 },
			hit = function(p) return p, {}, true end })
		assert.are.equal(25, result.pools.EnergyShield)
	end)

	local function calculate(mods)
		build.configTab.input.simulateRecovery = true
		build.configTab.input.recoverySimulationWindow = 10
		build.configTab.input.enemySpeed = 1000
		build.configTab.input.enemyDamageType = "Melee"
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.enemyCritChance = 0
		for _, damageType in ipairs({ "Physical", "Fire", "Cold", "Lightning", "Chaos" }) do
			build.configTab.input["enemy"..damageType.."Damage"] = damageType == "Cold" and "100" or "0"
		end
		build.configTab.input.customMods = "+100 to maximum Life\n+60% to Cold Resistance\n"..mods
		build.configTab:BuildModList()
		runCallback("OnFrame")
		assert(not __mainObject__.promptMsg, __mainObject__.promptMsg)
		return build.calcsTab.calcsOutput
	end

	it("uses reproducible randomness and entropy rather than independent evade rolls", function()
		local a, b = time.random(12345), time.random(12345)
		for i = 1, 20 do assert.are.equal(a(), b()) end
		local evades = time.evasion(function() return 0.25 end)
		assert.are.equal(false, evades(50, 0))
		assert.are.equal(true, evades(50, 1))
		assert.are.equal(false, evades(50, 2))
		assert.are.equal(true, evades(50, 3))
	end)

	it("resets entropy after an attack-free gap", function()
		local calls = 0
		local evade = time.evasion(function() calls = calls + 1; return 0.25 end)
		evade(50, 0); evade(50, 1); evade(50, 5)
		assert.are.equal(2, calls)
	end)

	it("consumes finite shrouds and regenerates them on their two-second cadence", function()
		local shrouds = time.shrouds(3)
		assert.are.equal(true, shrouds(0, true))
		assert.are.equal(false, shrouds(0.1, false)) -- blocked/evaded hit
		assert.are.equal(true, shrouds(0.2, true))
		assert.are.equal(true, shrouds(0.3, true))
		assert.are.equal(false, shrouds(1.99, true))
		assert.are.equal(true, shrouds(2, true))
		assert.are.equal(false, shrouds(2.1, true))
	end)

	it("permits full or partial recharge only in actual damage-free gaps", function()
		for _, window in ipairs({ 2.5, 4 }) do
			local result = simulate({ interval = 1, window = window, step = math.huge, recharge = 50, rechargeDelay = 2,
				pools = { Life = 100, Mana = 0, EnergyShield = 100 }, caps = { Life = 100, Mana = 0, EnergyShield = 100 },
				hit = function(p, t) if t == 0 then p.EnergyShield = 0; return p, {}, true end; return p end })
			assert.are.near(window == 2.5 and 25 or 100, result.pools.EnergyShield, 1e-8)
		end
	end)

	it("releases Dissolution reservation after a gap but resets its timer on damage", function()
		for _, interval in ipairs({ 1.9, 2.1 }) do
			local result = simulate({ dissolution = true, interval = interval, step = math.huge,
				hit = function(p) p.Life = p.Life - 60; return p end })
			assert.are.equal(interval > 2, result.survived)
		end
	end)

	it("reports bounded trial percentiles and survival frequency", function()
		local result = time.summarise({{time=1,survived=false},{time=4,survived=false},{time=10,survived=true}})
		assert.are.equal(4, result.time)
		assert.are.equal(1, result.low)
		assert.are.equal(10, result.high)
		assert.are.near(100 / 3, result.chance, 1e-8)
	end)

	it("includes regeneration without changing burst EHP", function()
		local before = calculate("")
		local ehp, death = before.TotalEHP, before.RecoverySimulationTime
		local after = calculate("Regenerate 100 Life per second")
		assert.are.near(ehp, after.TotalEHP, 1e-6)
		assert.is_true(after.RecoverySimulationTime > death)
		assert.are.equal(true, after.RecoverySimulationSurvived)
	end)

	it("adds main-skill poison window outputs without changing steady DPS", function()
		build.skillsTab:PasteSocketGroup("Ethereal Knives 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		local before = calculate("100% chance to Poison on Hit")
		local steady = before.TotalPoisonDPS
		assert.is_true(steady > 0)
		assert.is_true(before.PoisonWindowAverageDPS < steady)
		build.configTab.input.poisonDamageWindow = 20
		local after = calculate("100% chance to Poison on Hit")
		assert.are.near(steady, after.TotalPoisonDPS, 1e-6)
		assert.are.near(steady, after.PoisonWindowDPS, 1e-6)
	end)

	it("ramps native recoup rather than granting its steady rate immediately", function()
		local before = calculate("+400 to maximum Life").RecoverySimulationTime
		local after = calculate("+400 to maximum Life\n100% of Damage taken Recouped as Life")
		assert.is_true(after.RecoverySimulationTime > before)
	end)

	it("supports ordinary Ward restoration", function()
		local out = calculate("+100 to Ward")
		assert.is_nil(out.RecoverySimulationUnsupported)
		assert.is_true(out.RecoverySimulationTime > 0)
		build.configTab.input.enemySpeed = 5000
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.are.equal(true, build.calcsTab.calcsOutput.RecoverySimulationSurvived)
	end)

	it("ramps leech instances, caps their combined rate and removes them at full", function()
		local leech = time.leech({ Life = { duration = 5, rate = 10, cap = 15, full = 100 } })
		leech:add("Life", 0)
		assert.are.equal(10, leech:rates(0, {Life=50}).Life)
		leech:add("Life", 1)
		assert.are.equal(15, leech:rates(1, {Life=50}).Life)
		assert.is_nil(leech:rates(2, {Life=100}).Life)
		assert.is_nil(leech:rates(3, {Life=50}).Life)
	end)

	it("retains leech at full when allowed and expires each instance separately", function()
		local leech = time.leech({ Life = { duration = 5, rate = 10, cap = 50, full = 100, persist = true } })
		leech:add("Life", 0); leech:add("Life", 1)
		assert.are.equal(20, leech:rates(2, {Life=100}).Life)
		assert.are.equal(10, leech:rates(5, {Life=50}).Life)
		assert.is_nil(leech:rates(6, {Life=50}).Life)
	end)

	it("limits flask uptime to available charges", function()
		local flask = time.flask({ charges = 20, used = 10, duration = 2 })
		assert.are.equal(true, flask(0, true))
		assert.are.equal(true, flask(2, true))
		assert.are.equal(false, flask(4, true))
	end)

	it("Wicked Ward protects a recharge that began recently", function()
		for _, wicked in ipairs({false, true}) do
			local result = simulate({ window=3.5, interval=3, wickedWard=wicked, recharge=20, rechargeDelay=2, step=math.huge,
				pools={Life=100,Mana=0,EnergyShield=100},caps={Life=100,Mana=0,EnergyShield=100},
				hit=function(p,t) p.EnergyShield=p.EnergyShield-(t==0 and 80 or 10);return p,{},true end })
			assert.are.near(wicked and 40 or 30, result.pools.EnergyShield, 1e-8)
		end
	end)

	it("applies Petrified Blood's delayed loss between widely spaced hits", function()
		build.skillsTab:PasteSocketGroup("Petrified Blood 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		build.configTab.input.conditionLowLife = true
		local out = calculate("")
		build.configTab.input.enemySpeed = 10000
		build.configTab:BuildModList()
		runCallback("OnFrame")
		out = build.calcsTab.calcsOutput
		assert.is_true(out.RecoverySimulationTime > 0)
		assert.is_true(out.RecoverySimulationTime < 4)
		assert.are.equal(false, out.RecoverySimulationSurvived)
	end)

	it("consumes actual Ghost Dance charges without changing burst EHP", function()
		local out = calculate("Ghost Dance\n+2000 to Evasion Rating\n+500 to maximum Energy Shield\n100% less Energy Shield Recharge Rate")
		assert.is_true(out.RecoverySimulationShroudsUsed > 0)
		assert.is_true(out.RecoverySimulationShroudRecovery > 0)
		local ehp = out.TotalEHP
		build.configTab.input.simulateRecovery = false
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.are.near(ehp, build.calcsTab.calcsOutput.TotalEHP, 1e-8)
	end)

	it("adds native physical-prevention regeneration over its recent duration", function()
		build.configTab.input.enemyDamageType = "Melee"
		local mods = "+500 to maximum Energy Shield\n100% less Energy Shield Recharge Rate\n+2000 to Armour\nDivine Shield"
		calculate(mods)
		build.configTab.input.recoverySimulationWindow = 60
		build.configTab.input.enemyColdDamage = "0"
		build.configTab.input.enemyPhysicalDamage = "100"
		build.configTab:BuildModList(); runCallback("OnFrame")
		local withShield = build.calcsTab.calcsOutput.RecoverySimulationTime
		build.configTab.input.customMods = "+100 to maximum Life\n"..mods:gsub("Divine Shield", "")
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.is_true(withShield > build.calcsTab.calcsOutput.RecoverySimulationTime)
	end)

	it("models basic Dissolution without letting regeneration clear reservation", function()
		local mods = "Life that would be lost by taking Damage is instead Reserved\nRemoves all Energy Shield"
		local before = calculate(mods).RecoverySimulationTime
		local after = calculate(mods.."\nRegenerate 10000 Life per second")
		assert.are.near(before, after.RecoverySimulationTime, 1e-8)
		build.configTab.input.enemySpeed = 2100
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.are.equal(true, build.calcsTab.calcsOutput.RecoverySimulationSurvived)
	end)

	it("does not apply guaranteed spell suppression twice", function()
		calculate("+10000 to maximum Life\n+100% chance to Suppress Spell Damage")
		build.configTab.input.enemyDamageType = "Spell"
		build.configTab:BuildModList(); runCallback("OnFrame")
		local o = build.calcsTab.calcsOutput
		local expected = math.ceil(o.LifeRecoverable / o.ColdTakenHit) - 1
		build.configTab.input.recoverySimulationWindow = 300
		build.configTab:BuildModList(); runCallback("OnFrame")
		o = build.calcsTab.calcsOutput
		assert.are.near(expected, o.RecoverySimulationTime, 1e-8)
	end)

	it("does not consume Ghost Shrouds on blocked hits", function()
		local mods = "Ghost Dance\n+10000 to maximum Life\n+1000 to maximum Energy Shield\n+1000 to Evasion Rating"
		local before = calculate(mods).RecoverySimulationShroudsUsed
		local after = calculate(mods.."\n+75% chance to Block Attack Damage")
		assert.is_true(after.RecoverySimulationShroudsUsed < before)
	end)

	it("supports separate Dissolution reservation and delayed Life loss", function()
		build.skillsTab:PasteSocketGroup("Petrified Blood 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		local out = calculate("Life that would be lost by taking Damage is instead Reserved")
		assert.is_nil(out.RecoverySimulationUnsupported)
		assert.are.near(2, out.RecoverySimulationTime, 1e-8)
	end)

	it("keeps actual life independent from Dissolution reservation", function()
		local state = { Life = 50, LifeReservation = 0 }
		local added, generic, delayed = time.reserveLife(state, 50, {life=100,maximum=100,prevent=0,below=40})
		assert.are.equal(30, added)
		assert.are.equal(20, delayed)
		assert.are.equal(0, generic)
		assert.are.equal(50, state.Life)
		assert.are.equal(30, state.LifeReservation)
	end)

	it("Eternal Youth recharges actual life without clearing reservation", function()
		local state = { Life=20, Mana=0, EnergyShield=0, LifeReservation=40 }
		local result = simulate({ actualDissolution=true,dissolution=true,reservationMax=100,pools=state,interval=20,window=1,
			caps={Life=50,Mana=0,EnergyShield=0},rechargeResource="Life",rechargeDelay=0,recharge=10,
			hit=function(p) p.LifeDamageReserved=0; return p end })
		assert.are.near(30,result.pools.Life,1e-8)
		assert.are.equal(40,result.pools.LifeReservation)
	end)

	it("can die to delayed loss after Dissolution reservation has been released", function()
		local result = simulate({ actualDissolution=true,dissolution=true,reservationMax=100,interval=20,window=4,
			pools={Life=50,Mana=0,EnergyShield=0},caps={Life=50,Mana=0,EnergyShield=0},
			hit=function(p,t)
				local added,generic,below = time.reserveLife(p,120,{life=100,maximum=100,prevent=0,below=40})
				p.LifeDamageReserved=added
				return p,{{Life=-(generic+below*0.81)/4,expires=t+4}},true
			end })
		assert.are.equal(false,result.survived)
		assert.are.near(28/9.72,result.time,1e-8)
		assert.are.equal(0,result.pools.LifeReservation)
	end)

	it("expires Wicked Ward's protection four seconds after recharge begins", function()
		local result = simulate({window=7,interval=3,wickedWard=true,recharge=20,rechargeDelay=2,step=math.huge,
			pools={Life=100,Mana=0,EnergyShield=100},caps={Life=100,Mana=0,EnergyShield=100},
			hit=function(p,t) p.EnergyShield=p.EnergyShield-(t==0 and 80 or 10); return p,{},true end})
		assert.are.near(80,result.pools.EnergyShield,1e-8)
	end)

	it("pays Eldritch Battery costs from ES before mana without partial payment", function()
		local pools = {Life=100,Mana=10,EnergyShield=10}
		assert.are.equal(true, time.payCost(pools, {Mana=15}, true))
		assert.are.equal(5, pools.Mana)
		assert.are.equal(0, pools.EnergyShield)
		assert.are.equal(false, time.payCost(pools, {Mana=10}, true))
		assert.are.equal(5, pools.Mana)
	end)

	it("removes ordinary leech at the current Dissolution unreserved maximum", function()
		local leech = time.leech({ Life={duration=5,rate=10,cap=20,full=100,reservation=true} })
		leech:add("Life",0)
		assert.is_nil(leech:rates(1,{Life=70,LifeReservation=30}).Life)
	end)

	it("skips native main-skill attacks when mana cannot pay their cost", function()
		build.skillsTab:PasteSocketGroup("Ethereal Knives 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		build.configTab.input.recoverySimulationAttacking = true
		local out = calculate("+10000 to maximum Life\nCannot Regenerate Mana")
		assert.is_true(out.RecoverySimulationAttackUptime > 0)
		assert.is_true(out.RecoverySimulationAttackUptime < 100)
	end)

	it("expires native flask defenses without changing the configured burst calculation", function()
		local item = new("Item"):Item("Rarity: Normal\nGranite Flask")
		build.itemsTab:AddItem(item)
		build.itemsTab.slots["Flask 1"].selItemId = item.id
		build.itemsTab.slots["Flask 1"].active = true
		calculate("+3000 to maximum Life")
		build.configTab.input.enemyColdDamage = "0"
		build.configTab.input.enemyPhysicalDamage = "100"
		build.configTab.input.recoverySimulationWindow = 60
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg, __mainObject__.promptMsg)
		local out = build.calcsTab.calcsOutput
		local timed, ehp = out.RecoverySimulationTime, out.TotalEHP
		build.configTab.input.recoverySimulationTimedEffects = false
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime > timed)
		assert.are.near(ehp, build.calcsTab.calcsOutput.TotalEHP, 1e-8)
	end)

	it("decays Elusive avoidance instead of holding its configured effect forever", function()
		build.configTab.input.buffElusive = true
		build.configTab.input.overrideBuffElusive = 500
		calculate("+3000 to maximum Life\nElusive\n900% increased Elusive Effect")
		build.configTab.input.enemyColdDamage = "500"
		build.configTab.input.recoverySimulationWindow = 60
		build.configTab.input.recoverySimulationTimedEffects = false
		build.configTab:BuildModList(); runCallback("OnFrame")
		local fixed = build.calcsTab.calcsOutput.RecoverySimulationTime
		assert.are.equal(75, build.calcsTab.calcsOutput.AvoidAllDamageFromHitsChance)
		build.configTab.input.recoverySimulationTimedEffects = true
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime < fixed)
	end)

	it("expires guard protection and supports a paid recast policy", function()
		build.skillsTab:PasteSocketGroup("Molten Shell 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		local out = calculate("+500 to maximum Life")
		assert(not __mainObject__.promptMsg, __mainObject__.promptMsg)
		local before = out.RecoverySimulationTime
		build.configTab.input.recoverySimulationRecastGuard = true
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg, __mainObject__.promptMsg)
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime > before)
	end)

	it("copies physical-prevention regeneration through Pious Path", function()
		build.configTab.input.conditionOnConsecratedGround = true
		local mods = "+300 to maximum Energy Shield\n+2000 to Armour\n100% less Energy Shield Recharge Rate\nLife recovery from regeneration is not applied\n3% of Physical Damage prevented from Hits in the past 4 seconds is Regenerated as Life per second"
		calculate(mods)
		build.configTab.input.enemyColdDamage = "0"
		build.configTab.input.enemyPhysicalDamage = "100"
		build.configTab.input.recoverySimulationWindow = 60
		build.configTab:BuildModList(); runCallback("OnFrame")
		local before = build.calcsTab.calcsOutput.RecoverySimulationTime
		build.configTab.input.customMods = "+100 to maximum Life\n"..mods.."\nConsecrated Ground you create causes Life Regeneration to also Recover Energy Shield for you and Allies"
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.is_true(build.calcsTab.calcsEnv.player.modDB:Flag(nil, "LifeRegenerationRecoversEnergyShield"))
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime > before)
	end)
end)
