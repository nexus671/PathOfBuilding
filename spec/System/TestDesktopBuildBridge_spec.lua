describe("Desktop build proposals", function()
	local bridge = require("Modules.DesktopBuildBridge")
	local json = require("dkjson")
	-- Busted isolates spec globals; the bridge swaps the real process cache.
	local original, originalCache, files, open, remove
	before_each(function() newBuild(); original=build; originalCache=_G.GlobalCache end)
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
end)
