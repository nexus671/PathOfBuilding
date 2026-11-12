-- Path of Building
--
-- Class: Text List
-- Simple list control for displaying a block of text
--
---@class TextListControl: Control, ControlHost
local TextListClass = newClass("TextListControl", "Control", "ControlHost")

function TextListClass:TextListControl(anchor, rect, columns, list, sectionHeights)
	self:Control(anchor, rect)
	self:ControlHost()
	self.controls.scrollBar = new("ScrollBarControl"):ScrollBarControl({"RIGHT",self,"RIGHT"}, {-1, 0, 18, 0}, 40)
	self.controls.scrollBar.height = function()
		local width, height = self:GetSize()
		return height - 2
	end
	self.columns = columns or { { x = 0, align = "LEFT" } }
	self.list = list or { }
	self.sectionHeights = sectionHeights
	return self
end

function TextListClass:IsMouseOver()
	if not self:IsShown() then
		return
	end
	return self:IsMouseInBounds() or self:GetMouseOverControl()
end

function TextListClass:Draw(viewPort)
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local scrollBar = self.controls.scrollBar
	local contentHeight = 0
	for _, lineInfo in pairs(self.list) do
		contentHeight = contentHeight + lineInfo.height
	end
	scrollBar:SetContentDimension(contentHeight, height - 4)
	if self.borderColor then SetDrawColor(self.borderColor) else SetDrawColor(0.66, 0.66, 0.66) end
	DrawImage(nil, x, y, width, height)
	if self.backgroundColor then SetDrawColor(self.backgroundColor) else SetDrawColor(0.05, 0.05, 0.05) end
	DrawImage(nil, x + 1, y + 1, width - 2, height - 2)
	self:DrawControls(viewPort)
	SetViewport(x + 2, y + 2, width - 20, height - 4)
	for colIndex, colInfo in pairs(self.columns) do
		local lineY = -scrollBar.offset
		for _, lineInfo in ipairs(self.list) do
			if lineInfo[colIndex] and lineY+lineInfo.height>=0 and lineY<height-4 then
				if colIndex==1 and lineInfo.card then SetDrawColor("^x344253");DrawImage(nil,2,lineY+2,width-24,lineInfo.height-8);SetDrawColor("^x151E29");DrawImage(nil,3,lineY+3,width-26,lineInfo.height-10) end
				if colIndex==1 and lineInfo.selected then SetDrawColor("^x30445B");DrawImage(nil,0,lineY,width-20,lineInfo.height) end
				if colIndex==1 and lineInfo.iconPath then
					self.rowIcons=self.rowIcons or {};local icon=self.rowIcons[lineInfo.iconPath]
					if not icon then icon=NewImageHandle();icon:Load(lineInfo.iconPath);self.rowIcons[lineInfo.iconPath]=icon end
					SetDrawColor(1,1,1);DrawImage(icon,4,lineY+3,26,26)
				end
				local textX = lineInfo.x or colInfo.x
				local align = lineInfo.align or colInfo.align
				DrawString(textX, lineY, align, lineInfo.textSize or lineInfo.height, lineInfo.font or "VAR", lineInfo[colIndex])
				if colIndex==1 and lineInfo.subtitle then SetDrawColor("^xA6B3C6");DrawString(textX,lineY+19,"LEFT",13,"VAR",lineInfo.subtitle) end
				if colIndex==1 and lineInfo.detail then SetDrawColor("^xD5DEE8");DrawString(textX,lineY+44,"LEFT",14,"VAR",lineInfo.detail) end
				if lineInfo.underline and lineInfo.underline[colIndex] then
					local width = DrawStringWidth(lineInfo.textSize or lineInfo.height, "VAR", StripEscapes(lineInfo[colIndex]))
					-- note: not fully handled. this is currently only used for
					-- the side bar stats
					if align == "RIGHT_X" then
						textX = textX - width
					end
					SetDrawColor(0.5, 0.5, 0.5)
					DrawImage(nil, textX, lineY + lineInfo.height, width, 1)
				end
			end
			lineY = lineY + lineInfo.height
		end
	end
	-- determine which line the user is hovering over
	self.hoveredLine = nil
	local cursorX, cursorY = GetCursorPos()
	if cursorX >= x + 2 and cursorX < x + width - 18 and cursorY >= y + 2 and cursorY < y + height - 2 then
		local rowY = y - scrollBar.offset + 2
		-- suboptimal. should do binary search if this causes performance problems
		for _, lineInfo in ipairs(self.list) do
			if cursorY >= rowY and cursorY < rowY + lineInfo.height then
				self.hoveredLine = { line = lineInfo, x = x, y = rowY, width = width }
				break
			end
			rowY = rowY + lineInfo.height
		end
	end
	SetViewport()
end

function TextListClass:OnKeyDown(key, doubleClick)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	if self.planningFocusable and key:match("BUTTON") and not self:IsMouseOver() then return end
	if key == "LEFTBUTTON" and self.onClick then
		self.onClick(self.hoveredLine)
	end
	local mOverControl = self:GetMouseOverControl()
	if mOverControl and mOverControl.OnKeyDown then
		return mOverControl:OnKeyDown(key)
	end
	if key=="LEFTBUTTON" and self.planningFocusable then return self end
end

function TextListClass:OnKeyUp(key)
	if not self:IsShown() or not self:IsEnabled() then
		return
	end
	local scrollBar = self.controls.scrollBar
	if IsKeyDown("SHIFT") and self.sectionHeights then
		for i, height in ipairs(self.sectionHeights) do
			if height >= scrollBar.offset then
				if key == "WHEELDOWN" then
					scrollBar:SetOffset((i==#self.sectionHeights and self.sectionHeights[i] or self.sectionHeights[i + 1]))
					return self
				elseif key == "WHEELUP" then
					scrollBar:SetOffset(i==1 and self.sectionHeights[i] or self.sectionHeights[i - 1])
					return self
				end
			end
		end
		scrollBar.offset = scrollBar.offsetMax
		return self
	end
	if key == "WHEELDOWN" then
		scrollBar:Scroll(1)
		return self
	elseif key == "WHEELUP" then
		scrollBar:Scroll(-1)
		return self
	end
	if self.planningFocusable then return self end
end
