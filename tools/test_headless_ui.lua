-- Run from src: luajit ../tools/test_headless_ui.lua <existing-output-directory>
local directory=assert(arg[1],"Supply an output directory")
arg={}
dofile("HeadlessWrapper.lua")
main.disableDevAutoSave=true
local UI=require("Modules.HeadlessUI")
local sim=require("Modules.CraftingSimulator")
local frames=0
for _,size in ipairs({{1280,720},{1024,768},{960,640}}) do
	newBuild();main.popups={}
	local ui=UI.install({width=size[1],height=size[2]})
	local function frame(name,hover)
		ui.cursorX,ui.cursorY=-100,-100
		if hover then local x,y=main.popups[1].controls[hover]:GetPos();ui.cursorX,ui.cursorY=x+10,y+10 end
		ui:frame():write(directory.."/"..size[1].."-"..name..".json");frames=frames+1
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
	end
	-- Exercise the actual build-tab event loop, not direct panel callbacks.
	local bridge=require("Modules.DesktopBuildBridge")
	local json=require("dkjson")
	local originalOpen,originalRemove=io.open,os.remove
	local files={}
	io.open=function(path,mode)
		local name=path:match("AI%-build%-(%w+)%.json$")
		if not name then return originalOpen(path,mode) end
		if mode=="rb" and not files[name] then return nil end
		return {read=function(_,limit) return files[name]:sub(1,type(limit)=="number" and limit or -1) end,
			write=function(_,value) files[name]=value;return true end,close=function() return true end}
	end
	os.remove=function(path) local name=path:match("AI%-build%-(%w+)%.json$");if name then files[name]=nil;return true end;return originalRemove(path) end
	bridge.enabled=false;bridge.prepared=nil;bridge.plan={goal="balanced"};bridge.history={};bridge.undo={};bridge.owner=nil;bridge.previous=nil;bridge.comparison=nil
	build.viewMode="CONFIG";ui:bind(build);ui:click("aiBuild")
	assert(build.viewMode=="PLANNER" and #main.popups==0,"AI planner did not open as a native build tab")
	frame("ai-overview");ui:click("goals");frame("ai-goals")
	ui:text("budget","100");ui:text("minimumLife","3000");ui:click("save")
	ui:key("TAB");assert(build.planningWorkspace.body.selControl and build.planningWorkspace.body.selControl.hasFocus,"Tab did not retain visible keyboard focus");frame("planning-keyboard-focus");ui:key("ESCAPE")
	ui.keys.ALT=true;ui:key("2");assert(build.viewMode=="PLANNER" and build.planningWorkspace.page=="atlas","Alt+2 did not switch planning tools");ui:key("1");ui.keys.ALT=nil
	assert(bridge.plan.budget==100 and bridge.plan.minimums and bridge.plan.minimums.LifeUnreserved==3000,json.encode(bridge.plan).." popup="..tostring(main.popups[1] and main.popups[1].title))
	ui:click("candidates");frame("ai-empty-candidates");ui:click("close")
	ui:click("analysis");frame("ai-analysis");ui:click("close")
	ui:choose("page","Connection");frame("ai-connection");ui:click("setup")
	assert(ui.clipboard:find("McpServer.cjs",1,true))
	ui:click("enable");assert(bridge.enabled and files.context and files.state)
	ui:click("testConnection")
	files.client=json.encode({schemaVersion=1,session=bridge.session,name="Headless MCP client",seenAt=os.time(),contextRevision=bridge.contextRevision,testNonce=bridge.connectionTest.nonce})
	bridge.poll(build,true);assert(bridge.connectionTest.passed and bridge.client.name=="Headless MCP client","Client round-trip receipt was not recognized")
	frame("ai-client-confirmed")
	ui:click("diagnostics");frame("ai-diagnostics");ui:click("close")
	ui:choose("page","Plan & review")
	local original=main.modes.BUILD
	local prepared=bridge.prepare(original,{mode="edit",title="Headless life upgrade",baseRevision=bridge.revision(original),operations={{type="equip_item",slot="Helmet",text="Rarity: RARE\nTrial Hat\nIron Hat\nItem Level: 86\n+100 to maximum Life"}}})
	prepared.id="headless-review"
	prepared.audit.assumptions[#prepared.audit.assumptions+1]={text="Enabled condition: conditionFullEnergyShield. Check its source and uptime."}
	for i=1,60 do prepared.audit.assumptions[#prepared.audit.assumptions+1]={text="Review checklist entry "..i..": verify conditions and uptime before applying the candidate."} end
	bridge.remember(prepared);bridge.prepared=prepared
	ui:click("review");frame("ai-review-summary")
	ui:click("toggleMetrics");frame("ai-review-all-metrics");ui:click("toggleMetrics")
	ui:choose("page","Changes");frame("ai-review-changes")
	ui:choose("page","Checks");frame("ai-review-checks")
	ui:choose("page","Explain");frame("ai-review-explanation");assert(main.popups[1].controls.details.list[1][1]:find("Measured",1,true))
	ui:click("close");ui:click("candidates");frame("ai-candidates");ui:click("review")
	ui:click("apply");assert(main.modes.BUILD~=original,"Apply did not open the calculated candidate")
	ui:frame();ui:click("nav_ai");frame("ai-applied");ui:click("restore")
	assert(main.modes.BUILD==original,"Undo did not restore the original scratch build")
	ui:click("nav_atlas");frame("atlas-new-default");assert(build.planningWorkspace.controls.canvas.tree.version=="3.30.0-preview","New Atlas plan did not default to 3.30")
	ui:choose("version","3.29.3");ui:click("confirm");frame("atlas-start");assert(not build.controls.statBox:IsShown(),"Build sidebar should be hidden while planning")
	local workspace=build.planningWorkspace
	build.buildFlag=true;ui:frame();ui:click("nav_tools");frame("planning-tools");ui:click("choose");frame("performance-diagnostics");ui:click("copy");assert(ui.clipboard:find("ms",1,true));ui:click("refresh");ui:click("close")
	local canvas=workspace.controls.canvas
	ui:choose("mechanic","Essence");assert(next(canvas.matches),"Inline mechanic filter did not highlight its nodes");frame("atlas-mechanic-filter");ui:choose("mechanic","All mechanics")
	ui:text("budget","120");assert(workspace.controls.status.label:find("120 points",1,true),"Point budget feedback is stale");ui:text("budget","138")
	ui:text("search","Unwavering Vision");ui:click("find");frame("atlas-search")
	assert(canvas.focus==65225 and workspace.controls.allocate.label:find("+",1,true),"The selected route should preview its point cost")
	local x,y=canvas:GetPos();ui:clickAt(x+canvas.width/2,y+canvas.height/2,true)
	frame("atlas-connected");assert(workspace.controls.status.label:find("20 granted",1,true))
	ui:click("remove");frame("atlas-removed");ui:click("avoid");frame("atlas-avoided");ui:click("clearAvoid");ui:click("undo")
	ui:click("undo");assert(workspace.controls.avoid.label=="Avoid selected","Undo did not restore exclusions");ui:click("redo");ui:click("undo")
	ui:click("undo");ui:click("undo");assert(workspace.controls.status.label:find("0 /",1,true),workspace.controls.status.label);ui:click("allocate")
	ui:click("stats");frame("atlas-stats");ui:click("close")
	ui:click("browse");ui:choose("category","Essence");ui:text("search","Essence");frame("atlas-node-browser");ui:click("choose")
	assert(next(workspace.controls.canvas.matches),"Mechanic selection did not highlight nodes")
	local map=workspace.controls.canvas;local mx,my=map:GetPos();local oldY=map.centerY
	ui:clickAt(mx+map.width-70,my+map.height-60);assert(map.centerY~=oldY,"Minimap did not navigate");frame("atlas-minimap")
	ui:click("routes");frame("atlas-route-options");ui:click("close")
	ui:click("tools");ui:text("search","Strategy");ui:click("choose");frame("atlas-presets");ui:click("close")
	local divider=workspace.controls.splitter;local dx,dy=divider:GetPos();local priorWidth=workspace.controls.canvas.width
	ui.cursorX,ui.cursorY=dx+5,dy+50;ui:dispatch(build,{{type="KeyDown",key="LEFTBUTTON"}});ui.cursorX=ui.cursorX-24;ui:dispatch(build,{{type="KeyUp",key="LEFTBUTTON"}})
	assert(workspace.controls.canvas.width<priorWidth,"Atlas divider did not resize the inspector");frame("atlas-split")
	ui:text("title",string.rep("Long Atlas strategy ",5));frame("atlas-long-title")
	ui:choose("page","Notes & sharing");ui:text("notes","Essence and map sustain. Save this strategy.");frame("atlas-notes")
	ui:click("copy");local exported=ui.clipboard;assert(json.decode(exported).atlasPlan.notes:find("Essence",1,true))
	ui:click("import");ui:click("url");assert(ui.clipboard:find("fullscreen-atlas-skill-tree",1,true));ui:click("close")
	ui.clipboard=exported
	ui:click("nav_ai")
	local alternate=size[1]==1280 and {1024,768} or {1280,720}
	ui:resize(alternate[1],alternate[2]);frame("workspace-resized");ui:click("nav_atlas")
	assert(workspace.controls.notes.buf:find("Essence",1,true),"Resizing on another page lost the Atlas draft")
	frame("atlas-resized");ui:resize(size[1],size[2]);ui:frame()
	local savedTitle=workspace.controls.title.buf;ui:text("title","");ui:text("budget","-1");ui:resize(alternate[1],alternate[2]);ui:frame()
	assert(workspace.controls.title.buf=="" and workspace.controls.budget.buf=="-1","Unfinished Atlas edits were lost on resize")
	ui:resize(size[1],size[2]);ui:frame();ui:text("title",savedTitle);ui:text("budget","138")
	ui:click("nav_build");ui:click("modeItems");ui:click("modeSkills");ui:click("atlas");assert(workspace.controls.notes.buf:find("Essence",1,true),"Switching tools lost the Atlas draft")
	ui:click("keep");assert(#build.savers.AtlasPlans.plans==1)
	local starter=copyTable(build.savers.AtlasPlans.plans[1]);starter.id="starter-atlas";starter.title="Starter maps";starter.nodes={};starter.progression={stage="starter"};build.savers.AtlasPlans:Upsert(starter)
	ui:click("progression");ui:choose("stage","final","val");ui:choose("previous","starter-atlas","val");frame("atlas-progression")
	ui:click("strategyTab");ui:text("maps","T16 maps; avoid reflect");ui:text("scarabs","Record scarabs here");ui:text("requirements","Complete map unlocks");ui:text("avoid","Reflect");ui:text("amount","25");ui:text("source","Manual test quote");frame("atlas-strategy-requirements");ui:click("keep");ui:click("keep")
	assert(build.savers.AtlasPlans.plans[1].strategy.setupCost.amount==25 and build.savers.AtlasPlans.plans[1].progression.previousId=="starter-atlas","Atlas strategy was not kept")
	ui:choose("page","Tree");ui:click("tools");ui:text("search","Compare");ui:click("choose");frame("atlas-compare");ui:click("close")
	ui:click("tools");ui:text("search","history");ui:click("choose");frame("atlas-history");ui:click("close")
	ui:click("library");frame("atlas-library");ui:click("open")
	ui:choose("page","Tree");ui:click("fit");frame("atlas-fit")
	canvas=workspace.controls.canvas;x,y=canvas:GetPos();ui.cursorX,ui.cursorY=x+canvas.width/2,y+canvas.height/2
	local scale=canvas.scale;ui:key("WHEELUP");assert(canvas.scale>scale,"Wheel did not zoom the Atlas canvas")
	local oldCenter=canvas.centerX;ui:dragAt(x+canvas.width/2,y+canvas.height/2,45,20)
	assert(canvas.centerX~=oldCenter,"Dragging did not pan the Atlas canvas");frame("atlas-panned")
	ui:choose("version","3.27.0");frame("atlas-version-confirm");ui:click("confirm")
	assert(workspace.controls.canvas.tree.version=="3.27.0")
	frame("atlas-legacy")
	ui:click("nav_crafting");frame("crafting-empty-workspace")
	ui:click("new");frame("crafting-project-editor")
	ui:text("title","Life helmet");ui:text("starting","Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: R-G-B")
	ui:click("next");frame("crafting-wizard-target");ui:text("goals","Life\nResistances");ui:click("next");frame("crafting-wizard-plan");ui:text("steps","Roll life\nCheck resistances");ui:click("next");frame("crafting-wizard-review");ui:click("save")
	assert(#build.savers.CraftingProjects.projects==1 and #build.savers.CraftingProjects.projects[1].goals==2,"Project editor lost pasted line breaks")
	frame("crafting-workspace")
	ui:click("native");frame("crafting-workspace-item")
	assert(not main.popups[1],"Workbench should be embedded in the planning workspace")
	ui:click("currency_alchemy");ui:click("item");frame("workspace-crafted")
	assert(require("Modules.PlanningUI").saveStatus(build):find("Working draft",1,true),"Working item was incorrectly presented as saved")
	assert(not workspace.controls.apply:IsEnabled() and workspace.controls.currency_chaos:IsEnabled(),"Currency eligibility did not follow the crafted rarity")
	ui:click("history");frame("crafting-history");ui:choose("state",1,"val");frame("crafting-history-before");ui:click("restore")
	assert(not workspace.controls.undo:IsEnabled(),"History restore did not undo subsequent actions");ui:click("currency_alchemy");ui:click("item")
	ui:click("settings");assert(not main.popups[1],"Currency search should stay beside the item");assert(workspace.body.selControl==workspace.controls.paletteSearch,"Currency search should take keyboard focus")
	ui:text("paletteSearch","Divine");ui:click("paletteFavorite");frame("crafting-palette");ui:choose("paletteCategory","Favorites");frame("crafting-favorites")
	ui:resize(alternate[1],alternate[2]);ui:frame();assert(workspace.controls.paletteSearch:IsShown() and workspace.controls.paletteSearch.buf=="Divine","Resizing lost inline currency search");assert(not workspace.controls.item:IsEnabled(),"Browsing currencies should not apply one by clicking the item")
	ui:resize(size[1],size[2]);ui:frame();ui:click("paletteUse")
	assert(workspace.controls.selectedAction:GetProperty("label"):find("Divine",1,true))
	local mods=workspace.controls.itemMods;local ax,ay=mods:GetPos();local top=2-mods.controls.scrollBar.offset;local targetY
	for _,row in ipairs(mods.list) do if row.affixId then targetY=ay+top+row.height/2;break end;top=top+row.height end
	assert(targetY,"Crafted item has no selectable modifiers");ui:clickAt(ax+mods.width/2,targetY)
	assert(not main.popups[1] and workspace.controls.affixFacts:IsShown(),"Modifier inspection should stay beside the item");frame("crafting-inline-inspector")
	ui:resize(alternate[1],alternate[2]);ui:frame();assert(workspace.controls.affixFacts:IsShown(),"Resizing lost the inspected modifier");ui:resize(size[1],size[2]);ui:frame()
	ui:click("affixTarget");assert(workspace.controls.targetSummary:IsShown(),"Inline inspector did not add the target");frame("crafting-inline-target");ui:choose("page","Emulate item")
	local split=workspace.controls.splitter;local sx,sy=split:GetPos();local oldItemX=select(1,workspace.controls.item:GetPos())
	ui.cursorX,ui.cursorY=sx+5,sy+80;ui:dispatch(build,{{type="KeyDown",key="LEFTBUTTON"}});ui.cursorX=ui.cursorX+32;ui:dispatch(build,{{type="KeyUp",key="LEFTBUTTON"}})
	assert(select(1,workspace.controls.item:GetPos())>oldItemX,"Crafting divider did not resize panels");frame("crafting-split")
	ui:click("nav_atlas");ui:click("nav_crafting")
	assert(workspace.controls.undo:IsEnabled(),"Switching tools lost crafting history")
	ui:resize(alternate[1],alternate[2]);frame("workbench-resized")
	assert(workspace.controls.undo:IsEnabled() and #workspace.controls.itemMods.list>=4,"Resizing lost the crafted item")
	ui:resize(size[1],size[2]);ui:frame();ui:click("close");ui:click("native")
	assert(workspace.controls.undo:IsEnabled(),"Returning to a project lost the working item")
	ui:click("settings");ui:choose("paletteCategory","Favorites");frame("crafting-restored-favorites");assert(workspace.controls.paletteUse:IsEnabled(),"Favorites were lost when resizing or reopening the project");ui:key("ESCAPE");assert(not workspace.controls.paletteSearch:IsShown(),"Escape did not return to the currency tray")
	ui:click("undo");ui:click("close")
	ui:choose("libraryPage","Plan");frame("crafting-plan");ui:click("done");ui:click("undoStep")
	ui:choose("libraryPage","Sharing");frame("crafting-sharing");ui:click("copy")
	assert(json.decode(ui.clipboard).title=="Life helmet")
	ui:choose("libraryPage","Item")
	bridge.disable(build);io.open,os.remove=originalOpen,originalRemove
	ui:bind(nil)
	local project={id="headless-ui",title="Headless crafting check",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: R-G-B",
		goals={"Life and resistances"},steps={{action="Inspect native crafting"}}}
	build.savers.CraftingProjects:Upsert(project)
	require("Classes.CraftingProjectControl").Open(build)
	frame("projects");ui:choose("projects","Headless crafting check","label");ui:click("native")
	frame("emulator");frame("currency-tooltip","currency_alchemy")
	ui:click("currency_alchemy");ui:click("item")
	frame("crafted")
	assert(#main.popups[1].controls.itemMods.list>=4,"Clicking the item did not apply Alchemy")
	assert(main.popups[1].controls.intro.label:find("Applied Orb of Alchemy",1,true))
	ui:click("undo");frame("undone")
	assert(main.popups[1].controls.itemMods.list[1][1]:find("No explicit modifiers",1,true),"Undo did not restore the item")
	ui:click("currency_transmute");ui:click("item");frame("magic")
	assert(main.popups[1].controls.itemMods.list[1][1]:find("No explicit modifiers",1,true)==nil)
	ui:click("undo");ui:click("currency_chromatic");ui:click("item");frame("sockets")
	assert(main.popups[1].controls.intro.label:find("Applied Chromatic Orb",1,true))
	ui:click("undo");ui:click("currency_alchemy");ui:choose("page","Craft settings");ui:click("allflame")
	frame("allflame");ui:click("use");ui:choose("page","Emulate item");ui:click("apply")
	assert(main.popups[1].title=="Allflame outcomes")
	assert(#main.popups[1].controls.choice.list==4)
	frame("ghosts");ui:choose("choice",3,"val");ui:click("keep")
	frame("kept");ui:choose("page","Craft settings");ui:click("manual")
	frame("editor");ui:click("close")
	ui:choose("page","Target conditions")
	ui:click("targetPicker");ui:text("search","maximum Life");frame("crafting-target-picker");ui:click("choose")
	assert(#main.popups[1].controls.targetSummary.list>2,"Target picker did not add a target")
	ui:click("addTarget");ui:click("targetConditions")
	frame("targets");ui:choose("fractured","Fractured only");ui:click("keep")
	ui:choose("page","Simulate recipe")
	ui:choose("page","Craft settings");frame("settings");ui:click("inspectItem");frame("crafting-affix-inspector");ui:click("close")
	ui:click("compareItem");frame("crafting-item-diff");ui:click("close");ui:click("coverage");frame("crafting-coverage");ui:click("close");ui:choose("page","Simulate recipe")
	frame("simulation");ui:text("trials","12")
	ui:choose("page","Target conditions")
	ui:choose("page","Emulate item");ui:click("currency_chaos")
	ui:choose("page","Craft settings");ui:click("exact")
	local jobs=require("Modules.CraftingTasks")
	for i=1,100 do if not jobs.job then break end;jobs.tick(build) end
	assert(not jobs.job,"Action odds did not finish")
	ui:choose("page","Simulate recipe");ui:text("budget","2");ui:text("price","5");ui:text("baseCost","10");ui:click("simulate")
	for i=1,100 do if not jobs.job then break end;jobs.tick(build) end
	assert(not jobs.job,"Crafting simulation did not finish")
	frame("simulation-result");assert(#main.popups[1].controls.resultSummary.list>=4,"Detailed simulation results are missing")
	ui:click("editRecipe");frame("crafting-recipe-cards");ui:click("recovery");ui:choose("action","stop","val");ui:text("notes","Inspect unwanted rolls before spending more");frame("crafting-failure-recovery");ui:click("keep");frame("crafting-recovery-route");ui:click("keep")
	ui:click("distribution");frame("simulation-distribution");assert(main.popups[1].controls.successCard and main.popups[1].controls.medianSpend and main.popups[1].controls.veryUnluckySpend and main.popups[1].controls.moreTrials,"Simulation result cards are missing");ui:click("sample");frame("crafting-sampled-outcome");ui:click("close");ui:click("moreTrials")
	for i=1,100 do if not jobs.job then break end;jobs.tick(build) end
	assert(not jobs.job and main.popups[1].controls.trials.buf=="48","More trials did not rerun the captured setup")
	frame("simulation-refined")
	ui:click("simulate");ui:click("cancelJob");assert(not jobs.job);frame("simulation-cancelled")
	ui:click("compareRecipes");frame("crafting-recipe-comparison");ui:click("run")
	for i=1,200 do if not jobs.job then break end;jobs.tick(build) end
	assert(not jobs.job,"Recipe comparison did not finish");frame("crafting-comparison-result");ui:click("close")
	assert(main.popups[1].controls.trials.buf=="48","Native character events did not reach the edit control")
	ui:click("close");main.popups={}
	ui:bind(build);ui:click("nav_crafting");ui:click("native");ui:choose("page","Emulate item");ui:click(workspace.controls.currency_chaos:IsEnabled() and "currency_chaos" or "currency_alchemy");ui:click("item");ui:click("keepWorking")
	assert(build.savers.CraftingProjects.projects[1].run,"Working craft was not kept: "..tostring(main.popups[1] and main.popups[1].controls[1] and main.popups[1].controls[1].label))
	frame("crafting-checkpoint")
	workspace.craftDrafts={};workspace.cache.crafting=nil;workspace.drafts.crafting=nil;workspace:Show("crafting");ui:click("native")
	assert(workspace.controls.undo:IsEnabled(),"Saved working craft did not restore undo")
	frame("crafting-resumed")
	ui:click("nav_journey");frame("journey-empty")
	ui:click("nav_ai")
	bridge.calculateBatch(build,{id="guide-test",kind="leveling",baseRevision=bridge.revision(build),stages={{title="Early links",level=12,operations={}},{title="Later links",level=24,operations={}}}})
	ui:click("candidates");frame("journey-calculated-stages");ui:click("keepLeveling")
	assert(#build.savers.BuildJourney.data.stages==2,"Calculated leveling stages were not kept")
	frame("journey-captured-guide")
	ui:click("page4");ui:click("add");frame("journey-resource-editor")
	ui:text("title","Chaos Orbs");ui:text("unit","orbs");ui:click("keep")
	local resource=build.savers.BuildJourney.data.resources[1].id
	ui:click("record");ui:text("amount","100");ui:text("note","Starting stash");frame("journey-ledger-editor");ui:click("keep")
	assert(require("Modules.BuildJourney").budget(build.savers.BuildJourney.data)[resource].owned==100)
	frame("journey-budget")
	ui:click("page3");ui:click("add");ui:text("title","Final life helmet");ui:choose("slot","Helmet");ui:choose("route","craft")
	ui:choose("resourceId",resource,"val");ui:text("estimate","60");ui:choose("reserve","yes");ui:choose("projectId",build.savers.CraftingProjects.projects[1].id,"val")
	frame("journey-gear-editor");ui:click("keep");frame("journey-gear")
	ui:click("pasteTarget");ui:text("text","Rarity: RARE\nWishlist Hat\nIron Hat\nItem Level: 86\n+100 to maximum Life");frame("journey-paste-target");ui:click("keep")
	ui:click("expandDetails");frame("journey-expanded-details");ui:click("expandDetails")
	local splitter=workspace.controls.detailSplitter;local sx,sy=splitter:GetPos();local oldHeight=select(2,workspace.controls.details:GetSize())
	ui.cursorX,ui.cursorY=sx+40,sy+4;ui:dispatch(build,{{type="KeyDown",key="LEFTBUTTON"}});ui.cursorY=ui.cursorY-16;ui:dispatch(build,{{type="KeyUp",key="LEFTBUTTON"}})
	assert(select(2,workspace.controls.details:GetSize())>oldHeight,"Journey detail splitter did not resize the panel");frame("journey-resized-details")
	local gearId=build.savers.BuildJourney.data.wishlist[1].id
	local project=copyTable(build.savers.CraftingProjects.projects[1]);project.targetItem="Rarity: RARE\nJourney Hat\nIron Hat\nItem Level: 86\n+100 to maximum Life";build.savers.CraftingProjects:Upsert(project)
	ui:click("measure")
	for i=1,2000 do ui:frame();if not require("Modules.JourneyUpgrades").job then break end end
	assert(require("Modules.JourneyUpgrades").current(build).entries[gearId].status=="calculated","Native upgrade measurement did not finish")
	ui:choose("sort","LifeUnreserved","val");ui:click("perCost");frame("journey-upgrade-ranking")
	ui:click("compareAll");frame("journey-comparison-table");ui:click("choose")
	ui:click("reviewIssues");frame("journey-requirement-reasons");ui:click("close")
	ui:click("edit");ui:click("notesExpand");ui:text("text","Record exact target and price source");ui:click("keep");ui:click("keep");frame("journey-stale-ranking")
	local background=copyTable(build.savers.BuildJourney.data)
	for index=2,4 do local extra=copyTable(background.wishlist[1]);extra.id="background-"..index;extra.title="Background candidate "..index;background.wishlist[#background.wishlist+1]=extra end
	build.savers.BuildJourney:Replace(background);workspace:Show("journey",{page="Gear"});ui:click("measure");ui:click("nav_atlas")
	for i=1,2000 do ui:frame();if not require("Modules.JourneyUpgrades").job then break end end
	assert(workspace.page=="atlas","Finishing background upgrade measurements stole navigation")
	frame("journey-background-navigation")
	background.wishlist={background.wishlist[1]};build.savers.BuildJourney:Replace(background);ui:click("nav_journey");ui:click("page3")
	ui:click("page5");ui:click("add");ui:text("title","Campaign links");ui:text("level","12");ui:text("gems","Fireball + Combustion")
	ui:text("passives","Take nearby life");ui:text("quests","Finish Act 1");ui:text("transition","After finding a linked item");frame("journey-stage-editor")
	ui:click("gemsExpand");ui:text("text","Fireball + Combustion\nKeep an extra gem leveling");frame("journey-guide-text");ui:click("keep");ui:click("keep");frame("journey-leveling")
	ui:click("openLink");local quests=main.popups[1].controls.quests;local qx,qy=quests:GetPos();ui:clickAt(qx+30,qy+10);frame("journey-quest-guide");ui:click("close")
	assert(build.savers.BuildJourney.data.stages[3].questChecks[1]=="Finish Act 1","Quest completion was not kept")
	ui:click("page2");ui:click("add");ui:text("title","Craft the helmet");ui:choose("wishlistId",gearId,"val");ui:choose("projectId",build.savers.CraftingProjects.projects[1].id,"val")
	frame("journey-milestone-editor");ui:click("keep");frame("journey-roadmap")
	ui:click("complete");assert(build.savers.BuildJourney.data.milestones[1].done);ui:click("complete")
	ui:click("add");ui:text("title","Try the finished build");ui:click("dependencies");ui:text("search","Craft the helmet");frame("journey-prerequisite-picker")
	local picker=main.popups[1].controls.entries;local px,py=picker:GetPos();ui:clickAt(px+40,py+12);ui:click("keep");ui:click("keep")
	assert(build.savers.BuildJourney.data.milestones[2].dependencies[1]==build.savers.BuildJourney.data.milestones[1].id,"Prerequisite picker lost its selection")
	frame("journey-linked-progress")
	local milestones=workspace.controls.entries;local lx,ly=milestones:GetPos();ui:clickAt(lx+30,ly+10);ui:click("complete")
	assert(build.savers.BuildJourney.data.milestones[1].done and not build.savers.BuildJourney.data.milestones[2].done,"Clicking a different Journey entry did not select it")
	frame("journey-completed-progress");ui:click("complete")
	local entryX,entryY=workspace.controls.entries:GetPos();ui:clickAt(entryX+30,entryY+10)
	ui:key("DOWN");assert(workspace.controls.entries.selectedKey==2,"Keyboard navigation did not select the next milestone");frame("journey-keyboard-selection");ui:key("UP")
	ui:click("page1");frame("journey-overview");ui:click("openLink")
	assert(workspace.page=="crafting" and workspace.controls.keepWorking,"Journey link did not open the working craft")
	ui:click("nav_journey");ui.keys.ALT=true;ui:key("1");ui:key("4");ui.keys.ALT=nil
	assert(workspace.page=="journey","Alt+4 did not open Journey")
	ui:click("nav_text");frame("planning-large-text");ui:click("nav_text")
	ui:click("nav_tools");ui:text("search","bundle");ui:click("choose");frame("planning-bundle");ui:click("export");local bundle=ui.clipboard;assert(require("Modules.PlanningBundle").import(bundle).contents.checkpoints>=1,"Bundle omitted kept craft")
	ui:click("paste");frame("planning-bundle-inspected");bridge.prepared=nil;ui:click("review");frame("planning-bundle-review");ui:click("close");assert(main.modes.BUILD==build,"Bundle review changed the active build before Apply");bridge.prepared=nil

	ui:click("page5");ui:click("remove");ui:click("confirm");assert(#build.savers.BuildJourney.data.stages==2,"Guide stage removal failed")
	ui:click("nav_build")
	newBuild()
	local input=build.configTab.input
	input.simulateRecovery=true;input.recoverySimulationTrials=2;input.recoverySimulationWindow=3
	input.enemyDamageType="Untyped";input.enemyIsBoss="None";input.enemySpeed=1000;input.enemyCritChance=0
	input.enemyColdDamage="20";input.customMods="+3000 to maximum Life\n+60% to Cold Resistance"
	build.configTab:BuildModList();runCallback("OnFrame")
	local actor=build.calcsTab.calcsEnv.player
	assert(actor.recoverySimulationTrace and #actor.recoverySimulationTrace.points>1)
	build.calcsTab:OpenEncounterWorkspace();frame("encounter-workspace");ui:choose("preset",7,"val");ui:click("usePreset");frame("survival-scenario-assumptions");ui:click("create");assert(build.configTab.input.recoverySimulationColdDot==4,"Continuous damage preset did not preserve its stated scale");ui:click("chartUnits");frame("encounter-actual-values");ui:click("series_Life");ui:click("series_Mana");frame("encounter-series-hidden");ui:click("emptyLanes");frame("encounter-empty-lanes");ui:click("close")
	ui.cursorX,ui.cursorY=300,120
	ui:frame(function() build.calcsTab.controls.breakdown:DrawEncounterTimeline(16,16,{width=size[1]-32,timeline=actor.recoverySimulationTrace}) end)
	ui.regions={{0,0,size[1],size[2]}};ui:write(directory.."/"..size[1].."-recovery-hover.json");frames=frames+1
	ui.cursorX,ui.cursorY=-100,-100
	ui:frame(function() build.calcsTab.controls.breakdown:DrawEncounterTimeline(16,16,{width=size[1]-32,timeline=actor.recoverySimulationTrace}) end)
	ui.regions={{0,0,size[1],size[2]}}
	ui:write(directory.."/"..size[1].."-recovery-timeline.json");frames=frames+1
	newBuild();ui:bind(build)
	assert(not main.popups[1],"Preview setup: "..tostring(main.popups[1] and main.popups[1].title).." | "..tostring(main.popups[1] and main.popups[1].controls[1] and main.popups[1].controls[1].label))
	assert(build.spec.treeVersion=="3_30_preview","New builds should default to 3.30")
	ui:choose("versionSelect","3_29","value");ui:click("convert")
	ui:choose("versionSelect","3_30_preview","value");frame("covens-convert-preview");ui:click("convert")
	assert(build.spec.treeVersion=="3_30_preview","Native tree conversion did not select the preview")
	frame("covens-passive-tree");assert(table.concat(build.controls.warnings.lines," "):find("preview",1,true),"Preview warning missing")
	ui:click("atlas");ui:text("search","Massing Forces");ui:click("find");ui:click("allocate");frame("covens-atlas-tree")
	assert(build.planningWorkspace.controls.canvas.tree.maxPoints==150,"Atlas preview lost its 150 point budget")
	ui:click("keep");assert(build.savers.AtlasPlans.plans[1].version=="3.30.0-preview","Atlas preview version not retained")
	ui:restore()
end
-- These checks exercise the audit itself: raw uncoloured list text inherits the
-- background colour, and an oversized line must be detected as clipped.
local ui=UI.install({width=1024,height=768})
main:OpenPopup(600,200,"Audit controls",{details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,560,120},nil,
	{{height=18,"Unreadable regression fixture"},{height=18,colorCodes.NORMAL..string.rep("Oversized ",20)}})})
for i=1,2 do
	local control=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{16+(i-1)*90,156,140,24},"Overlap fixture",function() end)
	control.layoutAudit="negative-fixture";control.anchor.other=main.popups[1];main.popups[1].controls["overlap"..i]=control
end
ui:frame():write(directory.."/../expected-audit-failures.json")
ui:restore();main.popups={}
print("HEADLESS_UI_OK",frames)

