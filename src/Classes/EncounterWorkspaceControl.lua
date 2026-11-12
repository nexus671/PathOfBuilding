-- Encounter overview, selected-trial explanation and chart in one workspace.
local report = require("Modules.EncounterReport")
local Workspace = newClass("EncounterWorkspaceControl", "Control")

function Workspace:EncounterWorkspaceControl(anchor, rect, tab)
	self:Control(anchor, rect)
	self.tab = tab
	return self
end

function Workspace:Draw()
	local x,y = self:GetPos()
	local width,height = self:GetSize()
	if self.env ~= self.tab.calcsEnv then
		self.env = self.tab.calcsEnv
		self.report = report.capture(self.tab.build)
	end
	local current = self.report
	local summary = current.summary
	SetDrawColor(1,1,1)
	local function text(offset, value, size)
		DrawString(x,y+offset,"LEFT",size or 14,"VAR",value)
	end
	if summary.SurvivalChance then
		text(0,string.format("Survival: %.1f%%   |   95%% interval: %.1f-%.1f%%   |   %d trials   |   %.1fs window",
			summary.SurvivalChance,summary.ConfidenceLow,summary.ConfidenceHigh,summary.Trials,summary.Window),16)
		text(24,string.format("Attack uptime: %.1f%%   |   Damage / window: %.0f DPS   |   Configuration warnings: %d",
			summary.AttackUptime or 0,summary.DamageDPS or 0,summary.Warnings or 0))
	else text(0,"Run a supported encounter to see survival and resource history.",16) end
	if current.comparison.Ready then
		text(46,string.format("Comparison B - A: survival %+.1f points | time %+.2fs | damage %+.0f DPS",
			current.comparison.SurvivalDelta,current.comparison.TimeDelta,current.comparison.DamageDelta))
	end
	local deathLines=report.deathLines(current)
	for index,line in ipairs(deathLines) do
		-- Fit long hit descriptions to the workspace instead of drawing over its border.
		while DrawStringWidth(14,"VAR",line) > width and #line > 4 do line = line:sub(1,-5).."..." end
		text(78+(index-1)*18,line)
	end
	local chartY=math.max(112,78+#deathLines*18+16)
	local chartHeight=math.min(340,height-chartY-28)
	if current.trace and current.trace.caps and chartHeight>=210 then
		self.tab.controls.breakdown:DrawEncounterTimeline(x,y+chartY,{timeline=current.trace,width=width,height=chartHeight,options=self.options})
	else text(184,"Open the event log to inspect the full chart and exact resource changes.") end
	text(height-18,"One trial is shown. The survival estimate and confidence interval describe the configured encounter only.",12)
end

function Workspace.Open(tab)
	local build, config = tab.build,tab.build.configTab
	local width = math.min(1000, main.screenW-40)
	local height = math.min(740, main.screenH-60)
	local controls = { }
	local function label(id,x,y,value)
		controls[id] = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},value)
	end
	local function button(id,x,y,w,value,callback)
		controls[id] = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,22},value,callback)
	end
	label("windowLabel",16,28,"Window (s)")
	controls.window = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{100,24,70,22},tostring(config.input.recoverySimulationWindow or 60),nil,"%D",4)
	label("trialsLabel",190,28,"Trials")
	controls.trials = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{234,24,62,22},tostring(config.input.recoverySimulationTrials or 32),nil,"%D",4)
	label("trialLabel",312,28,"Chart trial")
	controls.trial = new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{388,24,62,22},tostring(config.input.recoverySimulationTraceTrial or 1),nil,"%D",4)
	button("run",466,24,125,"Run encounter",function()
		config.input.simulateRecovery = true
		config.input.recoverySimulationWindow = math.min(300,math.max(1,tonumber(controls.window.buf) or 60))
		config.input.recoverySimulationTrials = math.min(128,math.max(1,tonumber(controls.trials.buf) or 32))
		config.input.recoverySimulationTraceTrial = math.min(config.input.recoverySimulationTrials,math.max(1,tonumber(controls.trial.buf) or 1))
		config.input.recoverySimulationCompareSet = controls.compare.list[controls.compare.selIndex].val
		controls.window:SetText(tostring(config.input.recoverySimulationWindow))
		controls.trials:SetText(tostring(config.input.recoverySimulationTrials))
		controls.trial:SetText(tostring(config.input.recoverySimulationTraceTrial))
		config:BuildModList(); config:UpdateControls(); config:AddUndoState()
		build.buildFlag = true
	end)
	label("compareLabel",610,28,"Compare")
	config:UpdateEncounterComparisonList()
	controls.compare = new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{678,24,width-694,22},config.varControls.recoverySimulationCompareSet.list)
	controls.compare:SelByValue(config.input.recoverySimulationCompareSet or 0,"val")
	label("scenario",16,62,function()
		return string.format("Incoming: %s   |   Enemy interval: %.0fms   |   Attacking: %s   |   Timed effects: %s",
			config.input.enemyDamageType or "Average",(tab.calcsOutput.enemySkillTime or 0)*1000,config.input.recoverySimulationAttacking and "yes" or "no",config.input.recoverySimulationTimedEffects == false and "no" or "yes")
	end)
	button("settings",16,88,145,"Encounter settings",function() main:ClosePopup(); config:ShowEncounterSimulation() end)
	button("events",173,88,120,"Full event log",function()
		main:ClosePopup(); tab:ShowRecoverySimulation()
		tab:SetDisplayStat({{breakdown="RecoverySimulationTimeline"},x=100,y=100,width=0},true)
	end)
	button("ai",305,88,120,"AI tools / MCP",function() Workspace.OpenAI(tab) end)
	button("checks",437,88,125,"Review warnings",function()
		main:ClosePopup(); tab:ShowRecoverySimulation()
		tab:SetDisplayStat({{breakdown="RecoverySimulationWarnings"},x=100,y=100,width=0},true)
	end)
	controls.preset=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{574,88,math.max(60,width-822),24},(function() local list={};for i,preset in ipairs(require("Modules.CalcEncounter").presets) do list[#list+1]={label=preset.name,val=i} end;return list end)())
	button("usePreset",width-236,88,112,"New scenario",function()
		local encounters=require("Modules.CalcEncounter");local index=controls.preset:GetSelValueByKey("val");local preset=encounters.presets[index]
		local c={};local w,h=math.min(820,main.screenW-40),math.min(450,main.screenH-48);local ui=require("Modules.PlanningUI")
		ui.label(c,"name",16,28,preset.name,22);c.details=new("TextListControl"):TextListControl(ui.anchor,{16,72,w-32,h-146},nil,ui.rows(encounters.presetLines(preset),w-56))
		c.create=new("ButtonControl"):ButtonControl(ui.anchor,{16,h-48,220,28},"Create separate scenario",function()
			config:CreateEncounterConfigSet(index);config:UpdateEncounterComparisonList()
			controls.compare:SetList(config.varControls.recoverySimulationCompareSet.list);controls.compare:SelByValue(0,"val");controls.window:SetText(tostring(config.input.recoverySimulationWindow or 60));build.buildFlag=true;main:ClosePopup()
		end)
		c.close=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-48,140,28},"Cancel",function() main:ClosePopup() end)
		ui.style(c,{create=true});main:OpenPopup(w,h,"Scenario assumptions",c,nil,nil,"close")
	end)
	button("close",width-112,88,96,"Close",function() main:ClosePopup() end)
	controls.overview = new("EncounterWorkspaceControl"):EncounterWorkspaceControl({"TOPLEFT",nil,"TOPLEFT"},{16,168,width-32,height-184},tab)
	local options={hidden={},hideEmpty=true,raw=false};controls.overview.options=options
	for index,entry in ipairs({{"Life","Life",16,68},{"EnergyShield","ES",92,68},{"Mana","Mana",168,68},{"crab","Crab",244,68},{"shrouds","Shrouds",320,88},{"chargesTotal","Charges",416,88},{"poison","Poison",512,88}}) do
		local key,label,x,w=unpack(entry);button("series_"..key,x,124,w,function() return (options.hidden[key] and "[ ] " or "[x] ")..label end,function() options.hidden[key]=not options.hidden[key] end)
	end
	button("chartUnits",608,124,128,function() return options.raw and "Actual values" or "Normalized %" end,function() options.raw=not options.raw end)
	button("emptyLanes",744,124,160,function() return options.hideEmpty and "Hide empty: on" or "Hide empty: off" end,function() options.hideEmpty=not options.hideEmpty end)
	require("Modules.PlanningUI").style(controls,{run=true})
	main:OpenPopup(width,height,"Encounter simulation",controls,nil,nil,"close")
end

function Workspace.OpenAI(tab)
	local controls = { }
	local status = "Refresh context after changing the build. AI clients read the last captured desktop report."
	local path = main.userPath.."AI-encounter.json"
	local tasks = {
		{"Explain this death", "Explain the selected trial's terminal event and preceding resource history. Identify which facts are observed and which causes require testing."},
		{"Check assumptions", "Review the configured encounter, coverage warnings and model limitations. Prioritize assumptions that could change the survival conclusion."},
		{"Plan upgrade tests", "Propose three small paired configuration or build experiments based on the captured outcome. State what each would test; do not invent calculated upgrade benefits."},
	}
	for index,task in ipairs(tasks) do
		controls["brief"..index] = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{16+(index-1)*224,40,212,24},"Copy: "..task[1],function()
			Copy(report.brief(report.capture(tab.build),task[2]))
			status = "Brief copied. Paste it into your AI chat, or use MCP for the refreshed report."
		end)
	end
	controls.refresh = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{16,88,212,24},"Refresh MCP context",function()
		local captured = report.capture(tab.build)
		local ok,err = report.write(captured,path)
		status = ok and "Context captured at "..captured.capturedAt or "Could not write context: "..tostring(err)
	end)
	controls.setup = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{240,88,212,24},"Copy MCP configuration",function()
		Copy(report.mcpConfig(GetScriptPath().."/AI/McpServer.cjs",path))
		status = "MCP configuration copied. Requires Node.js and a client that supports local stdio servers."
	end)
	controls.status = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,134,0,14},function() return status end)
	controls.info = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,166,0,14},"Encounter reports are snapshots. Build proposals connect separately and need desktop review.")
	controls.builds = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{16,208,212,24},"Build proposals",function() require("Classes.BuildProposalControl").Open(tab.build) end)
	controls.close = new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{576,208,100,24},"Back",function() main:ClosePopup() end)
	main:OpenPopup(704,252,"AI tools",controls,nil,nil,"close")
end

return Workspace
