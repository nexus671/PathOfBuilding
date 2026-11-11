describe("Desktop encounter reports", function()
	local report = require("Modules.EncounterReport")
	local json = require("dkjson")
	before_each(function() newBuild() end)
	local function calculate()
		local input = build.configTab.input
		input.simulateRecovery = true
		input.recoverySimulationTrials = 1
		input.recoverySimulationWindow = 5
		input.enemyDamageType = "Melee"
		input.enemySpeed = 1000
		input.enemyIsBoss = "None"
		input.enemyCritChance = 0
		for _,kind in ipairs({"Physical","Lightning","Cold","Fire","Chaos"}) do input["enemy"..kind.."Damage"] = kind == "Cold" and "10000" or "0" end
		input.customMods = "+1000 to maximum Life\n+60% to Cold Resistance"
		build.configTab:BuildModList(); runCallback("OnFrame")
	end

	it("captures the lethal hit before post-hit recovery and preserves exact pool evidence", function()
		calculate()
		local captured = report.capture(build)
		local actor = build.calcsTab.calcsEnv.player
		local detail = captured.trace.deathDetails
		assert.are.equal("desktop-explicit-snapshot",captured.source)
		assert.are.equal(actor.recoverySimulationResults[1].deathCause,detail.event)
		assert.are.equal(0,detail.time)
		assert.is_true(detail.before.Life > 0)
		assert.is_true(detail.after.Life <= 0)
		assert.is_true(detail.damage.Cold > detail.before.Life)
		assert.is_true(detail.recoveryAfterHitSkipped)
		assert.are.equal(build.calcsTab.calcsOutput.enemySkillTime,captured.incoming.interval)
		assert.is_truthy(report.deathLines(captured)[5]:find("before on%-block"))
	end)

	it("detaches report data and serializes only finite values", function()
		calculate()
		build.calcsTab.calcsOutput.RecoverySimulationUnbounded = math.huge
		local captured = report.capture(build)
		local decoded,_,err = json.decode(json.encode(captured))
		assert.is_nil(err)
		assert.is_nil(decoded.summary.Unbounded)
		captured.trace.deathDetails.before.Life = -123
		assert.is_true(build.calcsTab.calcsEnv.player.recoverySimulationTrace.deathDetails.before.Life > 0)
	end)

	it("clears the previous trial when simulation is disabled", function()
		calculate()
		build.configTab.input.simulateRecovery = false
		build.configTab:BuildModList(); runCallback("OnFrame")
		local captured = report.capture(build)
		assert.is_nil(captured.trace)
		assert.is_nil(captured.summary.SurvivalChance)
		assert.is_truthy(report.deathLines(captured)[1]:find("Enable the simulation"))
	end)

	it("refuses to export a pending calculation", function()
		local ok,err = report.write({calculationPending=true},"unused-report.json")
		assert.is_nil(ok)
		assert.is_truthy(err:find("pending"))
	end)

	it("opens a joined workspace and clamps run inputs to native limits", function()
		calculate()
		build.calcsTab:OpenEncounterWorkspace()
		local popup = main.popups[1]
		assert.are.equal("Encounter simulation",popup.title)
		popup:Draw({x=0,y=0,width=1920,height=1080})
		assert.is_truthy(popup.controls.compare.list[popup.controls.compare.selIndex])
		popup.controls.ai:Click()
		assert.are.equal("AI tools",main.popups[1].title)
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main:ClosePopup()
		popup.controls.window:SetText("9999")
		popup.controls.trials:SetText("9999")
		popup.controls.trial:SetText("9999")
		popup.controls.run:Click()
		assert.are.equal(300,build.configTab.input.recoverySimulationWindow)
		assert.are.equal(128,build.configTab.input.recoverySimulationTrials)
		assert.are.equal(128,build.configTab.input.recoverySimulationTraceTrial)
		popup.controls.events:Click()
		local log = build.calcsTab.controls.breakdown
		log:Draw({x=310,y=56,width=1610,height=1024})
		assert.is_true(log.x >= 310)
		assert.is_true(log.y >= 56)
		build.calcsTab:ClearDisplayStat()
	end)

	it("generates MCP setup without shell interpolation", function()
		local config = json.decode(report.mcpConfig("C:/PoB/AI/McpServer.cjs","C:/My Builds/AI-encounter.json"))
		assert.are.equal("node",config.mcpServers["pob-ai-edition"].command)
		assert.are.equal("C:/My Builds/AI-encounter.json",config.mcpServers["pob-ai-edition"].args[2])
	end)
end)
