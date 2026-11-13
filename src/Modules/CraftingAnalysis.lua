-- Build-owned, transient calculation results. Views may be rebuilt mid-job.
local tasks=require("Modules.CraftingTasks")
local M={}
function M.reset(build)
	if tasks.job and tasks.job.build==build then tasks.cancel("The active build changed") end
	build.craftingAnalyses=nil
end
function M.get(build,project,restored)
	build.craftingAnalyses=build.craftingAnalyses or {}
	local session=build.craftingAnalyses[project.id]
	if session and session.raw==project.startingItem then return session end
	session={raw=project.startingItem,results={}}
	build.craftingAnalyses[project.id]=session
	if restored then
		if restored.lastSimulation then session.results.simulation={result=restored.lastSimulation,context=restored.lastSimulationRun} end
		if restored.lastFossilComparison then session.results.fossils={result=restored.lastFossilComparison} end
	end
	function session:deliver(announce)
		if self.receiver then self.receiver(self.event,announce and self.visible and self.visible() or false) end
	end
	function session:bind(owner,receiver,visible)
		self.owner,self.receiver,self.visible=owner,receiver,visible
		if tasks.job and tasks.job.analysis==self then tasks.job.owner=owner end
		if self.event then self:deliver(false) end
	end
	function session:start(kind,context,run)
		assert(kind=="simulation" or kind=="fossils" or kind=="odds","Unknown crafting analysis")
		local captured=context and copyTable(context)
		local job=tasks.start(build,run,function(result)
			self.results[kind]={result=result,context=captured}
			self.event={kind=kind,phase="done",result=result,context=captured};self:deliver(true)
		end,function(message)
			self.event={kind=kind,phase="error",message=message};self:deliver(false)
		end,function(progress)
			self.event={kind=kind,phase="progress",progress=progress};self:deliver(false)
		end)
		job.analysis=self;job.owner=self.owner
		self.event={kind=kind,phase="queued"};self:deliver(false)
		return job
	end
	function session:clearSimulation()
		self.results.simulation=nil
		self.event=nil
	end
	return session
end
return M
