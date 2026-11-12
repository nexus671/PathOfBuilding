-- Path of Building
--
-- Class: Calc Breakdown Control
-- Calculation breakdown control used in the Calcs tab
--
local t_insert = table.insert
local s_format = string.format
local m_max = math.max
local m_min = math.min
local m_ceil = math.ceil
local m_floor = math.floor
local m_sin = math.sin
local m_cos = math.cos
local m_pi = math.pi
local band = bit.band

---@class CalcBreakdownControl: Control, ControlHost
local CalcBreakdownClass = newClass("CalcBreakdownControl", "Control", "ControlHost")

---@param calcsTab CalcsTab
function CalcBreakdownClass:CalcBreakdownControl(calcsTab)
	self:Control()
	self:ControlHost()
	self.calcsTab = calcsTab
	self.shown = false
	self.tooltip = new("Tooltip"):Tooltip()
	self.nodeViewer = new("PassiveTreeView"):PassiveTreeView()
	self.rangeGuide = NewImageHandle()
	self.rangeGuide:Load("Assets/range_guide.png")
	self.uiOverlay = NewImageHandle()
	self.uiOverlay:Load("Assets/game_ui_small.png")
	self.borderThickness = 2
	self.controls.scrollBar = new("ScrollBarControl"):ScrollBarControl({ "RIGHT", self, "RIGHT" }, { -2, 0, 18, 0 }, 80,
	"VERTICAL", true)
	self.controls.scrollBar.x = function()
		return -self.borderThickness
	end
	self.pinnedColour = { 0.25, 1, 0.25 }
	self.borderColour = { 0.33, 0.66, 0.33 }
	self.controls.timelineClose = new("ButtonControl"):ButtonControl({"TOPRIGHT",self,"TOPRIGHT"},{-24,4,62,20},"Close",function()
		self.calcsTab:ClearDisplayStat()
		self.shown = false
	end)
	self.controls.timelineClose.shown = function() return self.isTimeline end
	self.controls.timelineSamples = new("CheckBoxControl"):CheckBoxControl({"TOPRIGHT",self,"TOPRIGHT"},{-240,5,18},"Show samples",function(state)
		self.showTimelineSamples = state
		local source,pinned,force = self.sourceData,self.pinned,self.forceActor
		self.sourceData = nil
		self:SetBreakdownData(source,pinned,force)
	end)
	self.controls.timelineSamples.shown = function() return self.isTimeline end
	return self
end

function CalcBreakdownClass:IsMouseOver()
	if not self:IsShown() then
		return
	end
	return self:IsMouseInBounds() or self:GetMouseOverControl() 
end

function CalcBreakdownClass:GetActor()
	local env = self.calcsTab[self.envName or "calcsEnv"]
	local actor = self.calcsTab.input.showMinion and env.minion or env.player
	if self.forceActor then
		actor = env[self.forceActor]
	end
	return actor, env
end
---@param displayData any
---@param pinned any
---@param forceActor "player"|"minion"|nil
function CalcBreakdownClass:SetBreakdownData(displayData, pinned, forceActor)
	self.pinned = pinned
	if displayData == self.sourceData then
		return
	end
	self.sourceData = displayData
	self.forceActor = forceActor
	self.shown = false
	if not displayData then
		return
	end

	-- Build list of sections
	local actor, env = self:GetActor()
	self.sectionList = wipeTable(self.sectionList)
	for _, sectionData in ipairs(displayData) do
		if self.calcsTab:CheckFlag(sectionData, actor, env.player) then
			if sectionData.breakdown then
				self:AddBreakdownSection(sectionData)
			elseif sectionData.modName then
				self:AddModSection(sectionData)
			end
		end
	end
	if #self.sectionList == 0 then
		if self.clearDisplayFunc then
			self.clearDisplayFunc()
		else
			self.calcsTab:ClearDisplayStat()
		end
		return
	end

	self.shown = true
	self.isTimeline = false
	for _,section in ipairs(self.sectionList) do if section.type == "TIMELINE" then self.isTimeline = true end end
	if self.isTimeline and not self.showTimelineSamples then
		for _,section in ipairs(self.sectionList) do
			if section.type == "TABLE" then
				local events = { }
				for _,row in ipairs(section.rowList) do if row.event ~= "Sample" then events[#events+1] = row end end
				section.rowList = events
			end
		end
	end

	-- Determine the size of each section, and the combined content size of the breakdown
	self.contentWidth = 0
	local offset = self.isTimeline and 28 or 2
	for i, section in ipairs(self.sectionList) do
		if section.type == "TEXT" then
			section.width = 0
			for _, line in ipairs(section.lines) do
				local _, num = string.gsub(line, "%d%d%d%d", "") -- count how many commas will be added
				if main.showThousandsSeparators and num > 0 then
					section.width = m_max(section.width, DrawStringWidth(section.textSize, "VAR", line) + 8 + (4 * num))
				else
					section.width = m_max(section.width, DrawStringWidth(section.textSize, "VAR", line) + 8)
				end
			end
			section.height = #section.lines * section.textSize + 4
		elseif section.type == "TABLE" then
			-- This also calculates the width of each column in the table
			section.width = 4
			for _, col in pairs(section.colList) do
				for _, row in pairs(section.rowList) do
					if row[col.key] then
						local _, num = string.gsub(row[col.key], "%d%d%d%d", "") -- count how many commas will be added
						if main.showThousandsSeparators and num > 0 then
							col.width = m_max(col.width or 0, DrawStringWidth(16, "VAR", col.label) + 6, DrawStringWidth(self.isTimeline and 14 or 12, "VAR", row[col.key]) + 6 + (4 * num))
						else 
							col.width = m_max(col.width or 0, DrawStringWidth(16, "VAR", col.label) + 6, DrawStringWidth(self.isTimeline and 14 or 12, "VAR", row[col.key]) + 6)
						end
					end
				end
				if col.width then
					section.width = section.width + col.width
				end
			end
			section.height = #section.rowList * (self.isTimeline and 18 or 14) + 20
			if section.label then
				self.contentWidth = m_max(self.contentWidth, 6 + DrawStringWidth(16, "VAR", section.label..":"))
				section.height = section.height + 16
			end
			if section.footer then
				self.contentWidth = m_max(self.contentWidth, 6 + DrawStringWidth(12, "VAR", section.footer))
				local _, lines = string.gsub(section.footer, "\n", "\n") -- counts newlines in the string
				section.height = section.height + 12 * (lines + 1)
			end
		end
		self.contentWidth = m_max(self.contentWidth, section.width)
		section.offset = offset
		offset = offset + section.height + 8
	end
	self.contentHeight = offset - 6
end

-- Add sections based on the breakdown data generated by the Calcs module
function CalcBreakdownClass:AddBreakdownSection(sectionData)
	local actor = self:GetActor()
	local breakdown
	local ns, name = sectionData.breakdown:match("^(%a+)%.(%a+)$")
	if ns then
		breakdown = actor.breakdown[ns] and actor.breakdown[ns][name]
	else
		breakdown = actor.breakdown[sectionData.breakdown]
	end
	if not breakdown then
		return
	end

	if #breakdown > 0 then
		-- Text lines
		local lines = breakdown
		if breakdown.wrap then
			lines = { }
			for _,text in ipairs(breakdown) do
				local line = ""
				for word in text:gmatch("%S+") do
					local candidate = line == "" and word or line.." "..word
					if line ~= "" and DrawStringWidth(16,"VAR",candidate) > breakdown.wrap then lines[#lines + 1] = line; line = word
					else line = candidate end
				end
				lines[#lines + 1] = line
			end
		end
		t_insert(self.sectionList, {
			type = "TEXT",
			lines = lines,
			textSize = 16
		})
	end

	if breakdown.radius then
		-- Radius visualiser
		t_insert(self.sectionList, {
			type = "RADIUS",
			radius = breakdown.radius,
			width = 8 + 1920/4,
			height = 4 + 1080/4,
		})
	end
	if breakdown.timeline then
		t_insert(self.sectionList,{type="TIMELINE",timeline=breakdown.timeline,width=730,height=340})
	end

	if breakdown.rowList and #breakdown.rowList > 0 then
		-- sort by the first column (the value)
		local rowList = copyTable(breakdown.rowList, true)
		local colKey = breakdown.colList[1].key
		-- avoid sorting ailment breakdowns
		if breakdown.source then
			table.sort(rowList, function(a, b)
				if a.reqNum then
					return a.reqNum > b.reqNum
				end
				return a[colKey] > b[colKey]
			end)
		end
		-- Generic table
		local section = {
			type = "TABLE",
			label = breakdown.label,
			footer = breakdown.footer,
			rowList = rowList,
			colList = breakdown.colList,
		}
		t_insert(self.sectionList, section)
	end

	if breakdown.reservations and #breakdown.reservations > 0 then
		-- Reservations table, used for life/mana reservation breakdowns
		local section = {
			type = "TABLE",
			rowList = breakdown.reservations,
			colList = { 
				{ label = "Skill", key = "skillName" },
				{ label = "Base", key = "base" },
				{ label = "MCM", key = "mult" },
				{ label = "More/less", key = "more" },
				{ label = "Inc/red", key = "inc" },
				{ label = "Efficiency", key = "efficiency" },
				{ label = "Efficiency More/less", key = "efficiencyMore" },
				{ label = "Reservation", key = "total" },
			}
		}
		t_insert(self.sectionList, section)
	end

	if breakdown.damageTypes and #breakdown.damageTypes > 0 then
		local section = {
			type = "TABLE",
			rowList = breakdown.damageTypes,
			colList = { 
				{ label = "From", key = "source", right = true },
				{ label = "Base", key = "base" },
				{ label = "Inc/red", key = "inc" },
				{ label = "More/less", key = "more" },
				{ label = "Converted Damage", key = "convSrc" },
				{ label = "Total", key = "total" },
				{ label = "Conversion", key = "convDst" },
				{ label = "Gain", key = "gainDst" },
			}
		}
		t_insert(self.sectionList, section)
	end

	if breakdown.slots and #breakdown.slots > 0 then
		-- Slots table, used for armour/evasion/ES total breakdowns
		local colList
		local rowList
		if (sectionData.gearOnly) then
			-- Only show basic table for gear and base ES/Armour/Evasion value
			colList = {
				{ label = "Value", key = "base", right = true },
				{ label = "Source", key = "source" },
				{ label = "Name", key = "sourceLabel" },
			}

			rowList = {}
			for _, row in pairs(breakdown.slots) do
				if (row.item and row.item.armourData) then
					table.insert(rowList, row)
				end
			end
		else
			colList = {
				{ label = "Base", key = "base", right = true },
				{ label = "Inc/red", key = "inc" },
				{ label = "More/less", key = "more" },
				{ label = "Total", key = "total", right = true },
				{ label = "Source", key = "source" },
				{ label = "Name", key = "sourceLabel" },
			}

			rowList = breakdown.slots
		end

		table.sort(rowList, function(a, b)
			return a['base'] > b['base']
		end)
		
		local section = { 
			type = "TABLE",
			rowList = rowList,
			colList = colList,
		}
		t_insert(self.sectionList, section)
		for _, row in pairs(section.rowList) do
			if row.item then
				row.sourceLabel = colorCodes[row.item.rarity]..row.item.name
				row.sourceLabelTooltip = function(tooltip)
					self.calcsTab.build.itemsTab:AddItemTooltip(tooltip, row.item, row.source)
				end
			else
				row.sourceLabel = row.sourceName
			end
		end
	end

	if breakdown.modList and #breakdown.modList > 0 then
		-- Provided mod list
		self:AddModSection(sectionData, breakdown.modList)
	end
end

-- Add a table section showing a list of modifiers
function CalcBreakdownClass:AddModSection(sectionData, modList)
	local actor = self:GetActor()
	local build = self.calcsTab.build

	-- Build list of modifiers to display
	local cfg = (sectionData.cfg and actor.mainSkill[sectionData.cfg.."Cfg"] and copyTable(actor.mainSkill[sectionData.cfg.."Cfg"], true)) or { }
	cfg.source = sectionData.modSource
	cfg.actor = sectionData.actor
	local rowList
	local modStore = (sectionData.enemy and actor.enemy.modDB) or (sectionData.cfg and actor.mainSkill.skillModList) or actor.modDB
	if modList then
		rowList = copyTable(modList)
	else
		if type(sectionData.modName) == "table" then
			rowList = modStore:Tabulate(sectionData.modType, cfg, unpack(sectionData.modName))
		else
			rowList = modStore:Tabulate(sectionData.modType, cfg, sectionData.modName)
		end
	end
	if #rowList == 0 then
		return
	end

	-- Create section data
	local section = {
		type = "TABLE",
		label = sectionData.label,
		rowList = rowList,
		colList = { 
			{ label = "Value", key = "displayValue" },
			{ label = "Stat", key = "name" },
			{ label = "Skill types", key = "flags" },
			{ label = "Notes", key = "tags" },
			{ label = "Source", key = "source" },
			{ label = "Source Name", key = "sourceName" },
		},
	}
	t_insert(self.sectionList, section)

	if not modList and not sectionData.modType then
		-- Sort modifiers by type
		table.sort(rowList, function(a, b)
			if a.mod.type == b.mod.type then
				return a.mod.name > b.mod.name or (a.mod.name == b.mod.name and type(a.value) == "number" and type(b.value) == "number") and a.value > b.value
			else
				return a.mod.type < b.mod.type
			end
		end)
	else -- Sort modifiers by value
		table.sort(rowList, function(a, b)
			return a.mod.name > b.mod.name or (a.mod.name == b.mod.name and type(a.value) == "number" and type(b.value) == "number") and a.value > b.value
		end)
	end

	local sourceTotals = { }
	if not modList and not sectionData.modSource then
		-- Build list of totals from each modifier source
		local types = { }
		local typeList = { }
		for i, row in ipairs(rowList) do
			-- Find all the modifier types and source types that are present in the modifier list
			if not types[row.mod.type] then
				types[row.mod.type] = true
				t_insert(typeList, row.mod.type)
			end
			if not row.mod.source then
				ConPrintTable(row.mod)
			end
			local sourceType = row.mod.source:match("[^:]+")
			if not sourceTotals[sourceType] then
				sourceTotals[sourceType] = { }
			end	
		end
		for sourceType, lines in pairs(sourceTotals) do
			cfg.source = sourceType
			for _, modType in ipairs(typeList) do
				if type(sectionData.modName) == "table" then
					-- Multiple stats, show each separately
					for _, modName in ipairs(sectionData.modName) do
						local total = modStore:Combine(modType, cfg, modName)
						if modType == "MORE" then
							total = round((total - 1) * 100)
						end
						if total and total ~= 0 then
							t_insert(lines, self:FormatModValue(total, modType) .. " " .. modName:gsub("(%l)(%u)","%1 %2"))
						end
					end
				else
					local total = modStore:Combine(modType, cfg, sectionData.modName)
					if modType == "MORE" then
						total = round((total - 1) * 100)
					end
					if total and total ~= 0 then
						t_insert(lines, self:FormatModValue(total, modType))
					end
				end
			end
		end
	end

	-- Process modifier data
	for _, row in ipairs(rowList) do
		if not sectionData.modType then
			-- No modifier type specified, so format the value to convey type
			row.displayValue = self:FormatModValue(row.value, row.mod.type)
		else
			section.colList[1].right = true
			row.displayValue = formatRound(row.value, 2)
		end
		if modList or type(sectionData.modName) == "table" then
			-- Multiple stat names specified, add this modifier's stat to the table
			row.name = self:FormatModName(row.mod.name)
		end
		local sourceType = row.mod.source and row.mod.source:match("[^:]+") or ""
		row.source = sourceType
		if not modList and not sectionData.modSource then
			-- No modifier source specified, add the source type to the table
			row.sourceTooltip = function(tooltip)
				tooltip:AddLine(16, "Total from "..sourceType..":")
				for _, line in ipairs(sourceTotals[sourceType]) do
					tooltip:AddLine(14, line)
				end
			end
		end
		if sourceType == "Item" then
			-- Modifier is from an item, add item name and tooltip
			local itemId = row.mod.source:match("Item:(%d+):.+")
			local item = build.itemsTab.items[tonumber(itemId)]
			if item then
				row.sourceName = colorCodes[item.rarity]..item.name
				row.sourceNameTooltip = function(tooltip)
					build.itemsTab:AddItemTooltip(tooltip, item, row.mod.sourceSlot)
				end
			end
		elseif sourceType == "Tree" then
			-- Modifier is from a passive node, add node name, and add node ID (used to show node location)
			local nodeId = row.mod.source:match("Tree:(%d+)")
			local textNodeId = row.mod.source:match("Tree:([%w_]+)")
			if nodeId then
				local nodeIdNumber = tonumber(nodeId)
				local node = build.spec.nodes[nodeIdNumber] or build.spec.tree.nodes[nodeIdNumber] or build.latestTree.nodes[nodeIdNumber]
				row.sourceName = node.dn
				row.sourceNameNode = node
			elseif textNodeId then
				row.sourceName = build.spec.tree.tattoo.idMap[textNodeId]
				if not row.sourceName then
					for _, node in pairs(build.spec.tree.legion.nodes) do
						if node.id == textNodeId then
							row.sourceName = node.dn
							break
						end
					end
				end
			end
		elseif sourceType == "Skill" then
			-- Extract skill name
			row.sourceName = build.data.skills[row.mod.source:match("Skill:(.+)")].name
		elseif sourceType == "Pantheon" then
			row.sourceName = row.mod.source:match("Pantheon:(.+)")
		elseif sourceType == "Spectre" then
			row.sourceName = row.mod.source:match("Spectre:(.+)")
		elseif sourceType == "Custom" then
			row.sourceName = row.mod.source:match("Custom:(.+)")
		end

		if row.mod.flags ~= 0 or row.mod.keywordFlags ~= 0 then
			-- Combine, sort and format modifier flags
			local flagNames = { }
			for flags, src in pairs({[row.mod.flags] = ModFlag, [row.mod.keywordFlags] = KeywordFlag}) do
				for name, val in pairs(src) do
					if band(flags, val) == val then
						t_insert(flagNames, name)
					end
				end
			end
			table.sort(flagNames)
			row.flags = table.concat(flagNames, ", ")
		end
		row.tags = nil
		if row.mod[1] then
			-- Format modifier tags
			local baseVal = type(row.mod.value) == "number" and (self:FormatModBase(row.mod, row.mod.value) .. " ")
			for _, tag in ipairs(row.mod) do
				local desc
				if tag.type == "Condition" or tag.type == "ActorCondition" then
					local cond = (tag.var or tag.varList) and ": "..(tag.neg and "Not " or "")..self:FormatVarNameOrList(tag.var, tag.varList) or ""
					desc = (tag.actor and (tag.actor:sub(1,1):upper()..tag.actor:sub(2).." ") or "").."Condition"..cond
				elseif tag.type == "Multiplier" then
					local base = tag.base and (self:FormatModBase(row.mod, tag.base).." + "..math.abs(row.mod.value).." ") or baseVal
					desc = base.."per "..(tag.div and (tag.div.." ") or "")..self:FormatVarNameOrList(tag.var, tag.varList)
					baseVal = ""
				elseif tag.type == "PerStat" then
					local base = tag.base and (self:FormatModBase(row.mod, tag.base).." + "..math.abs(row.mod.value).." ") or baseVal
					desc = base.."per "..(tag.div or 1).." "..(tag.actor and (tag.actor.." ") or "")..self:FormatVarNameOrList(tag.stat, tag.statList)
					baseVal = ""
				elseif tag.type == "PercentStat" then
					local finalPercent = (row.mod.value * ((tag.percent or 1) / 100)) * 100
					local base = tag.base and (self:FormatModBase(row.mod, tag.base).." + "..math.abs(finalPercent).." ") or self:FormatModBase(row.mod, finalPercent)
					desc = base.."% of "..(tag.actor and (tag.actor.." ") or "")..self:FormatVarNameOrList(tag.percentVar or tag.stat, tag.statList)
					baseVal = ""
				elseif tag.type == "MultiplierThreshold" or tag.type == "StatThreshold" then
					desc = "If "..self:FormatVarNameOrList(tag.var or tag.stat, tag.varList or tag.statList)..(tag.upper and " <= " or " >= ")..(tag.thresholdPercent and tag.thresholdPercent.."% " or "")..(tag.threshold or self:FormatModName(tag.thresholdVar or tag.thresholdStat))
				elseif tag.type == "SkillName" then
					desc = "Skill: "..(tag.skillNameList and table.concat(tag.skillNameList, " / ") or tag.skillName)
				elseif tag.type == "SkillId" then
					desc = "Skill: "..build.data.skills[tag.skillId].name
				elseif tag.type == "SkillType" then
					for name, type in pairs(SkillType) do
						if type == tag.skillType then
							desc = "Skill type: "..(tag.neg and "Not " or "")..self:FormatModName(name)
							break
						end
					end
					if not desc then
						desc = "Skill type: "..(tag.neg and "Not " or "").."?"
					end
				elseif tag.type == "BaseFlag" then
					desc = "Base flag: "..(tag.neg and "Not " or "")..self:FormatModName(tostring(tag.baseFlag))
				elseif tag.type == "SlotNumber" then
					desc = "When in slot #"..tag.num
				elseif tag.type == "GlobalEffect" then
					desc = self:FormatModName(tag.effectType)
				elseif tag.type == "Limit" then
					desc = "Limited to "..(tag.limitVar and self:FormatModName(tag.limitVar) or self:FormatModBase(row.mod, tag.limit))
				elseif tag.type == "MonsterTag" then
					desc = "Monster Tag: "..(tag.monsterTagList and table.concat(tag.monsterTagList, "/") or tag.monsterTag)
				else
					desc = self:FormatModName(tag.type)
				end
				if desc then
					row.tags = (row.tags and row.tags .. ", " or "") .. desc
				end
			end
		end
	end
end

function CalcBreakdownClass:FormatModName(modName)
	return modName:gsub("([%l%d]:?)(%u)","%1 %2"):gsub("(%l)(%d)","%1 %2")
end

function CalcBreakdownClass:FormatVarNameOrList(var, varList)
	return var and self:FormatModName(var) or self:FormatModName(table.concat(varList, " / "))
end

function CalcBreakdownClass:FormatModBase(mod, base)
	return mod.type == "BASE" and string.format("%+g", math.abs(base)) or math.abs(base).."%"
end

function CalcBreakdownClass:FormatModValue(value, modType)
	if modType == "BASE" then
		return string.format("%+g base", value)
	elseif modType == "INC" then
		if value >= 0 then
			return value.."% increased"
		else
			return -value.."% reduced"
		end
	elseif modType == "MORE" then
		if value >= 0 then
			return value.."% more"
		else
			return -value.."% less"
		end
	elseif modType == "OVERRIDE" then
		return "Override: "..value
	elseif modType == "FLAG" then
		return value and "True" or "False"
	elseif modType == "LIST" then
		if value.mod then
			return "Modifier: "..self:FormatModName(value.mod.name)
		else
			return "?"
		end
	else
		return value		
	end
end

function CalcBreakdownClass:DrawBreakdownTable(viewPort, x, y, section)
	local cursorX, cursorY = GetCursorPos()
	local rowHeight, textSize = self.isTimeline and 18 or 14, self.isTimeline and 14 or 12
	if section.label then
		-- Draw table label if able
		DrawString(x + 2, y, "LEFT", 16, "VAR", "^7"..section.label..":")
		y = y + 16
	end
	local colX = x + 4
	for index, col in ipairs(section.colList) do
		if col.width then
			-- Column is present, draw the separator and label
			col.x = colX
			if index > 1 then
				-- Skip the separator for the first column
				SetDrawColor(0.5, 0.5, 0.5)
				DrawImage(nil, colX - 2, y, 1, section.height - (section.label and 16 or 0) - (section.footer and 12 or 0))
			end
			SetDrawColor(1, 1, 1)
			DrawString(colX, y + 2, "LEFT", 16, "VAR", col.label)
			colX = colX + col.width
		end
	end
	local rowY = y + 20
	for _, row in ipairs(section.rowList) do
		-- Draw row separator
		SetDrawColor(0.5, 0.5, 0.5)
		DrawImage(nil, x + 2, rowY - 1, section.width - 4, 1)
		for _, col in ipairs(section.colList) do
			if col.width and row[col.key] then
				-- This row has an entry for this column, draw it
				local _, alpha = string.gsub(row[col.key], "%a", " ") -- counts letters in the string
				local _, notes = string.gsub(row[col.key], " to ", " ") -- counts " to " in the string
				local _, paren = string.gsub(row[col.key], "%b()", " ") -- counts parenthesis in the string
				if (alpha == 0 or notes > 0 or paren > 0) and col.right then
					DrawString(col.x + col.width - 4, rowY + 1, "RIGHT_X", textSize, "VAR", "^7"..formatNumSep(tostring(row[col.key])))
				elseif (alpha == 0 or notes > 0 or paren > 0) then
					DrawString(col.x, rowY + 1, "LEFT", textSize, "VAR", "^7"..formatNumSep(tostring(row[col.key])))
				else
					DrawString(col.x, rowY + 1, "LEFT", textSize, "VAR", "^7"..tostring(row[col.key]))
				end
				local ttFunc = row[col.key.."Tooltip"]
				local ttNode = row[col.key.."Node"]
				if (ttFunc or ttNode) and cursorY >= viewPort.y + 2 and cursorY < viewPort.y + viewPort.height - 2 and cursorX >= col.x and cursorY >= rowY and cursorX < col.x + col.width and cursorY < rowY + 14 then
					-- Mouse is over the cell, draw highlighting lines and show the tooltip/node location
					SetDrawLayer(nil, 15)
					SetDrawColor(0, 1, 0)
					DrawImage(nil, col.x - 2, rowY - 1, col.width, 1)
					DrawImage(nil, col.x - 2, rowY + 13, col.width, 1)
					if ttFunc then
						self.tooltip:Clear()
						ttFunc(self.tooltip)
						self.tooltip:Draw(col.x, rowY, col.width, 12, viewPort)
					elseif ttNode and ttNode.x and ttNode.y then -- The source "node" from cluster jewels don't know their location because it's the abstract node in tree.lua rather than the generated node from the cluster jewel.
						local viewerX = col.x + col.width + 5
						if viewPort.x + viewPort.width < viewerX + 304 then
							viewerX = col.x - 309
						end
						local viewerY = m_min(rowY, viewPort.y + viewPort.height - 304)
						SetDrawColor(1, 1, 1)
						DrawImage(nil, viewerX, viewerY, 304, 304)
						local viewer = self.nodeViewer
						viewer.zoom = 5
						local scale = self.calcsTab.build.spec.tree.size / 1500
						viewer.zoomX = -ttNode.x / scale
						viewer.zoomY = -ttNode.y / scale
						SetViewport(viewerX + 2, viewerY + 2, 300, 300)
						viewer:Draw(self.calcsTab.build, { x = 0, y = 0, width = 300, height = 300 }, { })
						SetDrawLayer(nil, 30)
						SetDrawColor(1, 0, 0)
						DrawImage(viewer.highlightRing, 135, 135, 30, 30)
						SetViewport()
					end
					SetDrawLayer(nil, 10)
				end
			end
		end
		rowY = rowY + rowHeight
	end
	if section.footer then
		-- Draw table footer if able
		DrawString(x + 2, rowY, "LEFT", 12, "VAR", "^7"..section.footer)
	end
end

function CalcBreakdownClass:DrawRadiusVisual(x, y, width, height, radius)
	SetDrawColor(0.75, 0.75, 0.75)
	DrawImage(self.rangeGuide, x, y, width, height)
	--SetDrawColor(0, 0, 0)
	--DrawImage(nil, x, y, width, height)
	--[[SetDrawColor(0.5, 0.5, 0.75)
	for r = 10, 130, 20 do
		main:RenderRing(x, y, width, height, 0, 0, r, 3)
	end
	SetDrawColor(1, 1, 1)
	for r = 20, 120, 20 do
		main:RenderRing(x, y, width, height, 0, 0, r, 3)
	end
	main:RenderCircle(x, y, width, height, 0, 0, 2)]]
	SetDrawColor(0.5, 1, 0.5, 0.33)
	main:RenderCircle(x, y, width, height, 0, 0, radius)
	--[[SetDrawColor(1, 0.5, 0.5, 0.33)
	if not self.foo1 then
		self.foo1, self.foo2 = 0, 0
	end
	if IsKeyDown("LEFT") then
		self.foo1 = self.foo1 - 0.3
	elseif IsKeyDown("RIGHT") then
		self.foo1 = self.foo1 + 0.3
	end
	if IsKeyDown("UP") then
		self.foo2 = self.foo2 + 0.3
	elseif IsKeyDown("DOWN") then
		self.foo2 = self.foo2 - 0.3
	end
	main:RenderCircle(x, y, width, height, self.foo1, self.foo2, 30)]]
	SetDrawColor(1, 1, 1)
	DrawImage(self.uiOverlay, x, y, width, height)
end

function CalcBreakdownClass:DrawEncounterTimeline(x,y,section)
	local trace=section.timeline
	local width,plotX,plotWidth=section.width,x+48,section.width-65
	local stop=m_max(0.001,trace.time or trace.window)
	local step=m_min(100,((section.height or 340)-40)/3)
	local plotHeight=step-38
	local function line(x1,y1,x2,y2)
		local dx,dy=x2-x1,y2-y1
		local length=math.sqrt(dx*dx+dy*dy)
		if length < 1e-8 then return end
		local ox,oy=-dy/length*0.75,dx/length*0.75
		DrawImageQuad(nil,x1+ox,y1+oy,x2+ox,y2+oy,x2-ox,y2-oy,x1-ox,y1-oy)
	end
	local plots={
		{label="Resources",series={{"Life",{0.3,1,0.4}},{"EnergyShield",{0.3,0.9,1}},{"Mana",{0.5,0.6,1}}}},
		{label="Defenses",series={{"crab",{1,0.75,0.25}},{"shrouds",{0.8,0.5,1}},{"chargesTotal",{0.9,0.9,0.9}}}},
		{label="Poison DPS",series={{"poison",{1,0.4,0.6}}}},
	}
	local labels={Life="Life",EnergyShield="ES",Mana="Mana",crab="Crab",shrouds="Shrouds",chargesTotal="Charges",poison="Poison DPS"}
	local cursorX,cursorY=GetCursorPos()
	local hovered=cursorX >= plotX and cursorX <= plotX+plotWidth and cursorY >= y and cursorY <= y+step*3
	local hoverTime=(cursorX-plotX)/plotWidth*stop
	local nearest
	for _,point in ipairs(trace.points) do if not nearest or math.abs(point.time-hoverTime) < math.abs(nearest.time-hoverTime) then nearest=point end end
	-- Cache immutable trace summaries instead of scanning every series every frame.
	if self.timelineTrace~=trace then
		self.timelineTrace=trace;self.timelineCaps=copyTable(trace.caps);self.timelineMarkers={}
		for _,point in ipairs(trace.points) do for _,key in ipairs({"Life","EnergyShield","Mana","crab","shrouds","chargesTotal","poison"}) do self.timelineCaps[key]=m_max(self.timelineCaps[key] or 0,point[key] or 0) end end
		for _,row in ipairs(trace.rows or {}) do if row.event~="Sample" and row.event~="Start" then self.timelineMarkers[#self.timelineMarkers+1]=row end end
	end
	for index,plot in ipairs(plots) do
		local top=y+(index-1)*step+22
		SetDrawColor(0.12,0.12,0.15); DrawImage(nil,plotX,top,plotWidth,plotHeight)
		SetDrawColor(0.45,0.45,0.5); line(plotX,top+plotHeight,plotX+plotWidth,top+plotHeight)
		DrawString(x+2,top,"LEFT",12,"VAR","100%")
		DrawString(x+20,top+plotHeight-14,"LEFT",12,"VAR","0")
		SetDrawColor(1,1,1); DrawString(x+4,top-20,"LEFT",14,"VAR",plot.label.." (normalized)")
		if plot.label == "Poison DPS" and (trace.caps.poison or 0) == 0 then DrawString(x+240,top-20,"LEFT",12,"VAR","No poison applied in this trial") end
		local legendX=x+240
		for _,series in ipairs(plot.series) do
			local key,color=series[1],series[2]
			local cap=self.timelineCaps[key] or 0
			if cap > 0 then
				SetDrawColor(unpack(color))
				local text=labels[key]..": "..s_format("%.0f",cap)
				DrawString(legendX,top-20,"LEFT",12,"VAR",text)
				legendX=legendX+DrawStringWidth(12,"VAR",text)+14
				local previous
				for _,p in ipairs(trace.points) do
					local px,py=plotX+p.time/stop*plotWidth,top+plotHeight-m_min(1,m_max(0,(p[key] or 0)/cap))*plotHeight
					if previous then line(previous[1],previous[2],px,py) end
					previous={px,py}
				end
			end
		end
		if hovered and nearest then SetDrawColor(0.7,0.7,0.7); local px=plotX+nearest.time/stop*plotWidth; line(px,top,px,top+plotHeight) end
		if index==1 then
			local last=-10
			for _,row in ipairs(self.timelineMarkers) do local px=plotX+row.time/stop*plotWidth
				if px-last>=3 then SetDrawColor(row.event=="Death" and "^xEF8D8D" or "^xCBB37D");line(px,top+plotHeight-4,px,top+plotHeight);last=px end
			end
		end
	end
	SetDrawColor(1,1,1)
	DrawString(plotX,y+step*3-14,"LEFT",12,"VAR","0s")
	for fraction=1,3 do
		local label=s_format("%.1fs",stop*fraction/4)
		DrawString(plotX+plotWidth*fraction/4-DrawStringWidth(12,"VAR",label)/2,y+step*3-14,"LEFT",12,"VAR",label)
	end
	DrawString(plotX+plotWidth,y+step*3-14,"RIGHT_X",12,"VAR",s_format("%.2fs",stop))
	if hovered and nearest then
		DrawString(x+4,y+step*3+4,"LEFT",12,"VAR",s_format("%.3fs: Life %.0f | ES %.0f | Mana %.0f | Crab %d | Shrouds %d",nearest.time,nearest.Life,nearest.EnergyShield,nearest.Mana,nearest.crab,nearest.shrouds))
		local event;for _,row in ipairs(self.timelineMarkers) do if not event or math.abs(row.time-hoverTime)<math.abs(event.time-hoverTime) then event=row end end
		local label=s_format("Flask charges: %s | Poison DPS: %.0f",nearest.charges,nearest.poison)..(event and s_format(" | %.3fs: %s",event.time,event.event) or "")
		while #label>4 and DrawStringWidth(12,"VAR",label)>width-8 do label=label:sub(1,-5).."..." end
		DrawString(x+4,y+step*3+20,"LEFT",12,"VAR",label)
	else DrawString(x+4,y+step*3+8,"LEFT",12,"VAR","Hover for samples and nearby events. Ticks mark events; legends show each series' reference maximum.") end
end

function CalcBreakdownClass:Draw(viewPort)
	local sourceData = self.sourceData
	local scrollBar = self.controls.scrollBar
	local width = self.contentWidth
	local height = self.contentHeight
	local borderThickness = self.borderThickness
	if self.contentHeight > viewPort.height then
		-- Content won't fit the screen height, so set the scrollbar
		width = self.contentWidth + scrollBar.width
		height = viewPort.height
		scrollBar.height = height - borderThickness * 2
		scrollBar:SetContentDimension(self.contentHeight - borderThickness * 2, viewPort.height - borderThickness * 2)
	else
		scrollBar:SetContentDimension(0, 0)
	end
	self.width = width
	self.height = height
	-- Calculate position based on the source cell
	local x = m_max(viewPort.x, sourceData.x + sourceData.width + 5)
	local y = m_max(viewPort.y, m_min(sourceData.y, viewPort.y + viewPort.height - height))
	if x + width > viewPort.x + viewPort.width then
		x = m_max(viewPort.x, sourceData.x - 5 - width)
	end
	self.x = x
	self.y = y
	-- Draw background
	SetDrawLayer(nil, 10)
	SetDrawColor(0, 0, 0, self.isTimeline and 1 or 0.9)
	DrawImage(nil, x + borderThickness, y + borderThickness, width - borderThickness * 2, height - borderThickness * 2)
	-- Draw border (this is put in sub layer 11 so it draws over the contents, in case they don't fit the screen)
	SetDrawLayer(nil, 11)
	if self.pinned then
		SetDrawColor(unpack(self.pinnedColour))
	else
		SetDrawColor(unpack(self.borderColour))
	end
	DrawImage(nil, x, y, width, borderThickness)
	DrawImage(nil, x, y + height - borderThickness, width, borderThickness)
	DrawImage(nil, x, y, borderThickness, height)
	DrawImage(nil, x + width - borderThickness, y, borderThickness, height)
	SetDrawLayer(nil, 10)
	self:DrawControls(viewPort)
	-- Hovered controls can reset the draw layer while drawing their tooltip.
	-- Restore it so the opaque panel never covers its own charts and event log.
	SetDrawLayer(nil,10)
	-- Draw the sections
	y = y - scrollBar.offset
	for i, section in ipairs(self.sectionList) do
		local sectionY = y + section.offset
		if section.type == "TEXT" then
			local lineY = sectionY + 2
			for i, line in ipairs(section.lines) do
				SetDrawColor(1, 1, 1)
				local _, dec = string.gsub(line, "%.%d%d.", " ") -- counts decimals with 2 or more digits
				DrawString(x + 4, lineY, "LEFT", section.textSize, "VAR", formatNumSep(line))
				lineY = lineY + section.textSize
			end
		elseif section.type == "TABLE" then
			self:DrawBreakdownTable(viewPort, x, sectionY, section)
		elseif section.type == "RADIUS" then
			SetDrawColor(1, 1, 1)
			DrawImage(nil, x + 2, sectionY, section.width - 4, section.height)
			self:DrawRadiusVisual(x + 4, sectionY + 2, section.width - 8, section.height - 4, section.radius)
		elseif section.type == "TIMELINE" then
			self:DrawEncounterTimeline(x+2,sectionY,section)
		end
	end
	if self.isTimeline then
		SetDrawLayer(nil,11)
		SetDrawColor(0.08,0.08,0.1); DrawImage(nil,self.x+2,self.y+2,width-4,24)
		SetDrawColor(1,1,1); DrawString(self.x+8,self.y+5,"LEFT",16,"VAR","Encounter timeline")
		self.controls.timelineClose:Draw(viewPort)
		SetDrawLayer(nil,11)
		self.controls.timelineSamples:Draw(viewPort)
	end
	SetDrawLayer(nil, 0)
end

function CalcBreakdownClass:OnKeyDown(key, doubleClick)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	local mOverControl = self:GetMouseOverControl()
	if mOverControl and mOverControl.OnKeyDown then
		return mOverControl:OnKeyDown(key)
	end
	local mOver = self:IsMouseOver()
	if key:match("BUTTON") then
		if not mOver then
			-- Mouse click outside the control, hide the breakdown
			if self.clearDisplayFunc then
				self.clearDisplayFunc()
			else
				self.calcsTab:ClearDisplayStat()
			end
			self.shown = false
			return
		end
	end
	return self
end

function CalcBreakdownClass:OnKeyUp(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if self.controls.scrollBar:IsScrollDownKey(key) then
		self.controls.scrollBar:Scroll(1)
	elseif self.controls.scrollBar:IsScrollUpKey(key) then
		self.controls.scrollBar:Scroll(-1)
	end
	return self
end
