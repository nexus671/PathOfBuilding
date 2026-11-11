-- Recovery trials run between UI frames; each recalculation replaces its job.
local M = { }
function M.start(tab, environments)
	local job = { cache = { cachedData = { MAIN = { }, CALCS = { }, CALCULATOR = { } } } }
	-- Auto-level and config placeholders can change while the frame is drawn.
	-- Projections keep the inputs of the core calculation they extend.
	for _, env in ipairs(environments) do
		local source = env.build
		local build = setmetatable({ characterLevel = env.player.level }, { __index = source })
		local config = source.configTab
		build.configTab = setmetatable({ build = build, input = copyTable(env.configInput), placeholder = copyTable(env.configPlaceholder),
			modList = config.modList, enemyModList = config.enemyModList, enemyLevel = config.enemyLevel }, { __index = config })
		build.calcsTab = setmetatable({ input = copyTable(env.calcsInput) }, { __index = source.calcsTab })
		env.recoveryBuild = build
		env.configInput = build.configTab.input
	end
	job.thread = coroutine.create(function()
		local function checkpoint()
			if os.clock() >= job.deadline then coroutine.yield() end
		end
		for _, env in ipairs(environments) do
			job.current = env
			env.recoveryDeferred = nil
			env.recoveryCheckpoint = checkpoint
			tab.calcs.recoveryOverTime(env, env.player)
			env.recoveryCheckpoint = nil
			env.player.output.RecoverySimulationPending = nil
		end
	end)
	tab.recoveryJob = job
	return job
end

function M.tick(tab, budget)
	local job = tab.recoveryJob
	if not job then return false end
	job.deadline = os.clock() + (budget or 0.006)
	local previousCache = GlobalCache
	GlobalCache = job.cache
	local ok, message = coroutine.resume(job.thread)
	job.cache = GlobalCache
	GlobalCache = previousCache
	if not ok then
		for _, env in ipairs({ tab.mainEnv, tab.calcsEnv }) do
			for key in pairs(env.player.output) do if key:match("^RecoverySimulation") or key:match("^RecoveryComparison") then env.player.output[key] = nil end end
			env.player.recoverySimulationResults, env.player.recoverySimulationTrace = nil, nil
			env.player.output.RecoverySimulationUnsupported = true
			if env.player.breakdown then env.player.breakdown.RecoverySimulationUnsupported = { "Recovery calculation failed: "..tostring(message) } end
		end
	end
	if not ok or coroutine.status(job.thread) == "dead" then
		tab.recoveryJob = nil
		return true
	end
	return false
end
return M
