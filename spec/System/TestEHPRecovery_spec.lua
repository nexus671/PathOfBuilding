describe("EHP recovery and damage avoidance", function()
	before_each(function()
		newBuild()
	end)

	local function calculate(mods, damage, category)
		build.configTab.input.enemyDamageType = category or "Melee"
		build.configTab.input.enemyIsBoss = "None"
		build.configTab.input.enemyCritChance = 0
		for _, damageType in ipairs({ "Physical", "Fire", "Cold", "Lightning", "Chaos" }) do
			build.configTab.input["enemy"..damageType.."Damage"] = damageType == "Cold" and tostring(damage or 1980) or "0"
		end
		build.configTab.input.customMods = "+60% to Cold Resistance\n"..mods
		build.configTab:BuildModList()
		runCallback("OnFrame")
		return build.calcsTab.calcsOutput
	end

	it("does not lower EHP when recovery increases with Petrified Blood and ES", function()
		build.skillsTab:PasteSocketGroup("Petrified Blood 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		build.configTab.input.conditionLowLife = true
		local previous = 0
		for gain = 250, 500 do
			local out = calculate("+4264 to maximum Life\n+3000 to maximum Energy Shield\n+68% chance to Block Attack Damage\n+"..gain.." Life gained when you Block")
			assert.is_true(out.LifeRecoverable <= out.Life / 2)
			assert.is_true(out.TotalEHP >= previous, string.format("EHP fell at %d recovery: %.2f -> %.2f", gain, previous, out.TotalEHP))
			previous = out.TotalEHP
		end
	end)

	it("counts recovery builds surviving more than the acceleration iteration limit", function()
		local out = calculate("+10000 to maximum Life\n+75% chance to Block Attack Damage\n+132 Life gained when you Block", 400)
		-- Each hit removes 100 Life and then restores 99. Only the fatal hit
		-- receives no recovery; its overkill is apportioned to the final hit.
		local fullHits = math.ceil(out.LifeRecoverable - 99)
		local expected = fullHits - 1 + (out.LifeRecoverable - (fullHits - 1)) / 100
		assert.is_true(expected > data.misc.ehpCalcMaxIterationsToCalc)
		assert.are.near(expected, out.NumberOfMitigatedDamagingHits, 0.0001)
	end)

	it("recognises sustainable recovery after finite energy shield is exhausted", function()
		local out = calculate("+1000 to maximum Life\n+1000 to maximum Energy Shield\n+75% chance to Block Attack Damage\n+200 Life gained when you Block", 400)
		assert.are.equal(math.huge, out.NumberOfMitigatedDamagingHits)
	end)

	it("does not apply recovery after a fatal hit", function()
		local out = calculate("+75% chance to Block Attack Damage\n+100000 Life gained when you Block", 10000)
		assert.is_true(out.NumberOfMitigatedDamagingHits < math.huge)
	end)

	it("adds all-damage and type-specific avoidance and caps their sum", function()
		local out = calculate("+1000 to maximum Life\n32% chance to Avoid all Damage from Hits\n15% chance to Avoid Cold Damage from Hits")
		assert.are.equal(47, out.AvoidColdDamageChance)
		assert.are.equal(32, out.AvoidPhysicalDamageChance)
		assert.are.equal(0, out.ConfiguredNotHitChance)
		out = calculate("+1000 to maximum Life\n65% chance to Avoid all Damage from Hits\n30% chance to Avoid Cold Damage from Hits")
		assert.are.equal(75, out.AvoidColdDamageChance)
	end)

	it("applies all-damage avoidance once as damage avoidance", function()
		local all = calculate("+1000 to maximum Life\n32% chance to Avoid all Damage from Hits").TotalEHP
		local specific = calculate("+1000 to maximum Life\n32% chance to Avoid Cold Damage from Hits").TotalEHP
		assert.are.equal(all, specific)
	end)

	it("keeps projectile hit avoidance independent of additive damage avoidance", function()
		local out = calculate("+1000 to maximum Life\n10% chance to Avoid Projectiles\n32% chance to Avoid all Damage from Hits\n15% chance to Avoid Cold Damage from Hits", nil, "SpellProjectile")
		assert.are.equal(47, out.AvoidColdDamageChance)
		assert.are.near(10, out.ConfiguredNotHitChance, 0.0001)
	end)

	it("averages attack evasion and spell block jointly (issue 8983)", function()
		local mods = "+1000 to maximum Life\n75% chance to evade attacks\n75% chance to block spell damage"
		local average = calculate(mods, 400, "Average").TotalEHP
		local melee = calculate(mods, 400, "Melee").TotalEHP
		local spell = calculate(mods, 400, "Spell").TotalEHP
		assert.are.near(melee, average, 0.01)
		assert.are.near(spell, average, 0.01)
	end)

	it("keeps spell block and suppression on the spell share of Average hits", function()
		for _, suppression in ipairs({ 0, 50, 100 }) do
			local out = calculate("+1000 to maximum Life\n75% chance to evade attacks\n75% chance to block spell damage\n+"..suppression.."% chance to Suppress Spell Damage", 400, "Average")
			-- Half the attempts are attacks (25% connect), half are spells
			-- (25% pass block, then suppression prevents its configured portion).
			local effect = out.SpellSuppressionEffect / 100
			local damageFraction = (0.25 + 0.25 * (1 - suppression / 100 * effect)) / 2
			local embeddedSuppression = suppression == 100 and (1 - effect / 2) or 1
			assert.are.near(damageFraction, out.ConfiguredDamageChance / 100 * (1 - out.ConfiguredNotHitChance / 100) * embeddedSuppression, 0.000001)
		end
	end)

	it("weights unlucky avoidance within each Average hit category", function()
		build.configTab.input.EHPUnluckyWorstOf = 2
		local out = calculate("+1000 to maximum Life\n75% chance to evade attacks\n75% chance to block spell damage", 400, "Average")
		assert.are.near(1 - 0.75 ^ 2, out.ConfiguredDamageChance / 100 * (1 - out.ConfiguredNotHitChance / 100), 0.000001)
	end)

	it("does not grant spell-block recovery for attack blocks in Average mode", function()
		local mods = "+1000 to maximum Life\n+1000 to maximum Energy Shield\n75% chance to block attack damage"
		local without = calculate(mods, 400, "Average").TotalEHP
		local with = calculate(mods.."\nRecover 1000 Energy Shield when you Block Spell Damage", 400, "Average")
		assert.are.equal(1000, with.EnergyShieldOnSpellBlock)
		assert.are.equal(without, with.TotalEHP)
	end)
end)
