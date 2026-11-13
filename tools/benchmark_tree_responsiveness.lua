-- Read-only headless benchmark. Run from src; the supplied build is never saved.
local fixture = assert(arg[1], "Supply a build XML path")
local cycles = arg[2] and assert(tonumber(arg[2]), "Cycle count must be numeric") or 5
assert(cycles == math.floor(cycles) and cycles >= 1 and cycles <= 20, "Use 1 to 20 cycles")
arg = {}
dofile("HeadlessWrapper.lua")
main.disableDevAutoSave = true
local file = assert(io.open(fixture, "rb"))
local raw = file:read("*a")
file:close()
loadBuildFromXML(raw, "Read-only tree responsiveness")
assert(not main.popups[1], "The supplied build requires conversion")

local bridge, tasks = require("Modules.DesktopBuildBridge"), require("Modules.RecoveryTasks")
local before = bridge.revision(build)
local rows = {}
local function finish()
	local count, total, worst = 0, 0, 0
	while build.calcsTab.recoveryJob do
		assert(count < 100000, "Recovery worker did not complete")
		local start = os.clock()
		tasks.tick(build.calcsTab)
		local elapsed = (os.clock() - start) * 1000
		count, total, worst = count + 1, total + elapsed, math.max(worst, elapsed)
	end
	return { count = count, totalMs = total, worstMs = worst }
end

for _ = 1, cycles do
	local selected
	for _, node in pairsSortByKey(build.spec.nodes) do
		if not node.alloc and node.type == "Normal" and not node.isMultipleChoiceOption
			and not node.ascendancyName and node.path and #node.path == 1 then
			selected = node
			break
		end
	end
	assert(selected, "No adjacent ordinary passive is available")
	local start = os.clock()
	build.spec:AllocNode(selected)
	local allocated = os.clock()
	build.calcsTab:BuildOutput(true)
	local calculated = os.clock()
	local recovery = finish()
	rows[#rows + 1] = { node = selected.id, allocationMs = (allocated - start) * 1000,
		outputMs = (calculated - allocated) * 1000, recovery = recovery }
	build.spec:DeallocSingleNode(selected)
	build.spec:BuildAllDependsAndPaths()
	build.calcsTab:BuildOutput(true)
	finish()
end
assert(bridge.revision(build) == before, "The benchmark did not restore the original build revision")
print("TREE_RESPONSIVENESS " .. require("dkjson").encode({ restored = true, cycles = rows,
	limitations = "CPU timings in a headless process; not a sustained desktop frame-rate measurement." }))
