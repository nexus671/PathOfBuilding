-- Evidence and readable comparisons for native build candidates.
local M = { }
local friendlyMetrics={CombinedDPS="Combined DPS",FullDPS="Full skill DPS",FireResist="Fire resistance",ColdResist="Cold resistance",LightningResist="Lightning resistance",ChaosResist="Chaos resistance",Str="Strength",Dex="Dexterity",Int="Intelligence"}
M.goals = { "balanced", "boss_damage", "mapping", "survival", "comfort" }
M.labels = {CombinedDPS="Combined DPS",FullDPS="Full DPS",TotalEHP="EHP",LifeUnreserved="Unreserved Life",EnergyShield="Energy Shield",ManaUnreserved="Unreserved Mana",PhysicalMaximumHitTaken="Physical maximum hit",ChaosMaximumHitTaken="Chaos maximum hit",RecoverySimulationSurvivalChance="Encounter survival (%)",RecoverySimulationDamageDPS="Encounter DPS",RecoverySimulationAttackUptime="Affordable attack fraction",Speed="Skill speed",EffectiveMovementSpeedMod="Movement speed",ManaRegen="Mana regeneration"}
for key,label in pairs(friendlyMetrics) do M.labels[key]=label end

local function sortedKeys(t)
	local keys = { }
	for key in pairs(t) do keys[#keys+1] = key end
	table.sort(keys)
	return keys
end

function M.snapshot(build)
	local o = build.calcsTab.calcsOutput
	local result = {level=build.characterLevel,className=build.spec.curClassName,ascendancy=build.spec.curAscendClassName,items={},skills={},passives={},config=copyTable(build.configTab.input),notes=build.notesTab.controls.edit.buf,stats={}}
	for key,value in pairs(o) do
		if type(value) == "number" and value == value and math.abs(value) < math.huge then result.stats[key] = value end
	end
	for name,slot in pairs(build.itemsTab.slots) do
		local item = build.itemsTab.items[slot.selItemId]
		if item then result.items[name] = {name=item.name or item.baseName or "Item",text=item.raw,active=slot.active,requirements=copyTable(item.requirements)} end
	end
	for _,group in ipairs(build.skillsTab.socketGroupList) do
		local names = { }
		for _,gem in ipairs(group.gemList) do names[#names+1] = string.format("%s %d/%d%s",gem.nameSpec,gem.level,gem.quality,gem.enabled == false and " (disabled)" or "") end
		result.skills[#result.skills+1] = (group.label or "").." ["..(group.slot or "unassigned").."] "..table.concat(names," + ")..(group.enabled == false and " (disabled)" or "")..(group.includeInFullDPS and " [Full DPS]" or "").." main="..tostring(group.mainActiveSkill or 1)
	end
	result.mainGroup = build.mainSocketGroup
	result.craftingProjects = require("Modules.CraftingProjects").copy(build.savers.CraftingProjects.projects)
	result.journey = build.savers.BuildJourney and copyTable(build.savers.BuildJourney.data)
	result.lootFilters = copyTable(build.savers.LootFilters.data)
	result.atlasPlans = copyTable(build.savers.AtlasPlans.plans)
	for _,node in pairs(build.spec.nodes) do if node.alloc then result.passives[node.id] = (node.name or node.dn or node.type or "Passive")..(build.spec.masterySelections[node.id] and " (mastery "..build.spec.masterySelections[node.id]..")" or "") end end
	return result
end

function M.changes(before, after)
	local lines = { }
	local function add(s) lines[#lines+1] = s end
	for _,key in ipairs({"level","className","ascendancy","mainGroup"}) do if before[key] ~= after[key] then add(key..": "..tostring(before[key]).." -> "..tostring(after[key])) end end
	local slots = { }
	for name in pairs(before.items) do slots[name]=true end
	for name in pairs(after.items) do slots[name]=true end
	for _,name in ipairs(sortedKeys(slots)) do
		local a,b = before.items[name],after.items[name]
		if (a and a.text) ~= (b and b.text) then add(name..": "..(a and a.name or "empty").." -> "..(b and b.name or "empty")); if b then for line in (b.text or ""):gmatch("[^\r\n]+") do add("  "..line) end end end
		if a and b and a.active ~= b.active then add(name.." active: "..tostring(a.active).." -> "..tostring(b.active)) end
	end
	for i=1,math.max(#before.skills,#after.skills) do if before.skills[i] ~= after.skills[i] then add("Socket group "..i..": "..(before.skills[i] or "empty").." -> "..(after.skills[i] or "removed")) end end
	for _,id in ipairs(sortedKeys(before.passives)) do if before.passives[id] ~= after.passives[id] then add("Remove passive: "..before.passives[id].." (#"..id..")") end end
	for _,id in ipairs(sortedKeys(after.passives)) do if before.passives[id] ~= after.passives[id] then add("Add passive: "..after.passives[id].." (#"..id..")") end end
	local config = { }
	for key in pairs(before.config) do config[key]=true end
	for key in pairs(after.config) do config[key]=true end
	for _,key in ipairs(sortedKeys(config)) do if before.config[key] ~= after.config[key] then add("Configuration "..key..": "..tostring(before.config[key]).." -> "..tostring(after.config[key])) end end
	if before.notes ~= after.notes then add("Notes updated:"); for line in after.notes:gmatch("[^\n]+") do add("  "..line) end end
	if not tableDeepEquals(before.journey,after.journey) or not tableDeepEquals(after.journey,before.journey) then
		add("Build journey updated; use build Save to persist.")
		for _,key in ipairs({"milestones","wishlist","resources","ledger","stages"}) do
			for _,entry in ipairs(after.journey and after.journey[key] or {}) do
				add(key.." | "..require("dkjson").encode(entry))
			end
		end
	end
	if not tableDeepEquals(before.craftingProjects,after.craftingProjects) or not tableDeepEquals(after.craftingProjects,before.craftingProjects) then
		add("Crafting projects updated (saved only with an explicit build Save)")
		local originals,present={},{}
		for _,project in ipairs(before.craftingProjects or {}) do originals[project.id]=project end
		for _,project in ipairs(after.craftingProjects or {}) do
			present[project.id]=true
			local old=originals[project.id]
			if not old or not tableDeepEquals(old,project) or not tableDeepEquals(project,old) then
				add((old and "Updated" or "Added").." crafting project: "..project.title)
				for _,line in ipairs(require("Modules.CraftingProjects").lines(project)) do add(line) end
			end
		end
		for _,project in ipairs(before.craftingProjects or {}) do if not present[project.id] then
			local linked=0;for _,entry in ipairs(after.journey and after.journey.wishlist or {}) do if entry.projectId==project.id then linked=linked+1 end end
			local items=#(project.inventory or {})
			add("Removed crafting project: "..project.title.." ["..project.id.."] | "..items.." saved inventory "..(items==1 and "item" or "items").." | "..linked.." linked gear "..(linked==1 and "goal remains" or "goals remain"))
		end end
	end
	if not tableDeepEquals(before.atlasPlans,after.atlasPlans) then
		add("Atlas plans updated (planning only; character stats are unchanged by Atlas nodes)")
		for _,plan in ipairs(after.atlasPlans or {}) do
			local report=require("Modules.AtlasPlanner").report(plan)
			add(plan.title.." ["..plan.version.."] "..report.used.." points; budget "..report.budget.." + "..report.bonus)
			for _,id in ipairs(plan.nodes) do add("  #"..id.." "..require("Modules.AtlasPlanner").tree(plan.version).nodes[id].name) end
			if plan.notes ~= "" then add("  "..plan.notes) end
		end
	end
	if not tableDeepEquals(before.lootFilters,after.lootFilters) then
		add("Loot filters updated; export and build Save remain explicit.")
		for _,profile in ipairs(after.lootFilters.profiles) do
			add(profile.title.." | "..profile.preset.." | "..require("Modules.LootFilters").strictness[profile.strictness+1])
			for _,rule in ipairs(profile.rules) do add((rule.enabled and "Enabled: " or "Disabled: ")..rule.title);add(rule.text) end
		end
	end
	if #lines == 0 then add("No character, equipment, gem, passive, configuration, Atlas plan or notes changes.") end
	return lines
end

function M.audit(build)
	local snapshot = M.snapshot(build)
	local o,c = snapshot.stats,snapshot.config
	local result = {assumptions={},dependencies={},nativeWarnings=copyTable(build.controls.warnings.lines)}
	local function assumption(key,message) result.assumptions[#result.assumptions+1] = {key=key,text=message} end
	local function dependency(key,message) result.dependencies[#result.dependencies+1] = {key=key,text=message} end
	if treeVersions[build.spec.treeVersion].preview then assumption("previewTree","3.30 preview tree. Items, gems and new mechanics may not yet be modeled; verify unsupported modifiers before relying on these calculations.") end
	if treeVersions[build.spec.treeVersion].num==3.30 and not treeVersions[build.spec.treeVersion].preview then assumption("patchData","3.30 trees are available; gem, item and new mechanic support is still being updated. Review unsupported modifiers.") end
	assumption("enemyIsBoss","Enemy preset: "..tostring(c.enemyIsBoss or "None")..". Match the encounter you intend to test.")
	for _,key in ipairs(sortedKeys(c)) do
		if c[key] == true and (key:match("^condition") or key:match("^use.*Charges")) then assumption(key,"Enabled condition: "..key..". Check its source and uptime.") end
	end
	for _,name in ipairs(sortedKeys(snapshot.items)) do local item=snapshot.items[name]; if item.active then assumption(name,name.." is active in native calculations; continuous uptime is not guaranteed.") end end
	if not c.simulateRecovery then assumption("simulateRecovery","Encounter simulation is disabled; recovery and resource sustain have no timed result.") end
	if c.customMods and c.customMods ~= "" then assumption("customMods","Custom modifiers affect calculations. Check their source and values.") end
	if o.RecoverySimulationAttackUptime and o.RecoverySimulationAttackUptime < 0.99 then dependency("resource_sustain",string.format("Only %.1f%% of simulated attack attempts were affordable.",o.RecoverySimulationAttackUptime*100)) end
	for _,kind in ipairs({"Fire","Cold","Lightning","Chaos"}) do
		local value,cap = o[kind.."Resist"],o[kind.."ResistMax"]
		if value and cap and value < cap then dependency(kind.."Resist",string.format("%s resistance %.0f%% is below its %.0f%% cap.",kind,value,cap)) end
	end
	if (o.ManaUnreserved or 0) < 0 then dependency("reservation","Mana reservation exceeds the available pool.") end
	if (o.LifeUnreserved or 0) < 0 then dependency("reservation","Life reservation exceeds the available pool.") end
	local env = build.calcsTab.mainEnv
	local omni = env and env.modDB:Flag(nil,"OmniscienceRequirements")
	local omniRate = omni and env.modDB:Sum("INC",nil,"OmniAttributeRequirements") or 0
	local function requirements(name,req)
		if not req then return end
		if (req.level or 0) > build.characterLevel then dependency("level",name.." requires level "..req.level.." (character "..build.characterLevel..").") end
		if omni then
			local high = math.max(req.strMod or req.str or 0,req.dexMod or req.dex or 0,req.intMod or req.int or 0)
			if omniRate > 0 and math.floor(high*100/omniRate) > (o.Omni or 0) then dependency("Omni",name.." exceeds available Omniscience.") end
		else
			for _,entry in ipairs({{"str","Str"},{"dex","Dex"},{"int","Int"}}) do
				local needed = req[entry[1].."Mod"] or req[entry[1]] or 0
				if needed > (o[entry[2]] or 0) then dependency(entry[2],string.format("%s requires %d %s; available %.0f.",name,needed,entry[2],o[entry[2]] or 0)) end
			end
		end
	end
	for name,item in pairs(snapshot.items) do requirements(name.." ("..item.name..")",item.requirements) end
	for _,group in ipairs(build.skillsTab.socketGroupList) do for _,gem in ipairs(group.gemList) do
		if group.enabled ~= false and gem.enabled ~= false and gem.gemData then requirements(gem.nameSpec,{level=gem.reqLevel,str=gem.reqStr,dex=gem.reqDex,int=gem.reqInt}) end
	end end
	for _,warning in ipairs(result.nativeWarnings) do dependency("native",StripEscapes(warning)) end
	return result
end

local weights = {
	balanced={CombinedDPS=0.4,TotalEHP=0.3,PhysicalMaximumHitTaken=0.15,ChaosMaximumHitTaken=0.15},
	boss_damage={FullDPS=0.6,CombinedDPS=0.2,RecoverySimulationDamageDPS=0.2},
	mapping={CombinedDPS=0.5,EffectiveMovementSpeedMod=0.3,TotalEHP=0.2},
	survival={TotalEHP=0.3,PhysicalMaximumHitTaken=0.25,ChaosMaximumHitTaken=0.25,RecoverySimulationSurvivalChance=0.2},
	comfort={ManaRegen=0.3,ManaUnreserved=0.2,RecoverySimulationAttackUptime=0.3,EffectiveMovementSpeedMod=0.2},
}

function M.evaluate(before, after, plan, quote, audit)
	plan = plan or {goal="balanced"}
	assert(weights[plan.goal or "balanced"],"Unknown build goal")
	local score,used,missing = 0,0,{ }
	for key,weight in pairs(weights[plan.goal or "balanced"]) do
		if before[key] and before[key] > 0 and after[key] then score=score+weight*(after[key]/before[key]-1)*100; used=used+weight
		else missing[#missing+1]=key end
	end
	local result = {goal=plan.goal or "balanced",score=used > 0 and score/used or nil,missingMetrics=missing,eligible=true,issues={},quote=quote,
		method="Weighted percentage changes versus the same base; unavailable or zero baseline metrics excluded. A heuristic, not an optimizer or a guarantee."}
	for key,minimum in pairs(plan.minimums or { }) do if not after[key] or after[key] < minimum then result.eligible=false; result.issues[#result.issues+1]="Minimum not met: "..key.." >= "..minimum end end
	if plan.budget then
		if not quote or quote.currency ~= plan.currency then result.eligible=false; result.issues[#result.issues+1]="Missing price quote in "..plan.currency
		elseif quote.amount > plan.budget then result.eligible=false; result.issues[#result.issues+1]="Over budget" end
	end
	if quote then
		assert(type(quote.amount) == "number" and quote.amount >= 0 and quote.amount < math.huge,"Invalid quoted cost")
		result.priceAgeSeconds = math.max(0,os.time()-quote.quotedAt)
		if result.priceAgeSeconds > 86400 then result.issues[#result.issues+1]="Price quote is over 24 hours old; verify availability and total cost." end
		if quote.amount > 0 and result.score then result.scorePerCurrency=result.score/quote.amount end
	end
	result.dependencyCount = audit and #audit.dependencies or 0
	return result
end

function M.diagnose(build)
	local reportModule = require("Modules.EncounterReport")
	local report = reportModule.capture(build)
	local result = {capturedAt=report.capturedAt,summary=report.summary,settings=report.settings,checks=report.checks,unsupported=report.unsupported,
		observations=reportModule.deathLines(report),tests={},limitations=report.limitations,trace=report.trace}
	result.limitations[1] = "Captured from the connected build at the stated revision and time. Recalculate after changes."
	if report.trace and report.trace.cause then
		result.tests[#result.tests+1] = report.trace.deathDetails and "Compare a candidate improving the maximum hit for the terminal damage type, keeping encounter inputs fixed."
			or "Inspect continuous losses and compare mitigation and recovery for the recorded terminal cause. Maximum hit alone does not measure damage over time."
		result.tests[#result.tests+1] = "Compare recovery and resource sustain over the same duration, seed and trials."
		local before = report.trace.deathDetails and report.trace.deathDetails.before
		if before then
			if before.Mana and before.Mana <= 0 then result.observations[#result.observations+1] = "Mana was empty before the terminal hit. This alone does not establish the cause of death." end
			if before.EnergyShield and before.EnergyShield <= 0 then result.observations[#result.observations+1] = "Energy Shield was empty before the terminal hit." end
		end
	end
	return result
end

function M.explain(prepared)
	local lines={"Measured result for the complete proposal", "These are paired native calculation outputs. Individual changes have not been isolated."}
	for _,key in ipairs({"TotalEHP","PhysicalMaximumHitTaken","ChaosMaximumHitTaken","RecoverySimulationSurvivalChance","RecoverySimulationTime","RecoverySimulationDamageDPS"}) do
		local a,b=prepared.before[key],prepared.after[key]
		if a and b then lines[#lines+1]=string.format("%s: %.2f -> %.2f (%+.2f)",M.labels[key] or key,a,b,b-a) end
	end
	local before=prepared.base.calcsTab.calcsOutput;local after=prepared.candidate.calcsTab.calcsOutput
	local groups={
		{"Pools and mitigation",{"LifeUnreserved","EnergyShield","ManaUnreserved","Armour","Evasion","PhysicalDamageReduction","FireResist","ColdResist","LightningResist","ChaosResist"}},
		{"Avoidance and block",{"EvadeChance","BlockChance","SpellBlockChance","SpellSuppressionChance","AttackDodgeChance","SpellDodgeChance","AvoidAllDamageFromHitsChance"}},
		{"Recovery",{"LifeRegen","EnergyShieldRegen","ManaRegen","EnergyShieldRecharge","EnergyShieldRechargeDelay","MaxLifeLeechRate","MaxEnergyShieldLeechRate","LifeOnBlock","EnergyShieldOnBlock","ManaOnBlock"}},
	}
	for _,group in ipairs(groups) do
		lines[#lines+1]="";lines[#lines+1]=group[1];local count=0
		for _,key in ipairs(group[2]) do local a,b=before[key],after[key];if type(a)=="number" and type(b)=="number" and math.abs(a-b)>0.00001 then lines[#lines+1]=string.format("%s: %.2f -> %.2f (%+.2f)",M.labels[key] or key:gsub("(%l)(%u)","%1 %2"),a,b,b-a);count=count+1 end end
		if count==0 then lines[#lines+1]="No changed outputs recorded in this group." end
	end
	lines[#lines+1]="";lines[#lines+1]="Static EHP and timed survival measure different things. Recharge needs an uninterrupted window; recovery only helps if the character survives until it applies."
	if prepared.evaluation and prepared.evaluation.configurationChanged then lines[#lines+1]="Encounter or configuration settings changed. Compare under matching settings before attributing the result to equipment or passives." end
	lines[#lines+1]="Use the encounter chart and native Calcs breakdowns to inspect event order and individual formulas."
	return lines
end

return M
