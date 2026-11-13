-- Isolated native desktop side of the stdio MCP integration test. No live app.
local directory=assert(arg[1]):gsub("\\","/").."/"
io.stdout:setvbuf("no")
io.stderr:write("Native workflow: loading headless wrapper\n")
arg={};dofile("HeadlessWrapper.lua")
io.stderr:write("Native workflow: installing UI recorder\n")
local json=require("dkjson")
local bridge=require("Modules.DesktopBuildBridge")
local ui=require("Modules.HeadlessUI").install({width=1024,height=768})
local function frame()
	-- Each native frame replaces the recorder's previous draw commands.
	-- Calling OnFrame directly retains every tree draw across the whole workflow.
	ui:frame(function() runCallback("OnFrame") end)
end
io.stdout:setvbuf("no")
main.userPath=directory;main.buildPath=directory;main.defaultBuildPath=directory;main.disableDevAutoSave=true
newBuild()
io.stderr:write("Native workflow: calculating fixture\n")
build.buildName="MCP workflow fixture";build.characterLevel=80;build.characterLevelAutoMode=false
build.buildFlag=true;frame();ui:bind(build)
bridge.enable(build)
io.stderr:write("Native workflow: bridge ready\n")
local function respond(value) io.stdout:write("WORKFLOW\t"..json.encode(value).."\n") end
respond({ready=true,revision=bridge.revision(build)})
for line in io.lines() do
	local command=assert(json.decode(line))
	local ok,result=xpcall(function()
		if command.kind=="tick" then
			for i=1,command.frames or 1 do frame();bridge.poll(build,true) end
		elseif command.kind=="request-test" then bridge.connectionTest={nonce="workflow-connection-test",requestedAt=os.time()};bridge.publishState()
		elseif command.kind=="connection-proof" then return {client=bridge.client and bridge.client.name,tested=bridge.connectionTest and bridge.connectionTest.passed,synced=bridge.client and bridge.client.contextRevision==bridge.contextRevision}
		elseif command.kind=="apply" then
			assert(bridge.prepared,"Expected a pending native review")
			build.viewMode="CONFIG";ui:bind(build);ui:click("aiBuild");ui:click("review");ui:click("apply")
			assert(not main.popups[1],"Native apply did not finish")
			build=main.modes.BUILD;ui:bind(build);frame();bridge.refresh(build)
		elseif command.kind=="save-reopen" then
			build.viewMode="CONFIG";ui:bind(build);ui:click("aiBuild");ui:click("nav_crafting");ui:click("native")
			ui:click("currency_alchemy");ui:click("item");ui:click("keepWorking")
			assert(build.savers.CraftingProjects.projects[1].run,"Checkpoint was not kept")
			build.dbFileName=directory.."journey.xml";build:SaveDBFile()
			assert(require("Modules.PlanningUI").saveStatus(build)=="Build saved","Save status did not acknowledge the actual file save")
			local file=assert(io.open(directory.."journey.xml","rb"));local xml=file:read("*a");file:close()
			bridge.disable(build);loadBuildFromXML(xml,"MCP workflow fixture");build=main.modes.BUILD;ui:bind(build)
			assert(not main.popups[1],"Reload opened a popup: "..tostring(main.popups[1] and main.popups[1].title).." | "..tostring(main.popups[1] and main.popups[1].controls[1] and main.popups[1].controls[1].label))
			assert(#build.savers.BuildJourney.data.wishlist==2 and #build.savers.CraftingProjects.projects==2,"Saved plans did not reload")
			build.viewMode="CONFIG";ui:click("aiBuild");ui:click("nav_crafting");ui:click("native")
			assert(build.planningWorkspace.controls.undo:IsEnabled(),"Saved checkpoint did not restore undo")
			bridge.enable(build)
		elseif command.kind=="bundle-roundtrip" then
			build.viewMode="CONFIG";ui:bind(build);ui:click("aiBuild");ui:click("nav_tools");ui:text("search","bundle");ui:click("choose");ui:click("export");ui:click("paste");ui:click("review")
			assert(bridge.prepared and bridge.prepared.mode=="new","Bundle did not prepare a new build")
			ui:click("apply");build=main.modes.BUILD;ui:bind(build);frame()
			assert(not build.dbFileName and #build.savers.AtlasPlans.plans==2 and build.savers.CraftingProjects.projects[1].run,"Bundle import lost saved metadata or reused the source file")
			local body=build.savers.CraftingProjects.projects[2]
			assert(body and body.id=="body-enchant" and body.nativeRecipe.requirements.harvestEnchant=="LifeBodyEnchant" and body.inventory[1].state.harvestEnchant=="LifeBodyEnchant","Bundle import lost the second gear guide or its enchantment")
		elseif command.kind=="quit" then bridge.disable(build);return {quit=true}
		else error("Unknown host command") end
		return {revision=bridge.revision(build),status=bridge.status and bridge.status.status,life=build.calcsTab.calcsOutput.LifeUnreserved,drawCommands=#ui.commands}
	end,debug.traceback)
	respond({id=command.id,ok=ok,result=ok and result or nil,error=not ok and tostring(result) or nil})
	if command.kind=="quit" then break end
end
ui:restore()
