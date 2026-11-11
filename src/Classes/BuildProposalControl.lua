-- Native review surface for MCP build proposals.
local bridge = require("Modules.DesktopBuildBridge")
local report = require("Modules.EncounterReport")
local insights = require("Modules.BuildInsights")
local Panel = { }

local function wrapRows(lines)
	local rows = { }
	for _,line in ipairs(lines) do
		line = StripEscapes(tostring(line))
		while #line > 100 do
			local cut = line:sub(1,100):match("^.*() ") or 100
			if cut < 50 then cut=100 end
			rows[#rows+1] = {height=18,line:sub(1,cut)}; line=line:sub(cut+1)
		end
		rows[#rows+1] = {height=18,line}
	end
	return rows
end
local function button(x,y,width,label,callback)
	return new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,width,24},label,callback)
end

local function safely(callback)
	local ok,err = pcall(callback)
	if not ok then main:OpenMessagePopup("Build proposal",tostring(err):match("^[^\n]+")) end
end

function Panel.Review()
	local prepared = bridge.prepared
	if not prepared then main:OpenMessagePopup("Build proposal","No calculated proposal is waiting for review."); return end
	local rows = { }
	local function add(line)
		rows[#rows+1] = {height=18,StripEscapes(line)}
	end
	add((prepared.mode == "new" and "New build: " or "Edit current build: ")..prepared.title)
	add("Calculated separately. Applying opens the candidate unsaved; saving remains your choice.")
	add("Undo retains up to five earlier builds in memory. Later manual edits block undo.")
	add("")
	add("Current desktop -> Proposed (native calculations; configuration changes can affect these results)")

	for key,value in pairsSortByKey(prepared.after) do
		add(string.format("%s: %.2f -> %.2f (%+.2f)",insights.labels[key] or key,prepared.before[key] or 0,value,prepared.delta[key] or 0))
	end
	add("")
	add("Native warnings")
	for _,warning in ipairs(prepared.warnings) do add(warning) end
	if #prepared.warnings == 0 then add("No native warnings captured. This is not a guarantee of build viability.") end
	add("")
	add("Changes")
	for _,line in ipairs(prepared.changes) do add(line) end
	add("")
	local evaluation = bridge.evaluate(prepared)
	add("Goal: "..evaluation.goal.." | score: "..(evaluation.score and string.format("%+.2f",evaluation.score) or "unavailable").." | "..(evaluation.eligible and "within constraints" or "outside constraints"))
	add(evaluation.method)
	if evaluation.quote then add(string.format("Quoted total: %.2f %s | source: %s | age: %.0fh",evaluation.quote.amount,evaluation.quote.currency,evaluation.quote.source,evaluation.priceAgeSeconds/3600)) end
	for _,issue in ipairs(evaluation.issues) do add(issue) end
	add("")
	add("New dependency issues")
	for _,entry in ipairs(prepared.audit.introduced or { }) do add(entry.text) end
	add("All dependency checks")
	for _,entry in ipairs(prepared.audit.dependencies) do add(entry.text) end
	add("Assumptions to verify")
	for _,entry in ipairs(prepared.audit.assumptions) do add(entry.text) end
	local lines = { }
	for _,row in ipairs(rows) do lines[#lines+1] = row[1] end
	rows = wrapRows(lines)
	local controls = { }
	local height = math.min(680,main.screenH-60)
	controls.details = new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,24,848,height-92},nil,rows)
	controls.apply = button(16,height-52,160,"Apply proposed build",function() safely(function()
		local candidate = bridge.apply(prepared)
		if bridge.status then bridge.status.status = "applied" end
		bridge.refresh(candidate)
		main.popups = { }
	end) end)
	controls.reject = button(192,height-52,120,"Reject proposal",function() bridge.reject(); main:ClosePopup() end)
	controls.close = button(748,height-52,116,"Back",function() main:ClosePopup() end)
	main:OpenPopup(880,height,"Review AI build proposal",controls,nil,nil,"close")
end

local function textPopup(title,lines)
	local height = math.min(680,main.screenH-60)
	local controls = { }
	controls.details = new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,24,848,height-84},nil,wrapRows(lines))
	controls.close = button(748,height-48,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(880,height,title,controls,nil,nil,"close")
end

function Panel.Goals(build)
	local controls = { }
	controls.info = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Rank candidates by goal. Prices use supplied quotes, with no automatic trade lookup.")
	controls.goal = new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,58,260,24},insights.goals)
	controls.goal:SelByValue(bridge.plan.goal)
	for _,label in ipairs({{16,88,"Budget (optional)"},{172,88,"Currency"},{16,136,"Minimum Life"},{172,136,"Minimum DPS"}}) do
		controls["label"..label[1]..label[2]] = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{label[1],label[2],0,14},label[3])
	end
	controls.budget = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{16,106,140,24},bridge.plan.budget and tostring(bridge.plan.budget) or "","Budget (optional)","0-9%.",16)
	controls.currency = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{172,106,140,24},bridge.plan.currency or "chaos","Currency",nil,24)
	controls.minimumLife = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{16,154,140,24},bridge.plan.minimums and bridge.plan.minimums.LifeUnreserved or "","Minimum Life","0-9%.",12)
	controls.minimumDPS = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{172,154,140,24},bridge.plan.minimums and bridge.plan.minimums.CombinedDPS or "","Minimum DPS","0-9%.",16)
	controls.note = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,204,0,14},"AI can set other minimum stats through set_build_goals. Reviews show unmet constraints.")
	controls.save = button(16,246,140,"Set goals",function() safely(function()
		local budget = controls.budget.buf ~= "" and assert(tonumber(controls.budget.buf),"Invalid budget") or nil
		local minimums = copyTable(bridge.plan.minimums or { })
		minimums.LifeUnreserved = controls.minimumLife.buf ~= "" and assert(tonumber(controls.minimumLife.buf),"Invalid minimum Life") or nil
		minimums.CombinedDPS = controls.minimumDPS.buf ~= "" and assert(tonumber(controls.minimumDPS.buf),"Invalid minimum DPS") or nil
		bridge.configure({goal=controls.goal:GetSelValue(),budget=budget,currency=controls.currency.buf,minimums=minimums,notes=bridge.plan.notes})
		if bridge.enabled then bridge.refresh(build) end
		main:ClosePopup()
	end) end)
	controls.close = button(538,246,116,"Cancel",function() main:ClosePopup() end)
	main:OpenPopup(670,292,"Build goals and budget",controls,nil,nil,"close")
end

function Panel.Analysis(build)
	local lines = {"Current build: "..build.buildName,"Dependency checks"}
	local audit = insights.audit(build)
	for _,entry in ipairs(audit.dependencies) do lines[#lines+1] = entry.text end
	if #audit.dependencies == 0 then lines[#lines+1] = "No issues detected by these checks. Check interactions and playability separately." end
	lines[#lines+1] = ""; lines[#lines+1] = "Assumptions to verify"
	for _,entry in ipairs(audit.assumptions) do lines[#lines+1] = entry.text end
	local diagnosis = insights.diagnose(build)
	lines[#lines+1] = ""; lines[#lines+1] = "Encounter evidence"
	for _,line in ipairs(diagnosis.observations) do lines[#lines+1] = line end
	for _,line in ipairs(diagnosis.tests) do lines[#lines+1] = "Test: "..line end
	for _,line in ipairs(diagnosis.limitations) do lines[#lines+1] = line end
	textPopup("Build checks and death analysis",lines)
end

function Panel.Candidates()
	local height = math.min(680,main.screenH-60)
	local controls,list = {},{}
	for _,entry in ipairs(bridge.history) do list[#list+1] = {label=entry.title,val=entry.id} end
	controls.candidate = new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,640,24},list)
	controls.review = button(672,28,192,"Review selected",function() safely(function() bridge.selectHistory(controls.candidate:GetSelValueByKey("val")); Panel.Review() end) end)
	controls.review.enabled = #list > 0
	local lines = {"Up to eight candidates and five applied versions remain in memory for this session.","A candidate requires its original desktop base to be current and unchanged.",""}
	local status = bridge.comparison or bridge.status
	if status and status.results then
		lines[#lines+1] = status.kind == "leveling" and "Leveling milestones (changes accumulate from the current base)" or "Candidate comparison (each uses the same base)"
		local results = status.results
		for _,entry in ipairs(results) do
			lines[#lines+1] = entry.title.." | "..entry.status..(entry.level and " | level "..entry.level or "")
			if entry.error then lines[#lines+1] = entry.error end
			if entry.evaluation then
				local e = entry.evaluation
				lines[#lines+1] = "  "..e.goal.." score "..(e.score and string.format("%+.2f",e.score) or "unavailable").." | dependencies: "..e.dependencyCount.." | "..(e.eligible and "within constraints" or "outside constraints")
				if e.quote then lines[#lines+1] = string.format("  Cost %.2f %s | %s | quoted %.0fh ago",e.quote.amount,e.quote.currency,e.quote.source,e.priceAgeSeconds/3600) end
				for _,issue in ipairs(e.issues) do lines[#lines+1] = "  "..issue end
			end
		end
		lines[#lines+1] = ""; lines[#lines+1] = "Side-by-side stats (candidate order above)"
		for _,key in ipairs({"CombinedDPS","TotalEHP","LifeUnreserved","EnergyShield","ManaUnreserved","PhysicalMaximumHitTaken","ChaosMaximumHitTaken","RecoverySimulationSurvivalChance","RecoverySimulationAttackUptime"}) do
			local values = { }
			for _,entry in ipairs(results) do values[#values+1] = entry.after and entry.after[key] and string.format("%.2f",entry.after[key]) or "n/a" end
			lines[#lines+1] = (insights.labels[key] or key)..": "..table.concat(values," | ")
		end
		lines[#lines+1] = ""; lines[#lines+1] = "Goal ranking at calculation time (eligible candidates)"
		for i,entry in ipairs(status.ranking or { }) do lines[#lines+1] = string.format("%d. %s: %+.2f%s",i,entry.title,entry.score,entry.scorePerCurrency and string.format(" | %+.3f points/currency",entry.scorePerCurrency) or "") end
	else
		for _,entry in ipairs(bridge.history) do lines[#lines+1] = entry.title.." | base "..entry.baseRevision:sub(1,8) end
		if #list == 0 then lines[#lines+1] = "Ask your connected AI to compare upgrades or make a leveling plan. Calculated candidates appear here." end
	end
	controls.details = new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,68,848,height-132},nil,wrapRows(lines))
	controls.close = button(748,height-48,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(880,height,"Build candidates and leveling",controls,nil,nil,"close")
end

function Panel.Diagnostics()
	local now = os.time()
	textPopup("AI connection diagnostics",{bridge.enabled and "Desktop bridge enabled" or "Desktop bridge disabled",
		"A ready desktop bridge does not prove an AI client is connected.",
		"Session: "..tostring(bridge.session or "none"),"Build revision: "..tostring(bridge.contextRevision or "none"),
		"Last context refresh: "..(bridge.lastContext and (now-bridge.lastContext).." seconds ago" or "never"),
		"Last poll: "..(bridge.lastPoll and (now-bridge.lastPoll).." seconds ago" or "never"),
		"Last request: "..(bridge.lastRequest and (now-bridge.lastRequest).." seconds ago" or "never"),
		"Last error: "..tostring(bridge.lastError or "none"),"Proposal: "..tostring(bridge.status and bridge.status.status or "none"),"Undo depth: "..#bridge.undo,"",
		"1. Open a build and wait for calculations to finish.","2. Enable build proposals in AI builds.","3. Copy the MCP configuration into a local stdio MCP client, then reconnect it.","4. Ask the client to call get_build_connection and get_build_context.","5. Review a pending proposal before submitting another request.","Disable the connection when finished. Candidates and undo are session-only; save builds explicitly."})
end

function Panel.Open(build)
	local controls = { }
	controls.status = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,30,0,16},function()
		return (bridge.enabled and "Desktop bridge ready" or "Desktop bridge disabled").." | "..(bridge.status and bridge.status.status or "No proposal").." | Goal: "..bridge.plan.goal
	end)
	controls.info = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,64,0,14},"Plan with AI, compare native results, then review and apply an unsaved candidate.")
	controls.enable = button(16,100,210,function() return bridge.enabled and "Disable connection" or "Enable build proposals" end,function() safely(function()
		if bridge.enabled then bridge.disable(bridge.build) else bridge.enable(build) end
	end) end)
	controls.enable.enabled = function() return not build.buildFlag end
	controls.setup = button(242,100,210,"Copy MCP configuration",function() Copy(report.mcpConfig(GetScriptPath().."/AI/McpServer.cjs",main.userPath.."AI-encounter.json")) end)
	controls.goals = button(468,100,210,"Goals and budget",function() Panel.Goals(build) end)
	controls.review = button(16,142,210,"Review pending proposal",Panel.Review)
	controls.review.enabled = function() return bridge.prepared ~= nil end
	controls.candidates = button(242,142,210,"Candidates and leveling",Panel.Candidates)
	controls.restore = button(468,142,210,"Undo applied candidate",function() safely(function() bridge.restore(); main.popups={} end) end)
	controls.restore.enabled = function() return bridge.previous ~= nil and bridge.build == main.modes.BUILD end
	controls.analysis = button(16,184,210,"Checks and death analysis",function() Panel.Analysis(build) end)
	controls.diagnostics = button(242,184,210,"Connection diagnostics",Panel.Diagnostics)
	controls.detail = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,234,0,14},function()
		local text = bridge.lastError or bridge.status and bridge.status.title or "Enable the bridge, connect your MCP client, then ask it to plan or compare builds."
		return #text > 100 and text:sub(1,97).."..." or text
	end)
	controls.close = button(562,276,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(698,320,"AI build planner",controls,nil,nil,"close")
end

return Panel
