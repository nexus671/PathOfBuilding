-- Compare generated conditions rather than treating every unrelated build edit as stale.
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local stable=require("Modules.PlanningData")
local M={}
local generated=setmetatable({},{__mode="k"})
local function skillInputs(build)
	local result={weaponSet=build.itemsTab.activeItemSet.useSecondWeaponSet and 2 or 1,groups={}}
	for _,group in ipairs(build.skillsTab.socketGroupList) do
		local entry={enabled=group.enabled~=false,slot=group.slot or "",gems={}};result.groups[#result.groups+1]=entry
		for _,gem in ipairs(group.gemList) do
			local effect=gem.grantedEffect or gem.gemData and gem.gemData.grantedEffect
			local color=effect and effect.color; if type(color)~="number" and type(color)~="string" then color="" end
			entry.gems[#entry.gems+1]={enabled=gem.enabled~=false,name=gem.nameSpec or "",color=color}
		end
	end
	return stable.encode(result)
end
function M.report(build,profile,checkpoint)
	local function collect(rules)
		local groups={};for _,rule in ipairs(rules) do if rule.origin then
			local group=groups[rule.origin] or {origin=rule.origin,rules={},conditions={}};groups[rule.origin]=group
			group.rules[#group.rules+1]=rule.title;local block=parser.parse(rule.text).rules[1];local conditions={}
			for _,condition in ipairs(block.conditions) do
				local numericName=(condition.keyword=="HasExplicitMod" or condition.keyword=="HasEnchantment") and tonumber(condition.values[1]) and condition.quoted and condition.quoted[1] or nil
				conditions[#conditions+1]={keyword=condition.keyword,operator=condition.operator,values=condition.values,numericName=numericName}
			end
			table.sort(conditions,function(a,b) return stable.encode(a)<stable.encode(b) end);group.conditions[#group.conditions+1]={title=rule.title,action=block.action,conditions=conditions}
		end end
		for _,group in pairs(groups) do table.sort(group.conditions,function(a,b) return stable.encode(a)<stable.encode(b) end) end
		return groups
	end
	local revision=require("Modules.PlanningRevision");local stamp=revision.stamp(build);local skills=skillInputs(build);local cached=generated[build]
	if not cached or not revision.same(cached.stamp,stamp) or cached.skills~=skills then cached={stamp=stamp,skills=skills,profiles={}};generated[build]=cached end
	local key=profile.preset..":"..profile.theme;local new=cached.profiles[key]
	if new and new.rulesKey and new.rulesKey~=stable.encode(profile.rules) then new=nil end
	if not new then
		local start=os.clock();local rules,warnings=filters.generate(build,profile,checkpoint);new={groups=collect(rules),warnings=warnings or {}}
		local retry=false;for _,warning in ipairs(new.warnings) do if warning.retry then retry=true;break end end
		if not retry then
			-- Incomplete recipes retain existing pickups, so their result depends
			-- on the current draft as well as the build and filter style.
			if #new.warnings>0 then new.rulesKey=stable.encode(profile.rules) end
			cached.profiles[key]=new
		end
		if not checkpoint then require("Modules.PlanningPerformance").record(build,"Filter target refresh",os.clock()-start) end
	end
	local old=collect(profile.rules);local result={stale=false,linked=0,entries={}}
	local origins,warningByOrigin={},{};for key in pairs(old) do origins[key]=true end;for key in pairs(new.groups) do origins[key]=true end
	for _,warning in ipairs(new.warnings) do origins[warning.origin]=true;warningByOrigin[warning.origin]=warning end
	for origin in pairsSortByKey(origins) do
		local before,after=old[origin],new.groups[origin];local warning=warningByOrigin[origin];local status=warning and "Needs review" or not before and "New target" or not after and "Source removed / no longer needed" or stable.encode(before.conditions)~=stable.encode(after.conditions) and "Changed" or "Current"
		if before then result.linked=result.linked+#before.rules end
		if status~="Current" then result.stale=true end
		local lines={status,"Source: "..origin,"Refreshing replaces generated pickups and preserves personal overrides.","Existing pickups: "..table.concat(before and before.rules or {},", "),"Current targets: "..table.concat(after and after.rules or {},", ")}
		if warning then lines[#lines+1]=warning.message end
		result.entries[#result.entries+1]={id=origin,label=(after and after.rules[1] or before and before.rules[1] or warning.title).." | "..status,category=status,details=lines,origin=origin,status=status}
	end
	-- An entirely manual filter has no previous generation to become out of date.
	result.stale=result.linked>0 and result.stale;return result
end
local function begin(build,profile,generate)
	local revision=require("Modules.PlanningRevision")
	local job={build=build,profile=profile,stamp=revision.stamp(build),skills=skillInputs(build),profileKey=stable.encode({preset=profile.preset,theme=profile.theme,rules=profile.rules}),generate=generate}
	local captured=copyTable(profile)
	job.thread=coroutine.create(function()
		local checkpoint=function() coroutine.yield() end
		if generate then local rules,warnings=filters.generate(build,captured,checkpoint);return {rules=rules,warnings=warnings} end
		return M.report(build,captured,checkpoint)
	end)
	return job
end
function M.begin(build,profile) return begin(build,profile,false) end
function M.beginGenerate(build,profile) return begin(build,profile,true) end
function M.current(job)
	local revision=require("Modules.PlanningRevision")
	return revision.same(job.stamp,revision.stamp(job.build)) and job.skills==skillInputs(job.build)
		and job.profileKey==stable.encode({preset=job.profile.preset,theme=job.profile.theme,rules=job.profile.rules})
end
function M.poll(job)
	if not M.current(job) then return true,nil,"changed" end
	local start=os.clock();local ok,result=coroutine.resume(job.thread)
	require("Modules.PlanningPerformance").record(job.build,job.generate and "Filter pickup generation slice" or "Filter target refresh slice",os.clock()-start)
	if not ok then return true,nil,result end
	if coroutine.status(job.thread)=="dead" then if not M.current(job) then return true,nil,"changed" end;return true,result end
	return false
end
function M.open(build,layout,origin)
	local kind,id=origin:match("^([^:]+):(.+)$")
	if kind=="craft" then for _,project in ipairs(build.savers.CraftingProjects.projects) do if project.id==id then layout.openWorkbench(project);return end end
	elseif kind=="atlas" then for _,plan in ipairs(build.savers.AtlasPlans.plans) do if plan.id==id then layout.navigate("atlas",copyTable(plan));return end end
	elseif kind=="gear" or kind=="budget" then
		local entries=build.savers.BuildJourney.data[kind=="gear" and "wishlist" or "resources"];for _,entry in ipairs(entries) do if entry.id==id then layout.navigate("journey",{page=kind=="gear" and "Gear" or "Budget",selected=id});return end end
	elseif origin=="gems" then
		if build.planningWorkspace then build.planningWorkspace:Remember("filters") end;build:SelectControl(nil);build.viewMode="SKILLS";return
	end
	error("The linked source is no longer available. Refresh pickups to remove its generated rules.")
end
return M
