-- Native review surface for MCP build proposals.
local bridge = require("Modules.DesktopBuildBridge")
local report = require("Modules.EncounterReport")
local json = require("dkjson")
local Panel = { }

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
	add("The original remains in memory. Save any later edits before switching builds.")
	add("")
	add("Current desktop -> Proposed (native calculations; configuration changes can affect these results)")
	local labels = {LifeUnreserved="Unreserved Life",EnergyShield="Energy Shield",ManaUnreserved="Unreserved Mana",CombinedDPS="Combined DPS",FullDPS="Full DPS",TotalEHP="EHP",PhysicalMaximumHitTaken="Physical maximum hit",ChaosMaximumHitTaken="Chaos maximum hit",RecoverySimulationSurvivalChance="Encounter survival (%)",RecoverySimulationDamageDPS="Encounter damage DPS"}
	for key,value in pairsSortByKey(prepared.after) do
		add(string.format("%s: %.2f -> %.2f (%+.2f)",labels[key] or key,prepared.before[key] or 0,value,prepared.delta[key] or 0))
	end
	add("")
	add("Native warnings")
	for _,warning in ipairs(prepared.warnings) do add(warning) end
	if #prepared.warnings == 0 then add("No native warnings captured. This is not a guarantee of build viability.") end
	add("")
	add("Requested changes (passive allocation also adds connecting paths and removes dependent nodes)")
	for line in json.encode(prepared.operations,{indent=true}):gmatch("[^\n]+") do
		while #line > 100 do add(line:sub(1,100)); line=line:sub(101) end
		add(line)
	end
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

function Panel.Open(build)
	local controls = { }
	controls.status = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,32,0,16},function()
		local status = bridge.status
		return (bridge.enabled and "Desktop connection enabled" or "Desktop connection disabled")..(status and " | Proposal: "..status.status or "")
	end)
	controls.info = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,66,0,14},"AI can read this unsaved build and queue proposals. Only desktop review applies changes.")
	controls.enable = button(16,104,190,function() return bridge.enabled and "Disable connection" or "Enable build proposals" end,function() safely(function()
		if bridge.enabled then bridge.disable(bridge.build) else bridge.enable(build) end
	end) end)
	controls.enable.enabled = function() return not build.buildFlag end
	controls.setup = button(222,104,210,"Copy MCP configuration",function()
		Copy(report.mcpConfig(GetScriptPath().."/AI/McpServer.cjs",main.userPath.."AI-encounter.json"))
	end)
	controls.review = button(16,146,190,"Review calculated proposal",Panel.Review)
	controls.review.enabled = function() return bridge.prepared ~= nil end
	controls.restore = button(222,146,210,"Restore previous build",function() safely(function() bridge.restore(); main.popups={} end) end)
	controls.restore.enabled = function() return bridge.previous ~= nil and bridge.build == main.modes.BUILD end
	controls.detail = new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,198,0,14},function()
		return bridge.status and (bridge.status.error or bridge.status.title or "") or "Enable the connection, add its MCP configuration to your AI client, then request a proposal."
	end)
	controls.close = button(558,250,130,"Close",function() main:ClosePopup() end)
	main:OpenPopup(712,294,"AI build proposals",controls,nil,nil,"close")
end

return Panel
