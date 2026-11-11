-- Calculations over a finite combat window.
-- These do not replace burst EHP or the existing steady-state DPS outputs.
local M = { }
local min, max = math.min, math.max

-- Local RNG: reproducible trials without changing Lua's global random state.
function M.random(seed)
	return function()
		seed = seed * 16807 % 2147483647
		return (seed - 1) / 2147483646
	end
end

-- Evasion shares one entropy counter across attackers. Dodge/block use rolls.
-- Reset entropy after an attack-free gap; callers pass actual attempt times.
function M.evasion(random)
	local entropy, lastAttack
	return function(chanceToHit, t)
		if not lastAttack or t - lastAttack > 100 / 30 then entropy = random() * 100 end
		lastAttack = t
		entropy = entropy + min(100, max(0, chanceToHit))
		if entropy >= 100 then entropy = entropy - 100; return true end
		return false
	end
end

function M.shrouds(initial)
	local count, tick = min(3, max(0, initial or 3)), 0
	return function(t, eligible)
		local now = math.floor(t / 2 + 1e-9)
		count, tick = min(3, count + now - tick), now
		if eligible and count > 0 then count = count - 1; return true, count end
		return false, count
	end
end

function M.summarise(results)
	local times, survived, incoming = { }, 0, 0
	for _, result in ipairs(results) do
		times[#times + 1] = result.time
		survived = survived + (result.survived and 1 or 0)
		incoming = incoming + (result.incoming or 0)
	end
	table.sort(times)
	local function percentile(p) return times[max(1, math.ceil(#times * p))] end
	return { time = percentile(0.5), low = percentile(0.1), high = percentile(0.9),
		survived = survived == #results, chance = survived / #results * 100, incoming = incoming / #results }
end

-- Each poison stream ramps linearly to its own stack/duration limit. Integrate
-- the sum piecewise, applying the shared DoT cap before taking the integral.
function M.poisonWindow(profiles, seconds, cap)
	seconds = max(0, seconds)
	cap = cap or math.huge
	local points = { 0, seconds }
	local function dps(t)
		local sum = 0
		for _, p in ipairs(profiles) do
			sum = sum + min(max(0, p.slope) * t, max(0, p.ceiling))
		end
		return sum
	end
	local ramp = 0
	for _, p in ipairs(profiles) do
		if p.slope > 0 then
			local stop = p.ceiling / p.slope
			ramp = max(ramp, stop)
			if stop > 0 and stop < seconds then points[#points + 1] = stop end
		end
	end
	table.sort(points)
	local damage = 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local low, high = dps(a), dps(b)
		if low >= cap then
			damage = damage + cap * (b - a)
		elseif high > cap then
			local crossing = a + (b - a) * (cap - low) / (high - low)
			damage = damage + (low + cap) / 2 * (crossing - a) + cap * (b - crossing)
		else
			damage = damage + (low + high) / 2 * (b - a)
		end
	end
	return { dps = min(cap, dps(seconds)), damage = damage, average = seconds > 0 and damage / seconds or 0, ramp = ramp }
end

-- The hit callback uses PoB's pool reduction and returns recovery/loss cohorts.
-- A cohort has rates by resource and an expiry time; overlapping cohorts add.
-- Rates are integrated between hits, expiries and recharge/reservation events.
-- An optional step limit is useful for comparing integration resolutions.
function M.survival(config)
	local pools = config.pools
	local window = min(max(config.window or 60, 0), 300)
	local interval = config.interval
	assert(interval and interval >= 0.02, "hit interval must be at least 20ms")
	local t, nextHit, hits, lastRechargeDamage = 0, 0, 0, 0
	local reservationRelease = math.huge
	local cohorts = { }
	local resources = { "Life", "Mana", "EnergyShield" }
	while t <= window do
		if t >= reservationRelease - 1e-9 then
			pools.Life, reservationRelease = config.caps.Life, math.huge
		end
		if t >= nextHit - 1e-9 then
			local oldES = pools.EnergyShield
			local oldLife = pools.Life
			local added, rechargeInterrupted
			pools, added, rechargeInterrupted = config.hit(pools, t)
			hits = hits + 1
			if rechargeInterrupted or pools.EnergyShield < oldES then lastRechargeDamage = t end
			if config.dissolution and pools.Life < oldLife then reservationRelease = t + 2 end
			if pools.Life <= 0 then return { time = t, hits = hits, survived = false, pools = pools } end
			for _, cohort in ipairs(added or { }) do cohorts[#cohorts + 1] = cohort end
			nextHit = nextHit + interval
		end
		if t >= window then break end
		local dt = min(config.step or 0.02, window - t, nextHit - t, reservationRelease - t)
		local rates = { }
		for _, resource in ipairs(resources) do rates[resource] = (config.rates or { })[resource] or 0 end
		for i = #cohorts, 1, -1 do
			local cohort = cohorts[i]
			if cohort.expires <= t + 1e-9 then
				table.remove(cohorts, i)
			else
				dt = min(dt, cohort.expires - t)
				for _, resource in ipairs(resources) do rates[resource] = rates[resource] + (cohort[resource] or 0) end
			end
		end
		local rechargeStart = lastRechargeDamage + (config.rechargeDelay or math.huge)
		if t >= rechargeStart - 1e-9 then
			rates.EnergyShield = rates.EnergyShield + (config.recharge or 0)
		elseif rechargeStart < t + dt then
			dt = rechargeStart - t
		end
		if rates.Life < 0 and pools.Life + rates.Life * dt <= 0 then
			return { time = t - pools.Life / rates.Life, hits = hits, survived = false, pools = pools }
		end
		for _, resource in ipairs(resources) do
			pools[resource] = min(config.caps[resource], max(0, pools[resource] + rates[resource] * dt))
		end
		t = min(window, t + dt)
	end
	return { time = window, hits = hits, survived = true, pools = pools }
end

return M
