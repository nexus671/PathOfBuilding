-- Desktop build proposals are calculated separately and applied only in the UI.
local json = require("dkjson")
local sha1 = require("sha1")
local M = { enabled=false }
local metrics = { "LifeUnreserved", "EnergyShield", "ManaUnreserved", "CombinedDPS", "FullDPS", "TotalEHP", "PhysicalMaximumHitTaken", "ChaosMaximumHitTaken", "RecoverySimulationSurvivalChance", "RecoverySimulationDamageDPS" }

local function serialize(build)
	-- The native Notes saver temporarily hides color codes. Preserve the editor.
	local notes = build.notesTab
	local edit = notes.controls.edit
	local buf, colors, caret, selection = edit.buf,notes.showColorCodes,edit.caret,edit.sel
	local ok, result = pcall(build.SaveDB,build,"AI build context")
	edit.buf, notes.showColorCodes, edit.caret, edit.sel = buf,colors,caret,selection
	notes.controls.toggleColorCodes.label = colors and "Hide Color Codes" or "Show Color Codes"
	assert(ok and result,ok and "Could not serialize build" or result)
	return result
end

function M.revision(build)
	local xml = assert(common.xml.ParseXML(serialize(build)))
	local root = xml[1]
	for index=#root,1,-1 do
		local node = root[index]
		if type(node) == "table" then
			if node.elem == "TreeView" then table.remove(root,index)
			elseif node.elem == "Build" then
				node.attrib.viewMode = nil
				for i=#node,1,-1 do if type(node[i]) == "table" and (node[i].elem == "PlayerStat" or node[i].elem == "MinionStat") then table.remove(node,i) end end
			end
		end
	end
	return sha1((build.buildName or "")..assert(common.xml.ComposeXML(root)))
end

local function stats(build)
	local result = { }
	for _,key in ipairs(metrics) do
		local value = build.calcsTab.calcsOutput[key]
		if type(value) == "number" and value == value and math.abs(value) < math.huge then result[key] = value end
	end
	return result
end

local function sandbox(callback)
	local originalMain, originalCache, originalError = main,GlobalCache,launch.ShowErrMsg
	local proxy = setmetatable({modes=setmetatable({},{__index=main.modes}),popups={}}, {__index=main})
	proxy.SetMode = function() error("Proposal requires a build conversion or an unsupported import") end
	proxy.OpenPopup = function() error("Proposal requires an interactive conversion or import") end
	proxy.SetWindowTitleSubtext = function() end
	main = proxy
	GlobalCache = setmetatable({cachedData={MAIN={},CALCS={},CALCULATOR={}}},{__index=originalCache})
	launch.ShowErrMsg = function(_,message,...) error(string.format(message,...)) end
	local ok,result = xpcall(function() return callback(proxy) end,debug.traceback)
	main,GlobalCache,launch.ShowErrMsg = originalMain,originalCache,originalError
	assert(ok,result)
	return result
end

local function integer(value, low, high, label)
	assert(type(value) == "number" and value == math.floor(value) and value >= low and value <= high,"Invalid "..label)
	return value
end

local function text(value, limit, label)
	assert(type(value) == "string" and #value <= limit,"Invalid "..label)
	return value
end

local function configOptions()
	local map = { }
	for _,entry in ipairs(require("Modules.ConfigOptions")) do if entry.var then map[entry.var] = entry end end
	return map
end

local function applyOperation(build, op)
	assert(type(op) == "table","Invalid operation")
	if op.type == "set_character" then
		if op.level then build.characterLevel = integer(op.level,1,100,"character level"); build.characterLevelAutoMode = false end
		if op.className then
			local classId = build.spec.tree.classNameMap[text(op.className,40,"class name")]
			assert(classId,"Unknown character class")
			-- Reset allocations when changing class, as for a fresh native tree.
			if classId ~= build.spec.curClassId then build.spec:ResetNodes(); build.spec:SelectClass(classId) end
		end
		if op.ascendancy then
			local id
			for index,entry in pairs(build.spec.curClass.classes) do if entry.name == op.ascendancy then id = index end end
			assert(id,"Unknown ascendancy for selected class")
			build.spec:SelectAscendClass(id)
		end
	elseif op.type == "allocate_passives" then
		for _,id in ipairs(op.remove or { }) do
			local node = assert(build.spec.nodes[integer(id,1,1000000,"passive ID")],"Unknown passive")
			assert(not node.isAscendancyStart and node.type ~= "ClassStart","Cannot remove a class start")
			if node.alloc then build.spec:DeallocNode(node) end
		end
		for _,id in ipairs(op.add or { }) do
			local node = assert(build.spec.nodes[integer(id,1,1000000,"passive ID")],"Unknown passive")
			assert(node.path and node.type ~= "Mastery","Passive is unreachable or needs a mastery effect")
			build.spec:AllocNode(node)
		end
		for _,selection in ipairs(op.masteries or { }) do
			local node = assert(build.spec.nodes[selection.nodeId],"Unknown mastery")
			assert(node.type == "Mastery" and node.path,"Mastery is unreachable")
			local valid = false
			for _,effect in ipairs(node.masteryEffects or { }) do if effect.effect == selection.effectId then valid = true end end
			assert(valid,"Effect does not belong to this mastery")
			for id,effectId in pairs(build.spec.masterySelections) do assert(id == node.id or effectId ~= selection.effectId,"Mastery effect is already allocated") end
			build.spec:AllocNode(node)
			local effect = assert(build.spec.tree.masteryEffects[selection.effectId],"Unknown mastery effect")
			node.sd,node.allMasteryOptions = effect.sd,false
			build.spec.tree:ProcessStats(node)
			build.spec.masterySelections[node.id] = selection.effectId
		end
	elseif op.type == "equip_item" then
		local slot = assert(build.itemsTab.slots[text(op.slot,80,"equipment slot")],"Unknown equipment slot")
		local item = new("Item"):Item(text(op.text,24000,"item text"))
		assert(item.baseName and build.itemsTab:IsItemValidForSlot(item,op.slot),"Item cannot be equipped in this slot")
		item:NormaliseQuality()
		build.itemsTab:AddItem(item,true)
		slot:SetSelItemId(item.id)
		if op.active ~= nil then assert(type(op.active) == "boolean","Invalid flask state"); slot.active = op.active end
		build.itemsTab:PopulateSlots()
	elseif op.type == "set_skills" then
		assert(type(op.groups) == "table" and #op.groups <= 40,"Invalid socket groups")
		local groups = { }
		for _,source in ipairs(op.groups) do
			assert(type(source.gems) == "table" and #source.gems <= 12,"Invalid gem list")
			if source.slot then assert(build.itemsTab.slots[source.slot],"Unknown socket-group slot") end
			local active = integer(source.mainActiveSkill or 1,1,12,"active skill index")
			local group = {label=text(source.label or "",120,"group label"),slot=source.slot,enabled=source.enabled ~= false,includeInFullDPS=source.includeInFullDPS == true,gemList={},mainActiveSkill=active,mainActiveSkillCalcs=active}
			for _,gem in ipairs(source.gems) do
				local entry = {nameSpec=text(gem.name,160,"gem name"),level=integer(gem.level or 20,1,40,"gem level"),quality=integer(gem.quality or 0,0,100,"gem quality"),qualityId="Default",enabled=gem.enabled ~= false,enableGlobal1=true,enableGlobal2=false,count=1}
				group.gemList[#group.gemList+1] = entry
			end
			build.skillsTab:ProcessSocketGroup(group)
			for _,gem in ipairs(group.gemList) do assert(gem.gemData and not gem.errMsg,"Unknown or invalid gem: "..gem.nameSpec) end
			groups[#groups+1] = group
		end
		build.skillsTab.socketGroupList = groups
		build.skillsTab.skillSets[build.skillsTab.activeSkillSetId].socketGroupList = groups
		build.mainSocketGroup = integer(op.mainGroup or 1,1,math.max(1,#groups),"main socket group")
		build.calcsTab.input.skill_number = build.mainSocketGroup
		build.skillsTab:SetDisplayGroup(groups[1])
	elseif op.type == "set_config" then
		local options = configOptions()
		assert(type(op.values) == "table","Invalid configuration")
		for key,value in pairs(op.values) do
			local option = assert(options[key],"Unknown configuration: "..tostring(key))
			if option.type == "check" then assert(type(value) == "boolean","Configuration requires a boolean: "..key)
			elseif option.type == "count" then assert(type(value) == "number" and value == value and math.abs(value) <= 1e9,"Configuration requires a finite number: "..key)
			elseif option.type == "list" then
				local valid = false
				local control = build.configTab.varControls[key]
				for _,entry in ipairs(control and control.list or { }) do if entry.val == value then valid = true end end
				assert(valid,"Invalid configuration choice: "..key)
			else text(value,24000,"configuration value") end
			build.configTab.input[key] = value
		end
	elseif op.type == "set_notes" then
		build.notesTab.controls.edit:SetText(text(op.text,64000,"notes"))
	else error("Unknown operation: "..tostring(op.type)) end
end

function M.prepare(build, proposal)
	assert(type(proposal) == "table" and (proposal.mode == "edit" or proposal.mode == "new"),"Choose edit or new build")
	assert(type(proposal.operations) == "table" and #proposal.operations > 0 and #proposal.operations <= 100,"Use 1 to 100 operations")
	assert(proposal.baseRevision == M.revision(build),"Build changed. Refresh context and submit a new proposal.")
	local title = text(proposal.title,120,"proposal title")
	assert(title:match("%S") and not title:find("[%c]"),"Title must be a nonempty single line")
	local source = proposal.mode == "edit" and serialize(build) or nil
	local candidate = sandbox(function(proxy)
		local candidate = LoadModule("Modules/Build")
		proxy.modes.BUILD = candidate
		candidate:Init(nil,proposal.mode == "new" and title or build.buildName,source)
		assert(candidate.abortSave == false,"Unable to initialize proposed build")
		for _,operation in ipairs(proposal.operations) do applyOperation(candidate,operation) end
		candidate.configTab:BuildModList()
		candidate.configTab:UpdateControls()
		candidate:UpdateClassDropdowns()
		candidate.skillsTab:UpdateSocketGroups()
		wipeGlobalCache()
		candidate.calcsTab:BuildOutput()
		candidate:RefreshStatList()
		local calculatedLevel = candidate.characterLevel
		candidate:EstimatePlayerProgress()
		if candidate.characterLevel ~= calculatedLevel then candidate.calcsTab:BuildOutput(); candidate:RefreshStatList() end
		candidate.controls.characterLevel:SetText(tostring(candidate.characterLevel))
		candidate.buildFlag = false
		return candidate
	end)
	local after = stats(candidate)
	local before = stats(build)
	local delta = { }
	for key,value in pairs(after) do if before[key] then delta[key] = value-before[key] end end
	return {candidate=candidate,baseRevision=proposal.baseRevision,mode=proposal.mode,title=title,operations=proposal.operations,before=before,after=after,delta=delta,base=build,warnings=copyTable(candidate.controls.warnings.lines)}
end

function M.apply(prepared)
	assert(main.modes.BUILD == prepared.base and M.revision(prepared.base) == prepared.baseRevision,"Build changed since preview. Submit a fresh proposal.")
	local candidate = prepared.candidate
	if prepared.mode == "edit" then candidate.dbFileName,candidate.dbFileSubPath = prepared.base.dbFileName,prepared.base.dbFileSubPath end
	candidate.modFlag,candidate.unsaved = true,true
	main.modes.BUILD = candidate
	candidate.spec:SetWindowTitleWithBuildClass()
	M.previous,M.build = prepared.base,candidate
	M.appliedRevision = M.revision(candidate)
	M.prepared = nil
	return candidate
end

local function writeFile(path, value)
	local file = assert(io.open(path,"wb"),"Cannot write AI context")
	local ok,err = file:write(json.encode(value))
	file:close()
	assert(ok,err)
end

local function path(name) return main.userPath.."AI-build-"..name..".json" end

function M.capture(build)
	local context = {revision=M.revision(build),name=build.buildName,level=build.characterLevel,className=build.spec.curClassName,ascendancy=build.spec.curAscendClassName,
		stats=stats(build),items={},skills={},passives={},masteries=copyTable(build.spec.masterySelections),config=copyTable(build.configTab.input),
		warnings=copyTable(build.controls.warnings.lines),slots={}}
	local catalog = {gems={},passives={},config={},classes={}}
	for name,slot in pairs(build.itemsTab.slots) do
		context.slots[#context.slots+1] = name
		local item = build.itemsTab.items[slot.selItemId]
		if item then context.items[#context.items+1] = {slot=name,id=item.id,name=item.name,text=item.raw,active=slot.active} end
	end
	table.sort(context.slots)
	for index,group in ipairs(build.skillsTab.socketGroupList) do
		local entry = {index=index,label=group.label,slot=group.slot,enabled=group.enabled,includeInFullDPS=group.includeInFullDPS,gems={}}
		for _,gem in ipairs(group.gemList) do entry.gems[#entry.gems+1] = {name=gem.nameSpec,level=gem.level,quality=gem.quality,enabled=gem.enabled} end
		context.skills[#context.skills+1] = entry
	end
	for _,node in pairs(build.spec.nodes) do
		if node.alloc then context.passives[#context.passives+1] = node.id end
		catalog.passives[#catalog.passives+1] = {id=node.id,name=node.name,type=node.type,stats=node.sd,ascendancy=node.ascendancyName,allocated=node.alloc or false,pathLength=node.path and #node.path,masteryEffects=node.masteryEffects}
	end
	table.sort(context.passives)
	for _,gem in pairs(build.data.gems) do catalog.gems[#catalog.gems+1] = {name=gem.name,id=gem.id,maxLevel=gem.naturalMaxLevel} end
	for _,option in ipairs(require("Modules.ConfigOptions")) do
		if option.var then
			local choices = { }
			local control = build.configTab.varControls[option.var]
			if option.type == "list" then for _,entry in ipairs(control and control.list or { }) do choices[#choices+1] = {value=entry.val,label=entry.label} end end
			catalog.config[#catalog.config+1] = {key=option.var,label=StripEscapes(option.label or ""),type=option.type,choices=choices}
		end
	end
	for _,class in pairs(build.spec.tree.classes) do
		local entry = {name=class.name,ascendancies={}}
		for _,ascendancy in pairs(class.classes) do entry.ascendancies[#entry.ascendancies+1] = ascendancy.name end
		catalog.classes[#catalog.classes+1] = entry
	end
	return {schemaVersion=1,session=M.session,capturedAt=os.date("!%Y-%m-%dT%H:%M:%SZ"),context=context,catalog=catalog}
end

function M.publishState()
	writeFile(path("state"),{schemaVersion=1,session=M.session,enabled=M.enabled,heartbeat=os.time(),revision=M.contextRevision,proposal=M.status})
end

function M.refresh(build)
	local captured = M.capture(build)
	M.contextRevision = captured.context.revision
	writeFile(path("context"),captured)
	M.publishState()
end

function M.enable(build)
	M.enabled,M.build,M.prepared,M.status,M.contextRevision = true,build,nil,nil,nil
	M.session = sha1(tostring({})..tostring(os.time())..tostring(GetTime()))
	local ok,err = pcall(M.refresh,build)
	if not ok then M.enabled=false; error(err) end
end

function M.disable(build)
	if not M.enabled or M.build ~= build then return end
	M.enabled,M.prepared = false,nil
	M.publishState()
end

function M.poll(build, force)
	if not M.enabled then return end
	if M.build ~= build then M.disable(M.build); return end
	if not force and GetTime() < (M.nextPoll or 0) then return end
	M.nextPoll = GetTime()+1000
	local ok,err = pcall(function()
		if build.buildFlag then return end
		if M.contextRevision ~= M.revision(build) then M.refresh(build) else M.publishState() end
		local file = io.open(path("request"),"rb")
		if not file then return end
		local requestText = file:read(262145); file:close()
		os.remove(path("request"))
		assert(#requestText <= 262144,"Proposal exceeds the supported size")
		local request = assert(json.decode(requestText),"Invalid proposal JSON")
		assert(request.session == M.session,"Proposal belongs to another desktop session")
		assert(type(request.id) == "string" and request.id:match("^[%w%-]+$") and #request.id <= 80,"Invalid proposal ID")
		if M.prepared then return end
		M.status = {id=request.id,title=request.proposal and request.proposal.title,status="calculating"}
		M.publishState()
		local prepared = M.prepare(build,request.proposal)
		M.prepared = prepared
		local resolved = M.capture(prepared.candidate).context
		resolved.xml = nil
		M.status = {id=request.id,title=prepared.title,status="review",before=prepared.before,after=prepared.after,delta=prepared.delta,warnings=prepared.warnings,resolved=resolved,
			instructions="Open AI tools > Build proposals in PoB to review. Only a desktop button can apply this proposal."}
		M.publishState()
	end)
	if not ok then
		M.status = {id=M.status and M.status.id,status="failed",error=tostring(err):match("^[^\n]+")}
		pcall(M.publishState)
	end
end

function M.reject()
	M.prepared = nil
	if M.status then M.status.status = "rejected" end
	M.publishState()
end

function M.restore()
	assert(M.previous and main.modes.BUILD == M.build,"No original build available")
	assert(M.revision(M.build) == M.appliedRevision,"The proposed build has been edited. Save your work before switching builds.")
	local original = M.previous
	main.modes.BUILD = original
	original.spec:SetWindowTitleWithBuildClass()
	M.previous,M.build = nil,original
	if M.status then M.status.status = "reverted" end
	M.refresh(original)
	return original
end

return M
