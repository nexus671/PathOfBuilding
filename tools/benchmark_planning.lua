-- Run from src: luajit ../tools/benchmark_planning.lua [read-only build XML]
local fixture=arg[1];arg={};dofile("HeadlessWrapper.lua")
main.disableDevAutoSave=true
if fixture then local file=assert(io.open(fixture,"rb"));local raw=file:read("*a");file:close();loadBuildFromXML(raw,"Performance fixture") else newBuild() end
assert(not main.popups[1],"Fixture requires interactive conversion")
local bridge=require("Modules.DesktopBuildBridge");local worker=require("Modules.PlanningWorker")
local originalMain,originalCache=main,GlobalCache
local proposal={mode="edit",title="Performance probe",baseRevision=bridge.revision(build),operations={{type="set_notes",text="Isolated performance probe"}}}
local start=os.clock();local synchronous=bridge.prepare(build,proposal);local syncMs=(os.clock()-start)*1000
local snapshotStart=os.clock();local frozen=bridge.freeze(build);local snapshotMs=(os.clock()-snapshotStart)*1000
local job=worker.new(build,function(checkpoint) return bridge.prepare(build,proposal,checkpoint,nil,frozen) end);local result
start=os.clock()
for i=1,100000 do
	local done,ok,value=worker.resume(job);assert(ok,value);assert(main==originalMain and GlobalCache==originalCache,"Background state leaked into active globals")
	if done then result=value;break end
end
assert(result and tableDeepEquals(synchronous.after,result.after) and tableDeepEquals(result.after,synchronous.after),"Background calculation differs")
assert(bridge.revision(build)==proposal.baseRevision,"Benchmark changed the source build")
print("PLANNING_BENCHMARK "..require("dkjson").encode({synchronousMs=syncMs,snapshotMs=snapshotMs,backgroundMs=(os.clock()-start)*1000,slices=job.slices,maxSliceMs=job.maxSlice,equivalent=true,timings=require("Modules.PlanningPerformance").rows(build)}))
