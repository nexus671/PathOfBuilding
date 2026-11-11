-- Expected-value calculations over a finite combat window.
-- These do not replace burst EHP or the existing steady-state DPS outputs.
local M = { }
local min, max = math.min, math.max

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
-- Recovery is integrated in <=20ms steps, split exactly at hits and expiries.
function M.survival(config)
	local pools = config.pools
	local window = min(max(config.window or 60, 0), 300)
	local interval = config.interval
	assert(interval and interval >= 0.02, "hit interval must be at least 20ms")
	local t, nextHit, hits, lastESLoss = 0, 0, 0, 0
	local cohorts = { }
	local resources = { "Life", "Mana", "EnergyShield" }
	while t <= window do
		if t >= nextHit - 1e-9 then
			local oldES = pools.EnergyShield
			local added, esDamaged
			pools, added, esDamaged = config.hit(pools, t)
			hits = hits + 1
			if esDamaged or pools.EnergyShield < oldES then lastESLoss = t end
			if pools.Life <= 0 then return { time = t, hits = hits, survived = false, pools = pools } end
			for _, cohort in ipairs(added or { }) do cohorts[#cohorts + 1] = cohort end
			nextHit = nextHit + interval
		end
		if t >= window then break end
		local dt = min(config.step or 0.02, window - t, nextHit - t)
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
		local rechargeStart = lastESLoss + (config.rechargeDelay or math.huge)
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
