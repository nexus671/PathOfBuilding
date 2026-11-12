-- Resume isolated candidate calculations without leaking their main/cache across frames.
local M={}
function M.new(build,run)
	local job={build=build,phase="Queued",slices=0,maxSlice=0}
	job.thread=coroutine.create(function() return run(function(phase)
		if phase then job.phase=phase end
		if phase or os.clock()>=job.deadline then coroutine.yield() end
	end) end)
	return job
end
function M.resume(job)
	local activeMain,activeCache,activeError=main,GlobalCache,launch.ShowErrMsg
	if job.context then main,GlobalCache,launch.ShowErrMsg=job.context.main,job.context.cache,job.context.showError end
	local start=os.clock();local phase=job.phase;job.deadline=start+0.004
	local ok,result=coroutine.resume(job.thread)
	job.context={main=main,cache=GlobalCache,showError=launch.ShowErrMsg}
	main,GlobalCache,launch.ShowErrMsg=activeMain,activeCache,activeError
	local elapsed=os.clock()-start;job.slices=job.slices+1;job.maxSlice=math.max(job.maxSlice,elapsed*1000)
	require("Modules.PlanningPerformance").record(job.build,"Upgrade: "..phase,elapsed)
	if not ok or coroutine.status(job.thread)=="dead" then job.context=nil;return true,ok,result end
	return false,true
end
return M
