describe("Desktop build proposals", function()
	local bridge = require("Modules.DesktopBuildBridge")
	local json = require("dkjson")
	-- Busted isolates spec globals; the bridge swaps the real process cache.
	local original, originalCache, files, open, remove
	before_each(function() newBuild(); original=build; originalCache=_G.GlobalCache; bridge.history={}; bridge.undo={}; bridge.plan={goal="balanced"}; bridge.owner=nil; bridge.comparison=nil end)
	after_each(function()
		main.modes.BUILD=original; bridge.enabled=false; bridge.prepared=nil; bridge.previous=nil; bridge.build=nil
		_G.GlobalCache=originalCache; bridge.previousCache=nil
		if open then io.open,os.remove=open,remove; open,remove=nil,nil end
	end)
	local function fakeFiles()
		files,open,remove = {},io.open,os.remove
		io.open = function(path,mode)
			if not path:match("AI%-build%-%w+%.json$") then return open(path,mode) end
			local name = path:match("AI%-build%-(%w+)%.json$")
			if mode == "rb" and not files[name] then return nil end
			return {read=function(_,size) return files[name]:sub(1,type(size) == "number" and size or -1) end,
				write=function(_,value) files[name]=value; return true end,close=function() return true end}
		end
		os.remove = function(path)
			local name = path:match("AI%-build%-(%w+)%.json$")
			if name then files[name]=nil; return true end
			return remove(path)
		end
	end
	local function proposal(operations,mode)
		return {mode=mode or "edit",title="AI test candidate",baseRevision=bridge.revision(build),operations=operations}
	end

	it("calculates edits without touching the desktop build, cache, or notes editor", function()
		local revision, cache = bridge.revision(build),_G.GlobalCache
		local prepared = bridge.prepare(build,proposal({{type="set_character",level=90},{type="equip_item",slot="Helmet",text="Rarity: RARE\nAI Hat\nIron Hat\n+100 to maximum Life"}}))
		assert.are.equal(90,prepared.candidate.characterLevel)
		assert.is_true(prepared.after.LifeUnreserved > prepared.before.LifeUnreserved)
		assert.are.equal(revision,bridge.revision(build))
		assert.are.equal(build,main.modes.BUILD)
		assert.are.equal(cache,_G.GlobalCache)
	end)

	it("creates a new character with native gem setup and a calculated main skill", function()
		local prepared = bridge.prepare(build,proposal({{type="set_character",level=80,className="Witch",ascendancy="Elementalist"},
			{type="set_skills",groups={{label="Main",includeInFullDPS=true,gems={{name="Fireball",level=20},{name="Combustion",level=20}}}},mainGroup=1}},"new"))
		assert.are.equal("Witch",prepared.candidate.spec.curClassName)
		assert.are.equal("Elementalist",prepared.candidate.spec.curAscendClassName)
		assert.are.equal("Fireball",prepared.candidate.skillsTab.socketGroupList[1].gemList[1].nameSpec)
		assert.is_true(prepared.after.CombinedDPS > 0)
		assert.are.equal(nil,prepared.candidate.dbFileName)
	end)

	it("rejects stale revisions before preparing or applying", function()
		local request = proposal({{type="set_character",level=90}})
		local prepared = bridge.prepare(build,request)
		build.characterLevel=40
		assert.are.equal(false,pcall(bridge.prepare,build,request))
		assert.are.equal(false,pcall(bridge.apply,prepared))
		assert.are.equal(build,main.modes.BUILD)
	end)

	it("restores global state and leaves the original intact when an operation fails", function()
		local revision, cache = bridge.revision(build),_G.GlobalCache
		assert.are.equal(false,pcall(bridge.prepare,build,proposal({{type="set_character",level=90},{type="equip_item",slot="Helmet",text="not an item"}})))
		assert.are.equal(revision,bridge.revision(build))
		assert.are.equal(cache,_G.GlobalCache)
		assert.are.equal(build,main.modes.BUILD)
	end)

	it("applies only a prepared candidate, retains an in-memory original and does not save", function()
		local prepared = bridge.prepare(build,proposal({{type="set_character",level=90}}))
		local candidate = bridge.apply(prepared)
		assert.are.equal(candidate,main.modes.BUILD)
		assert.are.equal(original,bridge.previous)
		assert.are.equal(prepared.cache,_G.GlobalCache)
		assert.is_true(candidate.unsaved)
		assert.is_true(candidate.modFlag)
	end)

	it("exports native catalogs and processes a queued proposal without auto-applying", function()
		fakeFiles(); bridge.enable(build)
		local context = json.decode(files.context)
		assert.is_true(#context.catalog.gems > 100)
		assert.is_true(#context.catalog.passives > 1000)
		assert.are.equal(bridge.revision(build),context.context.revision)
		files.request = json.encode({id="test-request",session=bridge.session,proposal=proposal({{type="set_character",level=90}})})
		bridge.poll(build,true)
		local state = json.decode(files.state)
		assert.are.equal("review",state.proposal.status)
		assert.are.equal(90,state.proposal.resolved.level)
		assert.are.equal(original,main.modes.BUILD)
		assert.is_nil(files.request)
		bridge.reject()
		assert.are.equal("rejected",json.decode(files.state).proposal.status)
	end)

	it("keeps stale requests from editing the desktop and disables its connection on close", function()
		fakeFiles(); bridge.enable(build)
		files.request = json.encode({id="old-request",session="another-session",proposal=proposal({{type="set_character",level=90}})})
		bridge.poll(build,true)
		assert.are.equal("failed",json.decode(files.state).proposal.status)
		assert.are.equal(original,main.modes.BUILD)
		bridge.disable(build)
		assert.are.equal(false,json.decode(files.state).enabled)
	end)

	it("uses native connecting paths for passive allocations", function()
		local selected
		for _,node in pairs(build.spec.nodes) do if not node.alloc and node.path and #node.path > 1 and #node.path < 5 and node.type == "Normal" then selected=node; break end end
		assert.is_truthy(selected)
		local prepared = bridge.prepare(build,proposal({{type="allocate_passives",add={selected.id}}}))
		assert.is_true(prepared.candidate.spec.nodes[selected.id].alloc)
		assert.are.equal(false,selected.alloc or false)
	end)

	it("restores the exact original and refuses to discard later manual edits", function()
		fakeFiles(); bridge.enable(build)
		local prepared = bridge.prepare(build,proposal({{type="set_character",level=90}}))
		local candidate = bridge.apply(prepared)
		candidate.characterLevel=91
		assert.are.equal(false,pcall(bridge.restore))
		candidate.characterLevel=90
		assert.are.equal(original,bridge.restore())
		assert.are.equal(original,main.modes.BUILD)
		assert.are.equal(originalCache,_G.GlobalCache)
	end)

	it("keeps review navigation out of build revisions and renders the native review", function()
		local revision = bridge.revision(build)
		build.viewMode="CONFIG"
		assert.are.equal(revision,bridge.revision(build))
		bridge.prepared = bridge.prepare(build,proposal({{type="set_character",level=90}}))
		require("Classes.BuildProposalControl").Open(build)
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main.popups[1].controls.review:Click()
		assert.are.equal("Review AI build proposal",main.popups[1].title)
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main:ClosePopup(); main:ClosePopup()
	end)
	it("ignores derived full DPS row values and ordering while retaining real edit guards",function()
		local output=build.calcsTab.mainOutput;local previous,display=output.SkillDPS,build.displayStats
		local ok,err=pcall(function()
			build.displayStats={{stat="SkillDPS"}};output.SkillDPS={{name="Fireball",count=1,dps=100},{name="Ignite",count=1,dps=200}}
			local before=bridge.revision(build);assert.is_truthy(bridge.serialize(build):find("FullDPSSkill",1,true))
			output.SkillDPS={output.SkillDPS[2],output.SkillDPS[1]};output.SkillDPS[1].dps=300
			assert.equal(before,bridge.revision(build));assert.equal(before,bridge.freeze(build).revision)
			build.notesTab.controls.edit:SetText("A real source edit");assert.is_not.equal(before,bridge.revision(build))
		end)
		output.SkillDPS,build.displayStats=previous,display;assert.is_true(ok,err)
	end)

	it("explains gear, gem requirements and actual connecting passive changes", function()
		local prepared = bridge.prepare(build,proposal({{type="equip_item",slot="Helmet",text="Rarity: RARE\nInsight Hat\nIron Hat\n+100 to maximum Life"},
			{type="set_skills",groups={{gems={{name="Fireball",level=20}}}}}}))
		assert.is_truthy(table.concat(prepared.changes,"\n"):find("Insight Hat",1,true))
		local found = false
		for _,entry in ipairs(prepared.audit.dependencies) do if entry.key == "level" then found=true end end
		assert.is_true(found)
	end)

	it("ranks within budget and exposes missing metrics and old quotes", function()
		local insights = require("Modules.BuildInsights")
		local result = insights.evaluate({CombinedDPS=100},{CombinedDPS=120},{goal="boss_damage",budget=10,currency="chaos"},{amount=15,currency="chaos",quotedAt=os.time()-90000,source="Manual quote"})
		assert.are.near(20,result.score,0.0001)
		assert.are.equal(false,result.eligible)
		assert.is_true(#result.issues >= 2)
		assert.is_true(#result.missingMetrics > 0)
		assert.are.equal(nil,insights.evaluate({},{},{goal="survival"}).score)
	end)

	it("compares alternatives from one base without applying and reviews a historical candidate", function()
		fakeFiles(); bridge.enable(build)
		bridge.configure({goal="survival",budget=10,currency="chaos"})
		local a = proposal({{type="equip_item",slot="Helmet",text="Rarity: RARE\nBudget Hat\nIron Hat\n+50 to maximum Life"}})
		local b = proposal({{type="equip_item",slot="Helmet",text="Rarity: RARE\nRich Hat\nIron Hat\n+100 to maximum Life"}})
		a.quote={amount=5,currency="chaos",quotedAt=os.time(),source="Test quote"}; b.quote={amount=20,currency="chaos",quotedAt=os.time(),source="Test quote"}
		files.request=json.encode({id="comparison",session=bridge.session,kind="compare",baseRevision=bridge.revision(build),candidates={a,b}})
		bridge.poll(build,true)
		assert.are.equal("compared",bridge.status.status)
		assert.are.equal(2,#bridge.status.results)
		assert.is_true(bridge.status.results[2].after.LifeUnreserved > bridge.status.results[1].after.LifeUnreserved)
		assert.are.equal(1,#bridge.status.ranking)
		assert.are.equal(build,main.modes.BUILD)
		local panel=require("Classes.BuildProposalControl")
		panel.Candidates()
		main.popups[1].controls.candidate:SelByValue("comparison-1","val")
		main.popups[1].controls.review:Click()
		assert.are.equal("Review AI build proposal",main.popups[1].title)
		main.popups={}
		assert.are.equal("review",bridge.status.status)
		build.characterLevel=40
		assert.are.equal(false,pcall(bridge.selectHistory,"comparison-2"))
	end)

	it("calculates cumulative leveling milestones and retains requirement warnings", function()
		fakeFiles(); bridge.enable(build)
		bridge.calculateBatch(build,{id="leveling",kind="leveling",baseRevision=bridge.revision(build),stages={
			{title="Early links",level=12,operations={{type="set_skills",groups={{gems={{name="Fireball",level=20}}}}}}},
			{title="Later gear",level=70,operations={{type="equip_item",slot="Helmet",text="Rarity: RARE\nLevel Hat\nIron Hat\n+100 to maximum Life"}}}}})
		assert.are.equal("compared",bridge.status.status)
		assert.are.equal(12,bridge.status.results[1].level)
		assert.are.equal(70,bridge.status.results[2].level)
		assert.are.equal("Fireball",bridge.status.results[2].resolved.skills[1].gems[1].name)
		assert.is_true(#bridge.status.results[1].audit.dependencies > 0)
		assert.are.equal(original,main.modes.BUILD)
	end)

	it("supports multiple undo steps without discarding later manual changes", function()
		fakeFiles(); bridge.enable(build)
		local first=bridge.apply(bridge.prepare(build,proposal({{type="set_character",level=80}})))
		local second=bridge.apply(bridge.prepare(first,{mode="edit",title="Second",baseRevision=bridge.revision(first),operations={{type="set_character",level=90}}}))
		second.characterLevel=91
		assert.are.equal(false,pcall(bridge.restore))
		second.characterLevel=90
		assert.are.equal(first,bridge.restore())
		assert.are.equal(original,bridge.restore())
		assert.are.equal(originalCache,_G.GlobalCache)
	end)

	it("publishes goals, diagnostics and failed request details", function()
		fakeFiles(); bridge.enable(build)
		files.request=json.encode({id="goals",session=bridge.session,kind="plan",plan={goal="comfort",budget=20,currency="chaos",minimums={LifeUnreserved=2000}}})
		bridge.poll(build,true)
		assert.are.equal("comfort",bridge.plan.goal)
		assert.are.equal("configured",bridge.status.status)
		local state=json.decode(files.state)
		assert.is_truthy(state.diagnostics.lastRequest)
		assert.are.equal("comfort",state.plan.goal)
		files.request=json.encode({id="broken",session="wrong",proposal=proposal({{type="set_character",level=90}})})
		bridge.poll(build,true)
		assert.is_truthy(bridge.lastError:find("another desktop session",1,true))
	end)

	it("renders goals, candidates, evidence and diagnostics controls", function()
		local panel=require("Classes.BuildProposalControl")
		panel.Goals(build)
		main.popups[1]:Draw({x=0,y=0,width=1920,height=1080})
		main.popups[1].controls.save:Click(); main.popups={}
		panel.Candidates(); main.popups[1]:Draw({x=0,y=0,width=1920,height=1080}); main.popups={}
		panel.Analysis(build); main.popups[1]:Draw({x=0,y=0,width=1920,height=1080}); main.popups={}
		panel.Diagnostics(); main.popups[1]:Draw({x=0,y=0,width=1920,height=1080}); main.popups={}
	end)

	it("excludes changed assumptions from rankings and bounds session history", function()
		fakeFiles(); bridge.enable(build)
		local prepared=bridge.prepare(build,proposal({{type="set_config",values={enemyIsBoss="None"}}}))
		assert.are.equal(false,prepared.evaluation.eligible)
		assert.is_true(prepared.evaluation.configurationChanged)
		for i=1,10 do prepared.id="bounded-"..i; bridge.remember(prepared) end
		assert.are.equal(8,#bridge.history)
		bridge.close(build)
		assert.are.equal(0,#bridge.history)
		assert.are.equal(0,#bridge.undo)
		assert.are.equal(false,json.decode(files.state).enabled)
	end)

	it("explains a native lethal encounter with captured evidence rather than guaranteed fixes", function()
		local input=build.configTab.input
		input.simulateRecovery=true; input.recoverySimulationTrials=1; input.recoverySimulationWindow=5
		input.enemyDamageType="Melee"; input.enemySpeed=1000; input.enemyIsBoss="None"; input.enemyCritChance=0
		for _,kind in ipairs({"Physical","Lightning","Cold","Fire","Chaos"}) do input["enemy"..kind.."Damage"]=kind == "Cold" and "10000" or "0" end
		build.configTab:BuildModList(); runCallback("OnFrame")
		local diagnosis=require("Modules.BuildInsights").diagnose(build)
		assert.is_truthy(diagnosis.trace.cause)
		assert.is_true(diagnosis.trace.deathDetails.before.Life > 0)
		assert.is_true(diagnosis.trace.deathDetails.after.Life <= 0)
		assert.is_true(#diagnosis.tests > 0)
		assert.is_truthy(table.concat(diagnosis.limitations," "):find("do not establish",1,true))
	end)

	it("captures allocated unnamed passive nodes in imported builds", function()
		local node
		for _,entry in pairs(build.spec.nodes) do if entry.alloc then node=entry; break end end
		assert.is_truthy(node)
		local originalName=node.name
		node.name=nil
		local ok,snapshot=pcall(require("Modules.BuildInsights").snapshot,build)
		node.name=originalName
		assert.is_true(ok)
		assert.is_truthy(snapshot.passives[node.id])
	end)

	it("handles queued crafting inspection without editing the build", function()
		fakeFiles(); bridge.enable(build)
		local revision=bridge.revision(build)
		files.request=json.encode({id="craft-inspect",kind="craftInspect",session=bridge.session,baseRevision=revision,itemText="Rarity: NORMAL\nIron Hat\nItem Level: 86",query="maximum Life",limit=5})
		bridge.poll(build,true)
		assert.are.equal("inspected",bridge.status.status)
		assert.is_true(bridge.status.crafting.total > 0)
		assert.is_true(#bridge.status.crafting.matches <= 5)
		assert.are.equal(revision,bridge.revision(build))
		assert.are.equal(0,#build.savers.CraftingProjects.projects)
	end)
end)
