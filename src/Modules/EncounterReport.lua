-- A bounded, factual snapshot shared by the desktop workspace and AI clients.
local json = require("dkjson")
local M = { }

local function clean(value, depth)
	if type(value) == "number" then return value == value and math.abs(value) < math.huge and value or nil end
	if type(value) == "string" or type(value) == "boolean" then return value end
	if type(value) ~= "table" or (depth or 0) > 8 then return nil end
	local result = { }
	for key,entry in pairs(value) do
		if type(key) == "string" or type(key) == "number" then result[key] = clean(entry, (depth or 0) + 1) end
	end
	return result
end

function M.capture(build)
	local env = build.calcsTab.calcsEnv
	local actor = env and env.player or { }
	local output, breakdown = actor.output or { }, actor.breakdown or { }
	local summary, settings, comparison = { }, { }, { }
	for key,value in pairs(output) do
		if key:match("^RecoverySimulation") and type(value) ~= "table" then summary[key:gsub("^RecoverySimulation", "")] = value end
		if key:match("^RecoveryComparison") and type(value) ~= "table" then comparison[key:gsub("^RecoveryComparison", "")] = value end
	end
	for key,value in pairs(build.configTab.input) do
		if key:match("^recoverySimulation") or key:match("^enemy.*Damage$") or key == "enemyDamageType" or key == "enemySpeed" or key == "simulateRecovery" then settings[key] = value end
	end
	local config = build.configTab.configSets[build.configTab.activeConfigSetId]
	local incoming = { interval=output.enemySkillTime, rawHitDamage=output.totalEnemyDamageIn, afterEnemyModifiers={ } }
	for _,kind in ipairs({ "Physical", "Lightning", "Cold", "Fire", "Chaos" }) do incoming.afterEnemyModifiers[kind] = output[kind.."EnemyDamage"] end
	return clean({ schemaVersion=1, capturedAt=os.date("!%Y-%m-%dT%H:%M:%SZ"), source="desktop-explicit-snapshot", calculationPending=build.buildFlag or false,
		build={ name=build.buildName, configuration=config and config.title, skill=actor.mainSkill and actor.mainSkill.activeEffect and actor.mainSkill.activeEffect.grantedEffect.name },
		settings=settings, summary=summary, comparison=comparison, trace=actor.recoverySimulationTrace,
		incoming=incoming,
		comparisonUnsupported=breakdown.RecoveryComparisonUnsupported and breakdown.RecoveryComparisonUnsupported[1],
		comparisonAssumptions=breakdown.RecoveryComparisonSurvivalDelta,
		checks=breakdown.RecoverySimulationWarnings and breakdown.RecoverySimulationWarnings.rowList or { },
		unsupported=breakdown.RecoverySimulationUnsupported and breakdown.RecoverySimulationUnsupported[1],
		assumptions=breakdown.RecoverySimulationTime or { },
		limitations={ "This is an explicitly refreshed snapshot, not a live connection. Refresh after changing the build or configuration.",
			"The chart is one selected trial. Survival estimates describe only the configured encounter and implemented mechanics.",
			"A terminal event and the preceding resource history do not establish that a proposed upgrade would prevent death." } })
end

function M.deathLines(report)
	local trace = report.trace
	if report.unsupported then return { "Simulation unavailable: "..report.unsupported } end
	if not trace then return { "Enable the simulation and run an encounter to inspect a trial." } end
	local lines = { string.format("Trial %d: %s at %.3fs", trace.trial, trace.cause and "died" or "window reached alive", trace.time) }
	if trace.cause then lines[#lines + 1] = "Terminal event: "..trace.cause end
	local death = trace.deathDetails
	if death then
		local before = death.before
		lines[#lines + 1] = string.format("Before the hit: Life %.0f | ES %.0f | Mana %.0f | Ward %.0f | Guard %.0f", before.Life,before.EnergyShield,before.Mana,before.Ward,before.Guard)
		lines[#lines + 1] = string.format("After the hit: ES %.0f | Mana %.0f | Ward %.0f", death.after.EnergyShield,death.after.Mana,death.after.Ward)
		lines[#lines + 1] = "The hit was lethal before on-block/on-suppress recovery, Ghost Shrouds or new recoup could apply."
	elseif trace.cause then
		lines[#lines + 1] = "Inspect the preceding events and recovery assumptions for the resource loss contributing to this death."
	end
	return lines
end

function M.brief(report, task)
	return (task or "Explain this encounter's outcome and the main assumptions to check.")
		.."\nUse only the captured facts. Separate observations from hypotheses. Suggest small paired experiments; do not promise that a change prevents death.\n"
		..json.encode(report, { indent=true })
end

function M.write(report, path)
	if report.calculationPending then return nil, "Calculation pending. Wait for the result, then refresh again." end
	local file, err = io.open(path, "wb")
	if not file then return nil, err end
	local ok, writeErr = file:write(json.encode(report))
	local closed, closeErr = file:close()
	return ok and closed, writeErr or closeErr
end

function M.mcpConfig(serverPath, reportPath)
	return json.encode({ mcpServers={ ["pob-ai-edition"]={ command="node", args={serverPath,reportPath} } } }, { indent=true })
end

return M
