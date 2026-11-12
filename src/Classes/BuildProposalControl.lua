-- Native review surface for MCP build proposals.
local bridge = require("Modules.DesktopBuildBridge")
local report = require("Modules.EncounterReport")
local insights = require("Modules.BuildInsights")
local Panel = { }

local ui=require("Modules.PlanningUI")
local function goalName(goal) return goal:gsub("_"," "):gsub("^%l",string.upper) end
local function wrapRows(lines,width) return ui.rows(lines,width or 818) end
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
	local evaluation=bridge.evaluate(prepared)
	local controls = { }
	local height = math.min(680,main.screenH-60)
	local cardWidth=272
	local function metric(key) local value=prepared.after[key] or 0;return string.format(value<100 and "%.2f" or "%.0f",value) end
	local function previous(key) local value=prepared.before[key] or 0;return string.format("Current %s (%+.2f)",string.format(value<100 and "%.2f" or "%.0f",value),prepared.delta[key] or 0) end
	ui.card(controls,"damageCard",16,24,cardWidth,"DAMAGE PER SECOND",metric("CombinedDPS"),previous("CombinedDPS"))
	ui.card(controls,"defenceCard",304,24,cardWidth,"EFFECTIVE HIT POOL",metric("TotalEHP"),previous("TotalEHP"))
	ui.card(controls,"lifeCard",592,24,cardWidth,"UNRESERVED LIFE",metric("LifeUnreserved"),previous("LifeUnreserved"))
	controls.page=new("DropDownControl"):DropDownControl(ui.anchor,{16,136,260,26},{"Summary","Changes","Checks"})
	ui.label(controls,"candidateTitle",464,142,prepared.title:sub(1,42),14)
	ui.label(controls,"goal",16,170,"Goal: "..goalName(evaluation.goal).." | "..(evaluation.eligible and "Within constraints" or "Constraints need attention"),14)
	local metricRows={{height=26,textSize=16,"^7Metric","^7Current","^7Proposed","^7Change"}}
	for key in pairsSortByKey(prepared.after) do
		if prepared.after[key] then metricRows[#metricRows+1]={height=24,textSize=16,"^7"..(insights.labels[key] or key),"^7"..string.format("%.2f",prepared.before[key] or 0),"^7"..string.format("%.2f",prepared.after[key]),"^7"..string.format("%+.2f",prepared.delta[key] or 0)} end
	end
	if evaluation.quote then metricRows[#metricRows+1]={height=24,textSize=16,"^7Quoted cost","","^7"..string.format("%.2f %s",evaluation.quote.amount,evaluation.quote.currency),""} end
	if evaluation.configurationChanged then metricRows[#metricRows+1]={height=24,textSize=16,"^7Configuration changed","","^7Yes",""} end
	controls.metrics=new("TextListControl"):TextListControl(ui.anchor,{16,198,848,height-292},{{x=8,align="LEFT"},{x=330,align="LEFT"},{x=490,align="LEFT"},{x=650,align="LEFT"}},metricRows)
	controls.metrics.shown=function() return controls.page:GetSelValue()=="Summary" end
	controls.details = new("TextListControl"):TextListControl(ui.anchor,{16,198,848,height-292},nil,{})
	controls.details.shown=function() return controls.page:GetSelValue()~="Summary" end
	controls.page.selFunc=function()
		if controls.page:GetSelValue()=="Changes" then controls.details.list=wrapRows(prepared.changes)
		else
			local checks={"Native warnings"}
			for _,warning in ipairs(prepared.warnings) do checks[#checks+1]=warning end
			if #prepared.warnings==0 then checks[#checks+1]="No native warnings captured." end
			checks[#checks+1]="";checks[#checks+1]="Goal constraints"
			for _,issue in ipairs(evaluation.issues) do checks[#checks+1]=issue end
			checks[#checks+1]="";checks[#checks+1]="Evaluation"
			checks[#checks+1]=evaluation.method
			if evaluation.quote then checks[#checks+1]=string.format("Quote: %.2f %s | %s | %.0f hours old",evaluation.quote.amount,evaluation.quote.currency,evaluation.quote.source,evaluation.priceAgeSeconds/3600) end
			checks[#checks+1]="";checks[#checks+1]="New dependency issues"
			for _,entry in ipairs(prepared.audit.introduced or {}) do checks[#checks+1]=entry.text end
			checks[#checks+1]="";checks[#checks+1]="Dependencies"
			for _,entry in ipairs(prepared.audit.dependencies) do checks[#checks+1]=entry.text end
			checks[#checks+1]="";checks[#checks+1]="Assumptions to verify"
			for _,entry in ipairs(prepared.audit.assumptions) do checks[#checks+1]=entry.text end
			controls.details.list=wrapRows(checks)
		end
	end
	ui.label(controls,"reviewNote",16,height-80,"Applying opens the candidate unsaved. Save the build when you want to keep it.",14)
	controls.apply = button(16,height-52,160,"Apply build",function() safely(function()
		local candidate = bridge.apply(prepared)
		if bridge.status then bridge.status.status = "applied" end
		bridge.refresh(candidate)
		main.popups = { }
	end) end)
	controls.reject = button(192,height-52,120,"Reject",function() bridge.reject(); main:ClosePopup() end)
	controls.close = button(748,height-52,116,"Back",function() main:ClosePopup() end)
	ui.style(controls,{apply=true});ui.tabs(controls,controls.page,{{"tab_summary","Summary","Summary"},{"tab_changes","Changes","Changes"},{"tab_checks","Checks","Checks"}},16,136,420)
	main:OpenPopup(880,height,"Review AI build proposal",controls,nil,nil,"close")
end

local function textPopup(title,lines)
	local height = math.min(680,main.screenH-60)
	local controls = { }
	controls.details = new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,24,848,height-84},nil,wrapRows(lines))
	controls.close = button(748,height-48,116,"Close",function() main:ClosePopup() end)
	ui.style(controls);main:OpenPopup(880,height,title,controls,nil,nil,"close")
end

function Panel.Goals(build)
	local controls = { }
	controls.info = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"^7Set a goal and optional limits for candidate comparisons.")
	controls.goal = new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,58,260,24},(function() local goals={};for _,goal in ipairs(insights.goals) do goals[#goals+1]={label=goalName(goal),val=goal} end;return goals end)())
	controls.goal:SelByValue(bridge.plan.goal,"val")
	for _,label in ipairs({{16,88,"Budget (optional)"},{172,88,"Currency"},{16,136,"Minimum Life"},{172,136,"Minimum DPS"}}) do
		controls["label"..label[1]..label[2]] = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{label[1],label[2],0,14},"^7"..label[3])
	end
	controls.budget = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{16,106,140,24},bridge.plan.budget and tostring(bridge.plan.budget) or "","","^0-9%.",16)
	controls.currency = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{172,106,140,24},bridge.plan.currency or "chaos","",nil,24)
	controls.minimumLife = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{16,154,140,24},bridge.plan.minimums and bridge.plan.minimums.LifeUnreserved or "","","^0-9%.",12)
	controls.minimumDPS = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{172,154,140,24},bridge.plan.minimums and bridge.plan.minimums.CombinedDPS or "","","^0-9%.",16)
	controls.note = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,204,0,14},"^7Reviews show constraints the candidate does not meet.")
	controls.save = button(16,246,140,"Set goals",function() safely(function()
		local budget = controls.budget.buf ~= "" and assert(tonumber(controls.budget.buf),"Invalid budget") or nil
		local minimums = copyTable(bridge.plan.minimums or { })
		minimums.LifeUnreserved = controls.minimumLife.buf ~= "" and assert(tonumber(controls.minimumLife.buf),"Invalid minimum Life") or nil
		minimums.CombinedDPS = controls.minimumDPS.buf ~= "" and assert(tonumber(controls.minimumDPS.buf),"Invalid minimum DPS") or nil
		bridge.configure({goal=controls.goal:GetSelValueByKey("val"),budget=budget,currency=controls.currency.buf,minimums=minimums,notes=bridge.plan.notes})
		if bridge.enabled then bridge.refresh(build) end
		main:ClosePopup()
	end) end)
	controls.close = button(538,246,116,"Cancel",function() main:ClosePopup() end)
	ui.style(controls,{save=true});main:OpenPopup(670,292,"Build goals and budget",controls,nil,nil,"close")
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
	ui.style(controls,{review=true});main:OpenPopup(880,height,"Build candidates and leveling",controls,nil,nil,"close")
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

function Panel.Open(build,layout)
	local controls={}
	local width=layout and layout.width or math.min(960,main.screenW-40)
	local height=layout and layout.height or math.min(720,main.screenH-60)
	ui.label(controls,"heading",16,20,"Plan this build",24)
	ui.label(controls,"info",16,56,"Set goals, compare calculated options, then review what changes.",14)
	local cardWidth=math.floor((width-64)/3)
	ui.card(controls,"goalCard",16,88,cardWidth,"BUILD GOAL",function() return goalName(bridge.plan.goal) end,"Set goals and a budget below")
	ui.card(controls,"connectionCard",32+cardWidth,88,cardWidth,"LOCAL BRIDGE",function() return bridge.enabled and "Enabled" or "Disabled" end,"Manage in Connection")
	ui.card(controls,"proposalCard",48+cardWidth*2,88,cardWidth,"PROPOSAL",function() return bridge.prepared and "Ready for review" or "None pending" end,"You choose what to apply")
	controls.page=new("DropDownControl"):DropDownControl(ui.anchor,{16,202,240,26},{"Plan & review","Connection"})
	local buttonWidth=math.min(240,math.floor((width-48)/2))
	local function action(key,y,title,description,callback)
		controls[key]=button(16,y,buttonWidth,title,callback)
		ui.label(controls,key.."Hint",32+buttonWidth,y+4,description,14)
	end
	action("goals",250,"Goals and budget","Define your priorities and constraints.",function() Panel.Goals(build) end)
	action("review",302,"Review proposal","Compare current and proposed results.",Panel.Review)
	controls.review.enabled=function() return bridge.prepared~=nil end
	action("candidates",354,"Candidates and leveling","Compare upgrades and progression.",Panel.Candidates)
	action("analysis",406,"Build checks","Inspect requirements and encounter evidence.",function() Panel.Analysis(build) end)
	action("restore",458,"Undo applied build","Restore the previous reviewed version.",function() safely(function() bridge.restore();main.popups={} end) end)
	controls.restore.enabled=function() return bridge.previous~=nil and bridge.build==main.modes.BUILD end
	action("enable",250,function() return bridge.enabled and "Disable connection" or "Enable proposals" end,"Allow your local AI client to propose builds.",function() safely(function()
		if bridge.enabled then bridge.disable(bridge.build) else bridge.enable(build) end
	end) end)
	controls.enable.enabled=function() return not build.buildFlag end
	action("setup",302,"Copy MCP configuration","Connect a local MCP client to this build.",function() Copy(report.mcpConfig(GetScriptPath().."/AI/McpServer.cjs",main.userPath.."AI-encounter.json")) end)
	action("diagnostics",354,"Connection details","Check requests, errors and connection setup.",Panel.Diagnostics)
	controls.status=ui.label(controls,"status",16,height-86,"",14)
	controls.status.label=function() return "^7"..(bridge.lastError and "Connection needs attention. Open Connection details." or bridge.prepared and "A calculated proposal is ready for your review." or "Your current build stays in place until you apply a proposal.") end
	for _,key in ipairs({"goals","review","candidates","analysis","restore"}) do
		controls[key].shown=function() return controls.page:GetSelValue()=="Plan & review" end
		controls[key.."Hint"].shown=controls[key].shown
	end
	for _,key in ipairs({"enable","setup","diagnostics"}) do
		controls[key].shown=function() return controls.page:GetSelValue()=="Connection" end
		controls[key.."Hint"].shown=controls[key].shown
	end
	controls.close=button(width-132,height-48,116,"Close",function() main:ClosePopup() end)
	ui.style(controls,{review=true})
	ui.tabs(controls,controls.page,{{"tab_plan","Plan & review","Plan & review"},{"tab_connection","Connection","Connection"}},16,202,360)
	if layout then controls.close.shown=false;layout.mount(width,height,"AI build planner",controls)
	else main:OpenPopup(width,height,"AI build planner",controls,nil,nil,"close") end
	return controls
end

return Panel
