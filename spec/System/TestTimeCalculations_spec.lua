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

	it("tracks Crab Barrier ticks, partial losses and recent-loss protection", function()
		local crab = time.crab({ maximum=12, initial=12, loss=5, protect=true }, function() return 1 end)
		assert.are.equal(7, crab(0, true))
		assert.are.equal(8, crab(0.5, true))
		assert.are.equal(12, crab(3.99, true))
		assert.are.equal(7, crab(4, true))
		local all = time.crab({ maximum=10 }, function() return 1 end)
		assert.are.equal(0, all(0, true))
		assert.are.equal(0, all(0.49, false))
		assert.are.equal(1, all(0.5, false))
		local gain = time.crab({ maximum=10, initial=0, maximumChance=100 }, function() return 0 end)
		assert.are.equal(10, gain(0.5, false))
	end)

	it("routes simultaneous DoTs through ES, bypass and empty-pool recovery", function()
		local cfg = { bypass={ Fire=0, Chaos=100 }, mom={ Fire=50, Chaos=50 } }
		local p = { Life=100, Mana=100, EnergyShield=100 }
		local r = time.dotRates(p, {}, { Fire=100, Chaos=100 }, cfg)
		assert.are.equal(100, r.EnergyShield); assert.are.equal(50, r.Mana); assert.are.equal(50, r.Life)
		p.EnergyShield, p.Mana = 0, 0
		r = time.dotRates(p, { EnergyShield=20, Mana=30 }, { Fire=100, Chaos=100 }, cfg)
		assert.are.equal(20, r.EnergyShield); assert.are.equal(30, r.Mana); assert.are.equal(150, r.Life)
		cfg.battery = true; p.EnergyShield, p.Mana = 100, 100
		r = time.dotRates(p, {}, { Fire=100, Chaos=100 }, cfg)
		assert.are.equal(50, r.EnergyShield); assert.are.equal(50, r.Mana); assert.are.equal(100, r.Life)
	end)

	it("recalculates native mitigation when Crab Barriers are lost", function()
		build.configTab.input.recoverySimulationTrials=1
		calculate("+1000 to maximum Life\n+10 to Maximum number of Crab Barriers\n2% additional Physical Damage Reduction per Crab Barrier\nYou only lose 5 Crab Barriers when you take Physical Damage from a Hit\nCannot lose Crab Barriers if you have lost Crab Barriers Recently\n10% chance that if you would gain a Crab Barrier, you instead gain up to your maximum number of Crab Barriers")
		build.configTab.input.enemyColdDamage="0"; build.configTab.input.enemyPhysicalDamage="300"
		build.configTab.input.recoverySimulationWindow=30
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		local o=build.calcsTab.calcsOutput
		assert.are.equal(10,o.CrabBarriers)
		assert.is_true(o.RecoverySimulationCrabLost > 0)
		local mods=build.calcsTab.calcsEnv.player.modDB
		assert.are.equal(5,mods:Override(nil,"CrabBarriersLost"))
		assert.is_true(mods:Flag(nil,"CrabBarriersProtectedRecently"))
		assert.are.equal(10,mods:Sum("BASE",nil,"CrabBarriersGainMaximumChance"))
		local timed=o.RecoverySimulationTime
		build.configTab.input.recoverySimulationTimedEffects=false
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime >= timed)
	end)

	it("splits DoT routing exactly at ES depletion and prevents recharge", function()
		for _,step in ipairs({ math.huge, 0.013 }) do
			local r = simulate({ step=step, window=10, interval=100, pools={ Life=100, Mana=0, EnergyShield=50 },
				caps={ Life=100, Mana=0, EnergyShield=50 }, recharge=100, rechargeDelay=1, hit=function(p) return p end,
				dot=function(p,rates) return time.dotRates(p,rates,{ Fire=25 },{ bypass={}, mom={} }) end })
			assert.are.equal(false, r.survived)
			assert.are.near(6, r.time, 1e-7)
		end
	end)

	it("lets empty ES regeneration absorb part of continuous damage without oscillation", function()
		local r = simulate({ step=math.huge, interval=100, pools={ Life=100, Mana=0, EnergyShield=0 },
			caps={ Life=100, Mana=0, EnergyShield=50 }, rates={ EnergyShield=10 }, hit=function(p) return p end,
			dot=function(p,rates) return time.dotRates(p,rates,{ Fire=30 },{ bypass={}, mom={} }) end })
		assert.are.near(5, r.time, 1e-7)
		assert.are.near(0, r.pools.EnergyShield, 1e-7)
	end)

	it("reserves continuous damage with Dissolution without using hit prevention", function()
		local r = simulate({ step=math.huge, interval=100, actualDissolution=true, dissolution=true, reservationMax=100,
			rates={ Life=1000 }, hit=function(p) return p end,
			dot=function() return { Life=25, Mana=0, EnergyShield=0 } end })
		assert.are.equal(false, r.survived)
		assert.are.near(4, r.time, 1e-7)
		assert.are.near(100, r.pools.LifeReservation, 1e-7)
	end)

	it("keeps Eternal Youth running until DoT reservation clamps actual life", function()
		local r=simulate({ window=2, step=math.huge, interval=100, actualDissolution=true, dissolution=true, reservationMax=100,
			pools={Life=10,Mana=0,EnergyShield=0}, recharge=10,rechargeDelay=0,rechargeResource="Life",hit=function(p) return p end,
			dot=function() return { Life=25,Mana=0,EnergyShield=0 } end })
		assert.are.near(30,r.pools.Life,1e-7)
		assert.are.near(50,r.pools.LifeReservation,1e-7)
	end)

	it("protects active Wicked Ward recharge from continuous damage for four seconds", function()
		local r=simulate({ window=5,step=math.huge,interval=100,wickedWard=true,recharge=50,rechargeDelay=0,
			pools={Life=100,Mana=0,EnergyShield=0},caps={Life=100,Mana=0,EnergyShield=100},hit=function(p) return p end,
			dot=function(p,rates) return time.dotRates(p,rates,{Fire=25},{bypass={},mom={}}) end })
		assert.are.near(75,r.pools.EnergyShield,1e-7)
		assert.are.equal(100,r.pools.Life)
	end)

	it("reacts with finite instant-flask charges and cancels an unneeded pending use", function()
		local flask = time.recoveryFlask({ charges=20, used=10, resources={Life=true}, threshold=0.5, reaction=0.1 })
		local p, full = {Life=20}, {Life=100}
		local function profile() return { Life={ instant=60, rate=0 } }, 2 end
		local _,_,event,uses = flask(0,p,full,full,profile)
		assert.are.near(0.1,event,1e-8); assert.are.equal(0,uses)
		flask(0.1,p,full,full,profile); assert.are.equal(80,p.Life)
		p.Life=20; flask(1,p,full,full,profile); p.Life=80
		flask(1.1,p,full,full,profile)
		p.Life=20; flask(2,p,full,full,profile); flask(2.1,p,full,full,profile)
		assert.are.equal(80,p.Life)
		p.Life=20; flask(3,p,full,full,profile); flask(4,p,full,full,profile)
		assert.are.equal(20,p.Life)
	end)

	it("ends gradual flasks at full and retains enduring recovery", function()
		for _,enduring in ipairs({false,true}) do
			local flask = time.recoveryFlask({ charges=10, used=10, resources={Life=true}, threshold=1, reaction=0 })
			local p, full = {Life=20}, {Life=100}
			local function profile() return { Life={ rate=20, enduring=enduring } }, 5 end
			local active = flask(0,p,full,full,profile); assert.are.equal(true,active)
			p.Life=100; active = flask(1,p,full,full,profile); assert.are.equal(enduring,active)
		end
	end)

	it("allows flask recovery above PB's cap without raising the non-flask cap", function()
		local r = simulate({ window=2, interval=100, pools={Life=40,Mana=0,EnergyShield=0}, caps={Life=50,Mana=0,EnergyShield=0},
			rates={Life=1000}, hit=function(p) return p end,
			flaskRecovery=function() return {Life=10},{Life=100,Mana=0,EnergyShield=0} end })
		-- Reach 50 using both sources; only the flask may heal above 50.
		assert.are.near(50 + 10 * (2 - 10 / 1010),r.pools.Life,1e-7)
	end)

	it("accepts native DoT-only and mixed DoT scenarios without changing burst EHP", function()
		local o = calculate("+1000 to maximum Life\n+200 to maximum Energy Shield")
		local ehp, before = o.TotalEHP, o.RecoverySimulationTime
		build.configTab.input.recoverySimulationChaosDot=1000
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		o=build.calcsTab.calcsOutput
		assert.are.near(ehp,o.TotalEHP,1e-8)
		assert.is_true(o.RecoverySimulationTime < before)
		build.configTab.input.enemyDamageType="DamageOverTime"
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		assert.is_true(not build.calcsTab.calcsOutput.RecoverySimulationUnsupported)
	end)

	it("activates a native instant recovery flask without editing its checkbox", function()
		local item=new("Item"):Item("Rarity: Magic\nSeething Divine Life Flask\nDivine Life Flask\n66% reduced Amount Recovered\nInstant Recovery")
		build.itemsTab:AddItem(item); build.itemsTab.slots["Flask 1"].selItemId=item.id
		build.itemsTab.slots["Flask 1"].active=false
		build.configTab.input.recoverySimulationTrials=1
		local o=calculate("+1000 to maximum Life\nCannot Regenerate Life")
		build.configTab.input.recoverySimulationWindow=60
		build.configTab:BuildModList(); runCallback("OnFrame")
		o=build.calcsTab.calcsOutput
		local before=o.RecoverySimulationTime
		build.configTab.input.recoverySimulationEquippedFlasks=true
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		assert.is_true(not build.calcsTab.calcsOutput.RecoverySimulationUnsupported)
		assert.is_true(build.calcsTab.calcsOutput.RecoverySimulationTime > before)
		assert.are.equal(false,build.itemsTab.slots["Flask 1"].active)
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
