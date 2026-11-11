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
		return build.calcsTab.calcsOutput
	end

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

	it("rejects unsupported Ward scenarios explicitly", function()
		local out = calculate("+100 to Ward")
		assert.are.equal(true, out.RecoverySimulationUnsupported)
		assert.is_nil(out.RecoverySimulationTime)
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
end)
