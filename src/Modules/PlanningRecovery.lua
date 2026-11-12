-- Two rotating local draft slots survive an interrupted write. Never applies a build.
local json=require("dkjson")
local data=require("Modules.PlanningData")
local M={cache={},limit=4*1024*1024,session=require("sha1")(os.time()..tostring({}))}
local kinds={filters=true,atlas=true,crafting=true}
local function path(build,kind,slot)
	assert(kinds[kind],"Unsupported draft type")
	if launch.headless and not M.testDirectory then return end
	local directory=M.testDirectory or main.userPath.."PlanningDrafts"
	local id=require("sha1")((build.dbFileName or "untitled:"..(build.buildName or ""))..":"..GetScriptPath())
	return directory.."/"..id.."-"..kind.."-"..slot..".json",directory
end
function M.clean(kind,entry)
	local value=assert(entry.plan,"Missing draft")
	if kind=="filters" then return {plan={data=require("Modules.LootFilters").validate(value.data),selected=value.selected,page=value.page,dirty=true}}
	elseif kind=="atlas" then
		local view=entry.view;local savedView
		if view then
			savedView={};for _,key in ipairs({"title","notes","budgetText","search"}) do assert(type(view[key])=="string" and #view[key]<=8000,"Invalid Atlas draft text");savedView[key]=view[key] end
			for _,key in ipairs({"centerX","centerY","scale","focus","inspectorWidth"}) do local v=view[key];assert(v==nil or type(v)=="number" and v==v and math.abs(v)<1e7,"Invalid Atlas view");savedView[key]=v end
			assert(savedView.scale and savedView.scale>0,"Invalid Atlas scale")
			savedView.page=view.page=="Notes & sharing" and view.page or "Tree";savedView.mechanic=view.mechanic;savedView.avoided=copyTable(value.avoided or {});savedView.undo={};savedView.redo={}
		end
		return {plan=require("Modules.AtlasPlanner").validate(value),view=savedView}
	elseif kind=="crafting" then
		assert(value.kind=="workbench","Only working crafts need draft recovery")
		local project=require("Modules.CraftingProjects").validate(value.project);local run=copyTable(value);run.schemaVersion=1
		local result=require("Modules.CraftingCheckpoint").validate(project.startingItem,run);result.project=project;result.kind="workbench"
		return {plan=result}
	end
	error("Unsupported draft type")
end
function M.isCurrent(build,kind,entry)
	local ok,result=pcall(function()
		if kind=="filters" then return data.hash(entry.plan.data)==data.hash(build.savers.LootFilters.data)
		elseif kind=="atlas" then
			local plan=copyTable(entry.plan);local view=entry.view
			if view then plan.title=view.title;plan.notes=view.notes;plan.budget=tonumber(view.budgetText) end
			plan=require("Modules.AtlasPlanner").validate(plan)
			for _,saved in ipairs(build.savers.AtlasPlans.plans) do if saved.id==plan.id then return data.hash(saved)==data.hash(plan) end end
		elseif kind=="crafting" then
			local working=entry.plan;local run=copyTable(working);run.project=nil;run.kind=nil
			for _,project in ipairs(build.savers.CraftingProjects.projects) do if project.id==working.project.id and project.startingItem==working.project.startingItem and project.run then
				return data.hash(project.run)==data.hash(run)
			end end
		end
		return false
	end)
	return ok and result==true
end
function M.load(build,kind)
	local best
	for slot=1,2 do local filePath=path(build,kind,slot);if not filePath then return end
		local file=io.open(filePath,"rb");if file then
			local raw=file:read(M.limit+1);file:close()
			if #raw<=M.limit then local ok,value=pcall(function()
				local record=assert(json.decode(raw));assert(record.schemaVersion==1 and record.kind==kind and type(record.generation)=="number" and record.generation==math.floor(record.generation) and record.generation>=1 and record.generation<1e12,"Invalid recovery record")
				assert(type(record.at)=="number" and record.at>=0 and record.at<4102444800,"Invalid recovery date")
				assert(record.digest==data.hash(record.entry),"Incomplete recovery record");record.entry=M.clean(kind,record.entry);record.path=filePath;return record
			end);if ok and (not best or value.generation>best.generation) then best=value end end
		end
	end
	return best
end
function M.save(build,kind,entry,force)
	local _,directory=path(build,kind,1);if not directory then return end
	local key=directory..":"..(build.dbFileName or build.buildName or "")..":"..kind;local cache=M.cache[key] or {build=build};M.cache[key]=cache
	local now=GetTime();if not force and cache.checked and now-cache.checked<2000 then return end;cache.checked=now
	local ok,message=pcall(function()
		local clean=M.clean(kind,entry);local digest=data.hash(clean);if digest==cache.digest then return end
		local old=M.load(build,kind)
		if old and old.session~=M.session and not cache.acknowledged and not M.isCurrent(build,kind,old.entry) then cache.pending=true;return end
		cache.pending=false
		local generation=(old and old.generation or 0)+1
		local record={schemaVersion=1,kind=kind,generation=generation,at=os.time(),digest=digest,entry=clean,session=M.session}
		local raw=json.encode(record);assert(#raw<=M.limit,"Recovery draft exceeds 4 MiB; keep the working project in the build")
		MakeDir(directory);local target=path(build,kind,generation%2+1);local file=assert(io.open(target,"wb"),"Could not create recovery draft")
		local written=file:write(raw);local closed=file:close();assert(written and closed,"Could not finish recovery draft");cache.digest=digest
	end)
	M.lastError=not ok and tostring(message) or nil;return ok,message
end
function M.acknowledge(build,kind)
	local _,directory=path(build,kind,1);if not directory then return end
	local key=directory..":"..(build.dbFileName or build.buildName or "")..":"..kind
	M.cache[key]=M.cache[key] or {build=build};M.cache[key].acknowledged=true;M.cache[key].pending=false
end
function M.clear(build,kind)
	for slot=1,2 do local target=path(build,kind,slot);if target then local ok,why,code=os.remove(target);assert(ok or code==2,why) end end
	M.acknowledge(build,kind)
	for _,cache in pairs(M.cache) do if cache.build==build then cache.digest=nil;cache.checked=nil end end
end
function M.hasPending(build) for _,cache in pairs(M.cache) do if cache.build==build and cache.pending then return true end end;return false end
return M
