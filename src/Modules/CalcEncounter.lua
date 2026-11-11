-- Encounter reporting and event state. No UI/build mutation or global RNG.
local M = { }
local min, max = math.min, math.max
local bit = require("bit")

local function multiply32(a,b)
	local low = bit.band(a,65535) * bit.band(b,65535)
	local high = bit.band(bit.rshift(a,16) * bit.band(b,65535) + bit.band(a,65535) * bit.rshift(b,16),65535)
	return bit.tobit(low + high * 65536)
end

function M.seed(input, trial, stream)
	-- Avalanche counters before seeding the LCG: nearby linear seeds produce
	-- correlated first outputs and can bias conditional block/avoidance samples.
	local value=bit.bxor(math.floor(input or 104729),multiply32(trial,2654435769),multiply32(stream or 0,2246822507))
	value=multiply32(bit.bxor(value,bit.rshift(value,16)),2146121005)
	value=multiply32(bit.bxor(value,bit.rshift(value,15)),2221713035)
	value=bit.bxor(value,bit.rshift(value,16))
	if value < 0 then value=value+4294967296 end
	return value % 2147483646 + 1
end

function M.wilson(successes, count)
	if count == 0 then return 0, 100 end
	local z, p = 1.95996398454, successes / count
	local d = 1 + z * z / count
	local centre = (p + z * z / (2 * count)) / d
	local half = z * math.sqrt(p * (1 - p) / count + z * z / (4 * count * count)) / d
	return max(0, centre - half) * 100, min(1, centre + half) * 100
end

-- Paired differences preserve trial identity; do not subtract independent CIs.
function M.paired(a, b, value)
	assert(#a == #b and #a > 0, "paired trials must have matching counts")
	local mean, sum, differences = 0, 0, { }
	for i = 1, #a do
		local av,bv=value(a[i]),value(b[i])
		local diff=bv-av
		if math.abs(diff) <= max(1,math.abs(av),math.abs(bv)) * 1e-10 then diff=0 end
		differences[i]=diff; mean=mean+diff
	end
	mean = mean / #a
	for _,diff in ipairs(differences) do sum = sum + (diff - mean) ^ 2 end
	local half = #a > 1 and 1.96 * math.sqrt(sum / (#a - 1) / #a) or math.huge
	return mean, mean - half, mean + half
end

-- Expected poison damage from landed attacks, with individual expiry. Damage
-- stays snapshotted when flasks expire; no new poisons are applied on skipped uses.
function M.poison(cap)
	local instances, at, damage, hitDamage = { }, 0, 0, 0
	local state = { }
	function state:advance(t)
		while at < t - 1e-9 do
			local expiry, groups = t, { }
			for i = #instances, 1, -1 do
				local p = instances[i]
				if p.expires <= at + 1e-9 then table.remove(instances, i)
				else
					expiry = min(expiry, p.expires)
					local g = groups[p.group] or { rate=0, limit=p.limit }; groups[p.group] = g
					g.rate = g.rate + p.rate
				end
			end
			local rate = 0
			for _,g in pairs(groups) do rate = rate + min(g.rate, g.limit) end
			damage = damage + min(cap or math.huge, rate) * (expiry - at)
			at = expiry
		end
		local groups, rate = { }, 0
		for _,p in ipairs(instances) do
			if p.expires > t + 1e-9 then
				local g = groups[p.group] or { rate=0, limit=p.limit }; groups[p.group] = g
				g.rate = g.rate + p.rate
			end
		end
		for _,g in pairs(groups) do rate = rate + min(g.rate, g.limit) end
		return min(cap or math.huge, rate), damage, hitDamage
	end
	function state:hit(t, profiles, landedRate, direct)
		self:advance(t)
		hitDamage = hitDamage + max(0, direct or 0)
		for i,p in ipairs(profiles or { }) do
			if p.duration > 0 and landedRate > 0 then
				instances[#instances + 1] = { group=i, rate=p.slope / landedRate, expires=t + p.duration, limit=p.limit or math.huge }
			end
		end
	end
	return state
end

-- Charge state is shared by use policies and incoming/outgoing event callbacks.
function M.charges(config, random)
	local bank = { charges=config.charges, uses=0, generated=0, last=0, lastUse=-math.huge }
	function bank:advance(t)
		self.charges = min(config.charges, self.charges + max(0,t - self.last) * (config.generation or 0))
		self.last = t
	end
	function bank:gain(t, amount)
		self:advance(t)
		local gain = max(0,amount) * (config.gain or 1)
		self.generated = self.generated + min(gain, config.charges - self.charges)
		self.charges = min(config.charges, self.charges + gain)
	end
	function bank:use(t)
		self:advance(t)
		if t <= self.lastUse + 1e-9 or config.used <= 0 or self.charges + 1e-9 < config.used then return false end
		if (config.freeChance or 0) <= 0 or random() * 100 >= config.freeChance then self.charges = max(0,self.charges - config.used) end
		self.uses, self.lastUse = self.uses + 1, t
		return true
	end
	function bank:ready(t)
		self:advance(t)
		return self.charges + 1e-9 >= config.used and config.used > 0 and t > self.lastUse + 1e-9
	end
	function bank:next(t)
		if self:ready(t) or not config.generation or config.generation <= 0 then return math.huge end
		return t + max(0,config.used - self.charges) / config.generation
	end
	return bank
end

-- The game rounds after combining local and global charge modifiers.
function M.chargesUsed(base, localInc, globalInc)
	return max(1, math.floor(base * (1 + localInc / 100) * (1 + globalInc / 100) + 1e-8))
end

function M.chargeEvents(banks, profiles, random)
	local lastCrit, lastHit = -math.huge,{ }
	local events = { }
	function events:critical(t, globalChance)
		if t - lastCrit < 0.1 - 1e-9 then return end
		local candidates = { }
		for i,p in ipairs(profiles) do
			local chance = min(100,(globalChance or 0) + (p.critChance or 0) + ((p.legacyCritCharges or 0) > 0 and 100 or 0))
			if chance > 0 then candidates[#candidates + 1] = {index=i,chance=chance} end
		end
		if #candidates == 0 then return end
		local candidate = candidates[math.floor(random() * #candidates) + 1]
		if random() * 100 >= candidate.chance then return end
		banks[candidate.index]:gain(t,profiles[candidate.index].legacyCritCharges or 1)
		lastCrit = t
		return candidate.index
	end
	function events:hit(t)
		for i,p in ipairs(profiles) do
			if (p.chargesWhenHit or 0) > 0 and t - (lastHit[i] or -math.huge) >= 0.1 - 1e-9 then
				banks[i]:gain(t,p.chargesWhenHit); lastHit[i] = t
			end
		end
	end
	return events
end

function M.trace(window)
	local trace = { rows={ }, points={ }, dropped=0, events=0, window=window }
	function trace:add(t, pools, event, extra)
		extra = extra or { }
		local row = { time=t, Life=pools.Life, Mana=pools.Mana, EnergyShield=pools.EnergyShield,
			reservation=pools.LifeReservation or 0, ward=pools.Ward or 0, crab=extra.crab or 0,
			shrouds=extra.shrouds or 0, charges=extra.charges or "", poison=extra.poison or 0, event=event }
		row.chargesTotal = extra.chargesTotal or 0
		if event == "Sample" or event == "Start" or event == "Death" or event == "Window reached" then
			self.points[#self.points + 1] = row
		end
		-- Bound large fight logs but always retain the final outcome.
		if #self.rows >= 1000 and event ~= "Death" and event ~= "Window reached" then self.dropped = self.dropped + 1; return end
		self.rows[#self.rows + 1] = row
	end
	return trace
end

M.presets = {
	{ name="Single heavy hit", category="Untyped", speed=700, scale=2, single=true },
	{ name="Rapid spells", category="Spell", speed=250, scale=1 },
	{ name="Mixed pressure", category="Average", speed=700, scale=1 },
	{ name="Sustained damage over time", category="DamageOverTime", speed=700, scale=1 },
}

function M.preset(input, placeholder, preset)
	local changed = { }
	for k,v in pairs(input) do changed[k] = v end
	changed.simulateRecovery, changed.recoverySimulationSingleHit = true, preset.single or false
	changed.recoverySimulationCompareSet = nil
	changed.enemyDamageType, changed.enemySpeed = preset.category, preset.speed
	for _,kind in ipairs({ "Physical", "Fire", "Cold", "Lightning", "Chaos" }) do
		changed["recoverySimulation"..kind.."Dot"] = 0
		changed["enemy"..kind.."Damage"] = tostring((tonumber(input["enemy"..kind.."Damage"]) or tonumber(placeholder["enemy"..kind.."Damage"]) or 0) * preset.scale)
	end
	return changed
end

function M.audit(input, context)
	local rows, warnings = { }, 0
	local function add(level, text)
		rows[#rows + 1] = { level=level,text=text }
		if level == "Review" then warnings = warnings + 1 end
	end
	if (input.multiplierManaBurnStacks or 0) > 0 and not context.tincture then add("Review","Mana Burn stacks are configured without an active tincture. They still drain mana; review whether those stacks describe the encounter.") end
	if context.tincture and input.recoverySimulationTimedEffects ~= false and input.recoverySimulationTinctures ~= false then add("Dynamic","Selected tincture starts at zero burn; resource exhaustion or the stack mastery deactivates it and starts cooldown. Burn clears. Reuse is a separate manual-use policy.") end
	if context.uncheckedRecovery and not input.recoverySimulationEquippedFlasks then add("Review","An equipped recovery flask is unchecked and unavailable to the simulation. Enable Include equipped recovery flasks to test using it.") end
	for _,resource in ipairs({"Life","Mana","EnergyShield"}) do
		if input["conditionFull"..resource] and input["conditionLow"..resource] then add("Review",resource.." is configured as both Full and Low. Check the intended conditions and any special mechanics.") end
	end
	if input.conditionFullEnergyShield then add("Review","Full-ES conditional damage remains configured even when the timeline loses ES. This can overstate outgoing damage.") end
	if not input.recoverySimulationAttacking then add("Assumption","No outgoing main-skill attacks, skill costs, on-hit recovery or leech generation. Simulated outgoing damage is zero.") end
	if context.poisonUnsupported then add("Review","This skill's poison application is unsupported; the outgoing damage result excludes its poisons.") end
	if input.recoverySimulationTimedEffects == false then add("Review","Temporary effects stay configured: flask charges/expiry, Elusive decay, guard expiry and Crab loss are disabled.") end
	if (input.enemyCritChance or 0) > 0 then add("Assumption","Enemy critical damage uses the native configured average. Individual critical bursts are not rolled.") end
	if input.usePowerCharges or input.useFrenzyCharges or input.useEnduranceCharges then add("Assumption","Configured power/frenzy/endurance charges stay fixed. Their generation and expiry are not simulated.") end
	if (input.multiplierPoisonOnEnemy or 0) > 0 then add("Assumption","Damage modifiers use the configured poison-on-enemy count; newly applied poison instances do not rewrite that condition.") end
	add("Dynamic","Resource pools, costs, leech, recoup, recharge, shrouds, continuous damage and Dissolution reservation follow the event timeline.")
	add("Assumption","Wither, movement, recently-hit/full-pool damage bonuses and other conditional buffs stay configured unless explicitly listed as dynamic.")
	return rows,warnings
end

return M
