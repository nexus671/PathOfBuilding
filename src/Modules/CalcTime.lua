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

-- Individual leech instances retain their own expiry; the total rate is capped.
-- Full is the unreserved pool, which can exceed a Petrified Blood recovery cap.
function M.leech(profiles)
	local instances = { }
	local leech = { }
	function leech:add(resource, t)
		local p = profiles[resource]
		if p and p.duration > 0 and p.rate > 0 then
			instances[#instances + 1] = { resource = resource, expires = t + p.duration }
		end
	end
	function leech:rates(t, pools)
		local rates, nextExpiry = { }, math.huge
		for i = #instances, 1, -1 do
			local instance = instances[i]
			local p = profiles[instance.resource]
			local full = p.reservation and p.full - (pools.LifeReservation or 0) or p.full
			if instance.expires <= t + 1e-9 or not p.persist and pools[instance.resource] >= full - 1e-9 then
				table.remove(instances, i)
			else
				rates[instance.resource] = (rates[instance.resource] or 0) + p.rate
				nextExpiry = min(nextExpiry, instance.expires)
			end
		end
		for resource, rate in pairs(rates) do rates[resource] = min(rate, profiles[resource].cap) end
		return rates, nextExpiry
	end
	return leech
end

function M.payCost(pools, cost, battery)
	local life, mana, es = max(0, cost.Life or 0), max(0, cost.Mana or 0), max(0, cost.EnergyShield or 0)
	if battery then
		local fromES = min(mana, max(0, pools.EnergyShield - es))
		mana, es = mana - fromES, es + fromES
	end
	if life >= pools.Life or mana > pools.Mana + 1e-9 or es > pools.EnergyShield + 1e-9 then return false end
	pools.Life, pools.Mana, pools.EnergyShield = pools.Life - life, max(0, pools.Mana - mana), max(0, pools.EnergyShield - es)
	return true
end

-- Dissolution reserves damage without treating healing as released reservation.
-- Delayed loss remains actual life loss and can kill independently of reservation.
function M.reserveLife(state, damage, config)
	local reserved = state.LifeReservation or 0
	local generic = damage * config.prevent / 100
	local immediate = damage - generic
	local aboveHalf = state.Life > config.life / 2 and max(0, config.maximum - reserved - config.life / 2) or 0
	local below = max(0, immediate - aboveHalf) * config.below / 100
	local added = immediate - below
	state.LifeReservation = reserved + added
	state.Life = min(state.Life, max(0, config.maximum - state.LifeReservation))
	return added, generic, below
end

-- Charge-limited use policy: use at expiry, starting with a full flask.
-- No kill charges are invented. Callers supply known passive generation only.
function M.flask(config)
	local charges, last, activeUntil = config.charges, 0, -math.huge
	local uses = 0
	return function(t, wanted)
		charges = min(config.charges, charges + (t - last) * (config.generation or 0))
		last = t
		local used = false
		if wanted and t >= activeUntil - 1e-9 and charges >= config.used and config.used > 0 then
			charges, activeUntil, uses, used = charges - config.used, t + config.duration, uses + 1, true
		end
		local nextEvent = t < activeUntil and activeUntil or config.generation and config.generation > 0 and t + max(0, config.used - charges) / config.generation or math.huge
		return t < activeUntil, used, nextEvent, uses
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
	local nextAttack, attempts, attacks = config.attack and 0 or math.huge, 0, 0
	local rechargeActive, rechargeBegan = false, -math.huge
	local reservationRelease = math.huge
	local cohorts = { }
	local resources = { "Life", "Mana", "EnergyShield" }
	local function result(survived, at)
		return { time = at, hits = hits, survived = survived, pools = pools, attacks = attacks, attempts = attempts }
	end
	while t <= window do
		if t >= reservationRelease - 1e-9 then
			if config.actualDissolution then pools.LifeReservation = 0
			else pools.Life = config.caps.Life end
			reservationRelease = math.huge
		end
		local external = config.before and config.before(pools, t) or math.huge
		if t >= nextHit - 1e-9 then
			local oldES, oldLife = pools.EnergyShield, pools.Life
			local added, interrupted
			pools, added, interrupted = config.hit(pools, t)
			hits = hits + 1
			if interrupted or pools.EnergyShield < oldES then
				if not (config.wickedWard and rechargeActive and t - rechargeBegan < 4 - 1e-9) then
					lastRechargeDamage, rechargeActive = t, false
				end
			end
			if config.dissolution and (config.actualDissolution and (pools.LifeDamageReserved or 0) > 0 or not config.actualDissolution and pools.Life < oldLife) then reservationRelease = t + 2 end
			if pools.Life <= 0 then return result(false, t) end
			for _, cohort in ipairs(added or { }) do cohorts[#cohorts + 1] = cohort end
			nextHit = nextHit + interval
		end
		if t >= nextAttack - 1e-9 then
			local paid
			pools, paid = config.attack(pools, t)
			attempts, attacks = attempts + 1, attacks + (paid and 1 or 0)
			if pools.Life <= 0 then return result(false, t) end
			local attackInterval = type(config.attackInterval) == "function" and config.attackInterval(pools, t) or config.attackInterval
			nextAttack = t + max(0.005, attackInterval)
		end
		if t >= window then break end
		local dt = min(config.step or 0.02, window - t, nextHit - t, nextAttack - t, reservationRelease - t, external - t)
		local rates = { }
		local baseRates = type(config.rates) == "function" and config.rates(pools, t) or config.rates or { }
		for _, resource in ipairs(resources) do rates[resource] = baseRates[resource] or 0 end
		for i = #cohorts, 1, -1 do
			local cohort = cohorts[i]
			if cohort.expires <= t + 1e-9 then table.remove(cohorts, i)
			else
				dt = min(dt, cohort.expires - t)
				for _, resource in ipairs(resources) do rates[resource] = rates[resource] + (cohort[resource] or 0) end
			end
		end
		if config.leech then
			local leechRates, expiry = config.leech:rates(t, pools)
			dt = min(dt, expiry - t)
			for _, resource in ipairs(resources) do rates[resource] = rates[resource] + (leechRates[resource] or 0) end
		end
		local delay = type(config.rechargeDelay) == "function" and config.rechargeDelay(pools, t) or config.rechargeDelay or math.huge
		local rechargeStart = lastRechargeDamage + delay
		if not rechargeActive and t >= rechargeStart - 1e-9 then rechargeActive, rechargeBegan = true, t end
		if rechargeActive then
			local resource = config.rechargeResource or "EnergyShield"
			local recharge = type(config.recharge) == "function" and config.recharge(pools, t) or config.recharge or 0
			rates[resource] = rates[resource] + recharge
		elseif rechargeStart < t + dt then dt = rechargeStart - t end
		-- Split when a pool reaches full so ordinary leech ends at the actual time.
		for _, resource in ipairs(resources) do
			if rates[resource] > 0 and pools[resource] < config.caps[resource] - 1e-9 then
				dt = min(dt, (config.caps[resource] - pools[resource]) / rates[resource])
			end
		end
		if rates.Life < 0 and pools.Life + rates.Life * dt <= 0 then
			local death = t - pools.Life / rates.Life
			pools.Life = 0
			return result(false, death)
		end
		for _, resource in ipairs(resources) do
			local cap = resource == "Life" and config.actualDissolution and min(config.caps.Life, config.reservationMax - (pools.LifeReservation or 0)) or config.caps[resource]
			local value = max(0, pools[resource] + rates[resource] * dt)
			pools[resource] = config.actualDissolution and resource == "Life" and min(cap, value) or min(max(cap, pools[resource]), value)
		end
		if dt <= 0 then error("Recovery timeline failed to advance") end
		t = min(window, t + dt)
	end
	return result(true, window)
end

return M
