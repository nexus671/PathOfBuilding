-- Calculations over a finite combat window.
-- These do not replace burst EHP or the existing steady-state DPS outputs.
local M = { }
local encounter = require("Modules.CalcEncounter")
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

-- A tincture starts with no burn. Deactivation clears burn and starts cooldown;
-- recovering its resource cannot bypass that cooldown. Reuse is a manual policy.
function M.tincture(config, random)
	local state = { active = false, stacks = 0, ready = 0, tick = math.huge, uses = 0, effect = false, lingerUntil = -math.huge }
	local function deactivate(self, t)
		self.lingerUntil = t + min(config.lingerMax or 0, self.stacks * (config.lingerPerStack or 0))
		self.active, self.stacks, self.tick, self.ready = false, 0, math.huge, t + config.cooldown
	end
	function state:hit(t)
		if self.active and config.onHit then
			if random() * 100 >= (config.skipChance or 0) then self.stacks = self.stacks + 1 end
			if config.maximum and self.stacks >= config.maximum then deactivate(self,t) end
		end
	end
	function state:update(t, resource)
		local event
		if self.active and resource <= (config.floor or 0) + 1e-8 then
			deactivate(self,t)
			event = "Tincture deactivated: resource exhausted; cooldown started"
		end
		if self.active and t >= self.tick - 1e-9 then
			self.tick = self.tick + config.interval
			if random() * 100 >= (config.skipChance or 0) then self.stacks = self.stacks + 1 end
			if config.maximum and self.stacks >= config.maximum then
				deactivate(self,t)
				event = "Tincture deactivated: Mana Burn limit; cooldown started"
			end
		end
		if not self.active and (self.uses == 0 or config.reuse) and t >= self.ready - 1e-9 and resource > (config.floor or 0) + 1e-8 then
			self.active, self.stacks, self.tick, self.uses = true, 0, config.onHit and math.huge or t + config.interval, self.uses + 1
			event = "Tincture activated"
		end
		local nextEvent = self.active and self.tick or config.reuse and self.ready > t + 1e-9 and self.ready or math.huge
		self.effect = self.active or t < self.lingerUntil - 1e-9
		if self.lingerUntil > t + 1e-9 then nextEvent = min(nextEvent,self.lingerUntil) end
		return nextEvent, event
	end
	return state
end

-- Barrier generation has a fixed phase from combat start, independent of hits.
function M.crab(config, random)
	local count, tick, lost = config.initial or config.maximum, 0, -math.huge
	return function(t, physicalHit)
		local now = math.floor(t * 2 + 1e-9)
		for _ = tick + 1, now do
			count = min(config.maximum, count + 1)
			if (config.maximumChance or 0) > 0 and random() * 100 < config.maximumChance then count = config.maximum end
		end
		tick = now
		if physicalHit and count > 0 and not (config.protect and t - lost < 4 - 1e-9) then
			count, lost = max(0, count - (config.loss or config.maximum)), t
		end
		return count, (tick + 1) / 2
	end
end

-- Simultaneous continuous damage. Empty pools can intercept damage with their
-- current recovery; allocate that supply proportionally across damage types.
function M.prepareDot(damage, config)
	local esDemand, flows = 0, { }
	for kind, amount in pairs(damage) do
		local bypass = min(1, max(0, (config.bypass[kind] or 0) / 100))
		local mom = min(1, max(0, (config.mom[kind] or 0) / 100))
		local es = amount * (1 - bypass) * (config.battery and mom or 1)
		flows[#flows + 1] = { amount = amount, es = es, mom = mom }
		esDemand = esDemand + es
	end
	return function(pools, rates)
		local manaDemand, life = 0, 0
		local esTaken = pools.EnergyShield > 1e-8 and esDemand or min(esDemand, max(0, rates.EnergyShield or 0))
		for _, flow in ipairs(flows) do
			local es = esDemand > 0 and flow.es * esTaken / esDemand or 0
			local mana = config.battery and flow.amount * flow.mom - es or (flow.amount - es) * flow.mom
			manaDemand, life = manaDemand + mana, life + flow.amount - es - mana
		end
		local manaTaken = pools.Mana > 1e-8 and manaDemand or min(manaDemand, max(0, rates.Mana or 0))
		life = life + manaDemand - manaTaken
		return { Life = life, Mana = manaTaken, EnergyShield = esTaken }
	end
end

function M.dotRates(pools, rates, damage, config)
	return M.prepareDot(damage, config)(pools, rates)
end

-- Reactive recovery flasks use finite charges and a delayed threshold policy.
-- Each resource ends independently at full unless the flask is enduring.
function M.recoveryFlask(config)
	local bank = config.bank or encounter.charges(config, config.random)
	local pending, expires = math.huge, -math.huge
	local effects = { }
	return function(t, pools, full, trigger, profile)
		bank:advance(t)
		local active = false
		local function sourceFull()
			for resource in pairs(config.resources) do if pools[resource] < full[resource] - 1e-8 then return false end end
			return true
		end
		local missingLife = max(0,(full.Life or 0) - (pools.Life or 0))
		for resource, effect in pairs(effects) do
			if t >= (effect.expires or expires) - 1e-9 then
				if effect.finishLife then pools[resource] = min(full[resource],pools[resource] + missingLife) end
				effects[resource] = nil
			elseif not effect.enduring and sourceFull() then effects[resource] = nil
			else active = true end
		end
		local wanted = config.auto or false
		for resource in pairs(config.resources) do
			if pools[resource] < trigger[resource] * config.threshold - 1e-8 then wanted = true end
		end
		if not wanted then pending = math.huge end
		if not active and wanted and bank:ready(t) then
			if pending == math.huge then pending = t + config.reaction end
			if t >= pending - 1e-9 then
				assert(bank:use(t))
				pending = math.huge
				local duration
				effects, duration = profile(pools)
				expires = t + duration
				for resource, effect in pairs(effects) do
					effect.expires = t + (effect.duration or duration)
					pools[resource] = min(full[resource], pools[resource] + (effect.instant or 0))
				end
				local fullNow=sourceFull()
				for resource,effect in pairs(effects) do
					if not effect.gradual and (effect.rate or 0) <= 0 and not effect.enduring or not effect.enduring and fullNow then effects[resource]=nil end
				end
			end
		end
		local recovery, groups = { }, { }
		active = false
		local event = pending
		for resource, effect in pairs(effects) do
			recovery[resource], groups[resource] = effect.rate, effect.groups or { Default=effect.rate }
			active = true; event = min(event, effect.expires)
		end
		return active, recovery, min(event,bank:next(t)), bank.uses, bank.charges, groups
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

-- Repeated hits share one upfront skill payment. A failed use cannot borrow
-- recovery from its repeats to fund a cost it could not initially afford.
function M.skillUses()
	local nextUse, paid = -math.huge, false
	return function(t, pools, cost, useRate, battery)
		if t >= nextUse - 1e-9 then
			nextUse = t + 1 / max(useRate, 0.005)
			paid = M.payCost(pools, cost, battery)
		end
		return paid
	end
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
	local bank = config.bank or encounter.charges(config, config.random)
	local activeUntil = -math.huge
	return function(t, wanted)
		bank:advance(t)
		local used = false
		if wanted and t >= activeUntil - 1e-9 and bank:use(t) then
			activeUntil, used = t + config.duration, true
		end
		local nextEvent = t < activeUntil and activeUntil or bank:next(t)
		return t < activeUntil, used, nextEvent, bank.uses, bank.charges
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
	local sampleInterval, nextSample = max(0.25,window / 240), 0
	local nextAttack, attempts, attacks = config.attack and 0 or math.huge, 0, 0
	local rechargeActive, rechargeBegan = false, -math.huge
	local continuousInterruption = false
	local reservationRelease = math.huge
	local cohorts = { }
	local resources = { "Life", "Mana", "EnergyShield" }
	local function interruptsRecharge(damage)
		local protected = config.protectedResource or "Life"
		local damaged = damage[protected] > 0
		if config.actualDissolution and protected == "Life" then damaged = damaged and config.reservationMax - (pools.LifeReservation or 0) <= pools.Life + 1e-8 end
		return damage.EnergyShield > 0 or damaged
	end
	local function result(survived, at)
		if config.observe then config.observe(at,pools,survived and "Window reached" or "Death") end
		return { time = at, hits = hits, survived = survived, pools = pools, attacks = attacks, attempts = attempts }
	end
	if config.observe then config.observe(0,pools,"Start") end
	local checkpointSteps = 0
	while t <= window do
		checkpointSteps = checkpointSteps + 1
		if config.checkpoint and checkpointSteps % 32 == 1 then config.checkpoint() end
		-- End ordinary leech at the full-pool boundary before simultaneous costs
		-- or incoming hits can make the resource appear non-full again.
		if config.leech then config.leech:rates(t, pools) end
		if t >= reservationRelease - 1e-9 then
			if config.actualDissolution then pools.LifeReservation = 0
			else pools.Life = config.caps.Life end
			if config.observe then config.observe(t,pools,"Dissolution reservation released") end
			reservationRelease = math.huge
		end
		local external = config.before and config.before(pools, t) or math.huge
		if pools.Life <= 0 then return result(false, t) end
		local occurred = false
		if t >= nextHit - 1e-9 then
			occurred = true
			local oldES, oldLife = pools.EnergyShield, pools.Life
			local added, interrupted
			pools, added, interrupted = config.hit(pools, t)
			hits = hits + 1
			if interrupted or pools.EnergyShield < oldES then
				if not (config.wickedWard and rechargeActive and t - rechargeBegan < 4 - 1e-9) then
					lastRechargeDamage, rechargeActive = t, false
					if config.observe then config.observe(t,pools,"Recharge interrupted by hit") end
				end
			end
			if config.dissolution and (config.actualDissolution and (pools.LifeDamageReserved or 0) > 0 or not config.actualDissolution and pools.Life < oldLife) then reservationRelease = t + 2 end
			if pools.Life <= 0 then return result(false, t) end
			for _, cohort in ipairs(added or { }) do cohorts[#cohorts + 1] = cohort end
			nextHit = nextHit + interval
		end
		if t >= nextAttack - 1e-9 then
			occurred = true
			local paid
			pools, paid = config.attack(pools, t)
			attempts, attacks = attempts + 1, attacks + (paid and 1 or 0)
			if pools.Life <= 0 then return result(false, t) end
			local attackInterval = type(config.attackInterval) == "function" and config.attackInterval(pools, t) or config.attackInterval
			nextAttack = t + max(0.005, attackInterval)
		end
		if occurred and config.before then external = min(external, config.before(pools, t)) end
		if t >= nextSample - 1e-9 then
			if config.observe then config.observe(t,pools,"Sample") end
			nextSample = t + sampleInterval
		end
		if t >= window then break end
		local dt = min(config.step or 0.02, window - t, nextHit - t, nextAttack - t, reservationRelease - t, external - t)
		dt = min(dt,nextSample - t)
		local rates = { }
		local delayedLifeLoss, dotLifeDamage = 0, 0
		local baseRates = type(config.rates) == "function" and config.rates(pools, t) or config.rates or { }
		for _, resource in ipairs(resources) do rates[resource] = baseRates[resource] or 0 end
		for i = #cohorts, 1, -1 do
			local cohort = cohorts[i]
			if cohort.expires <= t + 1e-9 then table.remove(cohorts, i)
			else
				delayedLifeLoss = delayedLifeLoss + max(0,-(cohort.Life or 0))
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
		local rechargeResource = config.rechargeResource or "EnergyShield"
		local rechargeRate = type(config.recharge) == "function" and config.recharge(pools, t) or config.recharge or 0
		local canRecharge = pools[rechargeResource] < config.caps[rechargeResource] - 1e-9 and rechargeRate > 0
		if continuousInterruption and config.dot and interruptsRecharge(config.dot(pools,rates,t)) then rechargeStart = math.huge end
		if not rechargeActive and canRecharge and t >= rechargeStart - 1e-9 then
			rechargeActive, rechargeBegan = true, t
			if config.observe then config.observe(t,pools,"Recharge started") end
		end
		local rechargeAdded = 0
		if rechargeActive then
			local resource = config.rechargeResource or "EnergyShield"
			local recharge = type(config.recharge) == "function" and config.recharge(pools, t) or config.recharge or 0
			rates[resource] = rates[resource] + recharge
			rechargeAdded = pools[resource] > config.caps[resource] + 1e-8 and 0 or recharge
		elseif canRecharge and rechargeStart > t + 1e-9 and rechargeStart < t + dt then dt = rechargeStart - t end
		if config.wickedWard and rechargeActive and t - rechargeBegan < 4 - 1e-9 then dt = min(dt, rechargeBegan + 4 - t) end
		local flaskRates, flaskCaps = { }, config.caps
		if config.flaskRecovery then flaskRates, flaskCaps = config.flaskRecovery(pools, t) end
		for _, resource in ipairs(resources) do
			if pools[resource] > config.caps[resource] + 1e-8 then rates[resource] = min(0, rates[resource]) end
			rates[resource] = rates[resource] + (flaskRates[resource] or 0)
		end
		local reservationRate, dotInterrupted = 0, false
		if config.dot then
			local damage = config.dot(pools, rates, t)
			if interruptsRecharge(damage) then
				if not (config.wickedWard and rechargeActive and t - rechargeBegan < 4 - 1e-9) then
					if rechargeActive then
						local resource = config.rechargeResource or "EnergyShield"
						rates[resource] = rates[resource] - rechargeAdded
						damage = config.dot(pools, rates, t)
					end
					dotInterrupted, rechargeActive = true, false
				end
			end
			for _, resource in ipairs(resources) do
				if resource == "Life" and config.actualDissolution then reservationRate = damage.Life
				else rates[resource] = rates[resource] - damage[resource] end
			end
			dotLifeDamage = damage.Life
			if reservationRate > 0 then
				dt = min(dt, max(0, config.reservationMax - (pools.LifeReservation or 0)) / reservationRate)
				local gap = config.reservationMax - (pools.LifeReservation or 0) - pools.Life
				if gap > 1e-8 and reservationRate + rates.Life > 0 then dt = min(dt, gap / (reservationRate + rates.Life)) end
			end
		end
		-- Split when a pool reaches full so ordinary leech ends at the actual time.
		for _, resource in ipairs(resources) do
			local floor = config.resourceFloor and config.resourceFloor(resource) or 0
			if rates[resource] < 0 and pools[resource] > floor + 1e-8 then dt = min(dt, (pools[resource] - floor) / -rates[resource]) end
			if pools[resource] >= config.caps[resource] - 1e-8 then rates[resource] = min(rates[resource], max(0, flaskRates[resource] or 0)) end
			if rates[resource] > 0 and pools[resource] < config.caps[resource] - 1e-9 then
				dt = min(dt, (config.caps[resource] - pools[resource]) / rates[resource])
			end
			if rates[resource] < 0 and pools[resource] > 1e-8 then dt = min(dt, -pools[resource] / rates[resource]) end
			if (flaskRates[resource] or 0) > 0 and rates[resource] > 0 and pools[resource] < flaskCaps[resource] - 1e-8 then dt = min(dt, (flaskCaps[resource] - pools[resource]) / rates[resource]) end
		end
		if dotInterrupted then lastRechargeDamage = t + dt end
		continuousInterruption = dotInterrupted
		if reservationRate > 0 then
			pools.LifeReservation = (pools.LifeReservation or 0) + reservationRate * dt
			reservationRelease = t + dt + 2
		end
		for _, resource in ipairs(resources) do
			local recoveryCap = (flaskRates[resource] or 0) > 0 and flaskCaps[resource] or config.caps[resource]
			local cap = resource == "Life" and config.actualDissolution and min(max(recoveryCap, pools.Life), config.reservationMax - (pools.LifeReservation or 0)) or recoveryCap
			local value = max(0, pools[resource] + rates[resource] * dt)
			pools[resource] = config.actualDissolution and resource == "Life" and min(cap, value) or min(max(cap, pools[resource]), value)
		end
		if pools.Life <= 1e-8 then
			pools.Life = 0
			local causes = { }
			if reservationRate > 0 then causes[#causes + 1] = "Dissolution reservation filled" elseif dotLifeDamage > 0 then causes[#causes + 1] = "Continuous damage" end
			if delayedLifeLoss > 0 then causes[#causes + 1] = "Delayed Life loss" end
			if (baseRates.Life or 0) < 0 then causes[#causes + 1] = "Configured net Life loss" end
			if config.lossCause then config.lossCause(#causes > 0 and table.concat(causes," + ") or "Life capacity depleted") end
			return result(false, t + dt)
		end
		if dt <= 0 then error("Recovery timeline failed to advance") end
		t = min(window, t + dt)
	end
	return result(true, window)
end

return M
