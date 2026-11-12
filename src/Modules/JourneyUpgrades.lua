-- Session-only measurements against an exact build revision. Never equips or saves.
local M={}
local revisions=require("Modules.PlanningRevision")
local stamp,sameStamp=revisions.stamp,revisions.same
M.metrics={
	{label="Priority",val="priority"},
	{label="Damage gain",val="CombinedDPS"},
	{label="Physical maximum hit gain",val="PhysicalMaximumHitTaken"},
	{label="Chaos maximum hit gain",val="ChaosMaximumHitTaken"},
	{label="Encounter survival gain",val="RecoverySimulationSurvivalChance"},
	{label="Life gain",val="LifeUnreserved"},
}
function M.target(build,entry)
	if entry.targetItem and entry.targetItem:match("%S") then return entry.targetItem end
	for _,project in ipairs(build.savers.CraftingProjects.projects) do if project.id==entry.projectId then return project.targetItem end end
end
function M.start(build,finish)
	assert(not M.job,"Upgrade calculation is already running")
	local bridge=require("Modules.DesktopBuildBridge")
	local frozen=require("Modules.PlanningPerformance").measure(build,"Capture upgrade snapshot",bridge.freeze,build)
	M.result={build=build,revision=frozen.revision,stamp=stamp(build),plan=copyTable(bridge.plan),entries={},completed=0,total=0}
	local entries={}
	for _,entry in ipairs(build.savers.BuildJourney.data.wishlist) do if entry.status=="planned" then entries[#entries+1]=copyTable(entry) end end
	M.result.total=#entries
	M.job={build=build,entries=entries,at=1,revision=M.result.revision,finish=finish,phase="Queued",frozen=frozen}
	return M.result
end
local function finish()
	local job=M.job;M.job=nil
	if job and job.finish then job.finish(M.export()) end
end
function M.cancel() if M.result then M.result.cancelled=true end;finish() end
function M.export()
	if not M.result then return end
	return {revision=M.result.revision,plan=copyTable(M.result.plan),entries=copyTable(M.result.entries),completed=M.result.completed,total=M.result.total,cancelled=M.result.cancelled,stale=M.result.stale,phase=M.result.phase,maxSliceMs=M.result.maxSlice}
end
function M.current(build)
	if not M.result or M.result.build~=build then return end
	return M.result
end
function M.fresh(build)
	local result=M.current(build);if not result then return false end
	local bridge=require("Modules.DesktopBuildBridge")
	return not result.stale and sameStamp(result.stamp,stamp(build)) and tableDeepEquals(result.plan,bridge.plan) and tableDeepEquals(bridge.plan,result.plan)
end
function M.tick(build)
	local job=M.job;if not job then return end
	if job.build~=build then M.cancel();return end
	if build.buildFlag then return end
	local bridge=require("Modules.DesktopBuildBridge")
	if not M.fresh(build) then M.result.stale=true;M.cancel();return end
	local entry=job.entries[job.at]
	if not entry then finish();return end
	local row=job.row or {id=entry.id,title=entry.title,slot=entry.slot,resourceId=entry.resourceId,cost=entry.estimate,perCost={}}
	local raw=M.target(build,entry)
	if not raw or not raw:match("%S") then row.status="missing-target";row.reason="Add an exact target item or link a craft with a target item."
	else
		local worker=require("Modules.PlanningWorker")
		if not job.worker then
			job.row=row
			job.worker=worker.new(build,function(checkpoint) return bridge.prepare(build,{mode="edit",title=entry.title,baseRevision=job.revision,operations={{type="equip_item",slot=entry.slot,text=raw}}},checkpoint,nil,job.frozen) end)
		end
		local done,ok,prepared=worker.resume(job.worker);job.phase=job.worker.phase
		M.result.phase=job.phase;M.result.maxSlice=math.max(M.result.maxSlice or 0,job.worker.maxSlice)
		if not done then return end
		job.worker=nil;job.row=nil
		if ok then
			row.status="calculated";row.before=prepared.before;row.after=prepared.after;row.delta=prepared.delta
			row.eligible=prepared.evaluation.eligible;row.issues=copyTable(prepared.evaluation.issues)
			row.introduced=copyTable(prepared.audit.introduced)
			if #row.introduced>0 then row.eligible=false;row.issues[#row.issues+1]="New dependency issues; review requirements before treating this as an upgrade." end
			if row.resourceId and row.cost and row.cost>0 then for metric,delta in pairs(row.delta) do row.perCost[metric]=delta/row.cost end end
		else row.status="failed";row.reason=tostring(prepared):match("[^\n]+") end
	end
	M.result.entries[entry.id]=row
	M.result.completed=M.result.completed+1;job.at=job.at+1
	if job.at>#job.entries then
		-- One exact final check guards results even against edits outside native controls.
		if M.result.revision~=bridge.revision(build) then M.result.stale=true;M.cancel() else finish() end
	end
end
function M.sorted(build,metric,perCost)
	local list=copyTable(build.savers.BuildJourney.data.wishlist)
	local result=M.current(build)
	local fresh=M.fresh(build)
	local function value(entry)
		local row=fresh and result.entries[entry.id]
		if not row or row.status~="calculated" or not row.eligible then return end
		if perCost then return row.perCost[metric] end
		return row.delta[metric]
	end
	table.sort(list,function(a,b)
		if metric~="priority" then
			-- Separate resource groups before comparing ratios; no exchange rate is assumed.
			if perCost and (a.resourceId~=nil)~=(b.resourceId~=nil) then return a.resourceId~=nil end
			if perCost and (a.resourceId or "")~=(b.resourceId or "") then return (a.resourceId or "")<(b.resourceId or "") end
			local av,bv=value(a),value(b)
			if (av~=nil)~=(bv~=nil) then return av~=nil end
			if av and av~=bv then return av>bv end
		end
		if a.priority~=b.priority then return a.priority<b.priority end;return a.id<b.id
	end)
	return list,fresh
end
return M
