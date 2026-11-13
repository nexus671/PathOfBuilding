-- cspell:ignore eimport jsontype
-- Build-owned crafting plans. External simulator exports are data, never code.
local json = require("dkjson")
local M = { }
M.home = "https://beta.craftofexile.com/?game=poe1"
M.developers = "https://beta.craftofexile.com/developers?game=poe1"

local function text(value,limit,label,optional)
	if value == nil and optional then return nil end
	assert(type(value) == "string" and #value <= limit and (optional or value:match("%S")),"Invalid "..label)
	return value
end
local function number(value,low,high,label)
	assert(type(value) == "number" and value == value and value >= low and value <= high,"Invalid "..label)
	return value
end
function M.item(raw)
	local item = new("Item"):Item(text(raw,24000,"item text"))
	assert(item.base and item.baseName,"Item text needs a recognized base")
	return item
end

function M.validate(project)
	assert(type(project) == "table","Invalid crafting project")
	local result = {id=text(project.id,64,"project ID"),title=text(project.title,120,"project title"),slot=text(project.slot,80,"slot"),
		startingItem=text(project.startingItem,24000,"starting item"),targetItem=text(project.targetItem,24000,"target item",true),
		notes=text(project.notes,8000,"project notes",true),simulatorExport=text(project.simulatorExport,128000,"simulator export",true),goals={},steps={}}
	assert(result.id:match("^[%w%-_]+$"),"Project ID must use letters, numbers, underscores or hyphens")
	assert(type(project.goals) == "table" and #project.goals <= 12,"Use up to twelve target modifiers")
	for _,goal in ipairs(project.goals) do result.goals[#result.goals+1]=text(goal,300,"target modifier") end
	assert(type(project.steps) == "table" and #project.steps <= 40,"Use up to forty crafting steps")
	for _,step in ipairs(project.steps) do
		assert(type(step) == "table","Invalid crafting step")
		result.steps[#result.steps+1] = {action=text(step.action,1000,"step action"),stopWhen=text(step.stopWhen,500,"stop condition",true),onFailure=text(step.onFailure,500,"failure route",true),done=step.done == true}
	end
	if project.priceBook then
		local prices=require("Modules.CraftingPrices")
		result.priceBook=prices.validate(project.priceBook)
		-- Reject conflicting aliases before saving, preserving the supplied keys.
		prices.normalized(result.priceBook,{item=M.item(result.startingItem)})
	end
	if project.nativeRecipe then result.nativeRecipe=require("Modules.CraftingSimulator").validateRecipe(project.nativeRecipe) end
	if project.preferredMethod then
		local valid=false;for _,method in ipairs(require("Modules.CraftingSimulator").methods) do if project.preferredMethod==method then valid=true end end
		assert(valid,"Unknown starting currency");result.preferredMethod=project.preferredMethod
	end
	if project.run then result.run=require("Modules.CraftingCheckpoint").validate(result.startingItem,project.run) end
	if project.inventory~=nil then result.inventory=require("Modules.CraftingInventory").validate(project.inventory) end
	if project.estimate then
		local quote = project.estimate
		result.estimate = {amount=number(quote.amount,0,1e12,"estimated cost"),currency=text(quote.currency,24,"currency"),source=text(quote.source,240,"price source"),quotedAt=number(quote.quotedAt,0,4102444800,"quote time")}
	end
	if project.simulation then
		local sim = project.simulation
		assert(type(sim.trials) == "number" and sim.trials == math.floor(sim.trials) and type(sim.successes) == "number" and sim.successes == math.floor(sim.successes),"Simulation counts must be integers")
		result.simulation = {source="Craft of Exile (supplied result)",patch=text(sim.patch,40,"simulation patch"),observedAt=number(sim.observedAt,0,4102444800,"simulation time"),
			trials=number(sim.trials,1,1e9,"simulation trials"),successes=number(sim.successes,0,sim.trials,"simulation successes"),notes=text(sim.notes,4000,"simulation notes",true)}
	end
	return result
end

-- Preserve JSON dictionary shape after the generic native table copy.
function M.copy(projects)
	local result=copyTable(projects)
	for _,project in ipairs(result) do
		if project.priceBook then project.priceBook=require("Modules.CraftingPrices").validate(project.priceBook) end
	end
	return result
end

function M.new(build)
	local self = {projects={},build=build}
	function self:Load(xml)
		local raw = table.concat(xml)
		if raw:match("^%s*$") then return end
		local ok,projects = pcall(function()
			assert(#raw <= 2*1024*1024,"Crafting projects exceed size limit")
			local decoded = assert(json.decode(raw,1,json.null),"Invalid crafting project data")
			assert(decoded.schemaVersion == 1 and type(decoded.projects) == "table" and decoded.projects ~= json.null,"Unsupported crafting project data")
			local meta=getmetatable(decoded.projects)
			assert(not meta or meta.__jsontype ~= "object","Crafting projects must be an array")
			for key in pairs(decoded.projects) do assert(type(key)=="number" and key==math.floor(key) and key>=1 and key<=#decoded.projects,"Crafting projects must be an array") end
			local result,ids = {},{}
			for _,project in ipairs(decoded.projects) do local entry=M.validate(project); assert(not ids[entry.id],"Duplicate crafting project ID"); ids[entry.id]=true; result[#result+1]=entry end
			return result
		end)
		if ok then self.projects=projects else self.unreadable=raw; self.warning="Crafting metadata could not be read. It is preserved unchanged when saving." end
	end
	function self:Save(xml)
		if self.unreadable then xml[#xml+1]=self.unreadable
		elseif #self.projects > 0 then xml[#xml+1]=json.encode({schemaVersion=1,projects=self.projects}) end
	end
	function self:Upsert(project)
		assert(not self.unreadable,self.warning)
		local entry=M.validate(project)
		assert(build.itemsTab.slots[entry.slot],"Unknown project equipment slot")
		local start=M.item(entry.startingItem)
		assert(build.itemsTab:IsItemValidForSlot(start,entry.slot),"Starting item cannot use this slot")
		for _,item in ipairs(entry.inventory or {}) do
			assert(build.itemsTab.slots[item.slot] and build.itemsTab:IsItemValidForSlot(M.item(item.state.baseItem or item.baseItem),item.slot),"Inventory item cannot use its equipment slot")
		end
		if entry.targetItem and entry.targetItem ~= "" then
			local target=M.item(entry.targetItem)
			assert(target.type == start.type and build.itemsTab:IsItemValidForSlot(target,entry.slot),"Crafting target must use the same item class and equipment slot")
		end
		local replacement=M.copy(self.projects)
		local found=false
		for index,existing in ipairs(replacement) do if existing.id == entry.id then
			if not entry.run and existing.run and entry.startingItem==existing.startingItem then entry.run=copyTable(existing.run) end
			if project.inventory==nil and existing.inventory then entry.inventory=copyTable(existing.inventory) end
			replacement[index]=entry; found=true; break
		end end
		if not found then replacement[#replacement+1]=entry end
		assert(#json.encode({schemaVersion=1,projects=replacement}) <= 2*1024*1024,"Crafting projects exceed the supported size")
		self.projects=replacement; build.modFlag=true
		require("Modules.PlanningUI").kept(build,"crafting")
		return entry
	end
	return self
end

function M.handoff(raw)
	local item = M.item(raw)
	local warnings,lines = {},{}
	local advanced = raw:match("Item Class:") and raw:match("{[^\n]*Modifier")
	if advanced then
		return {url=M.home.."&eimport="..urlEncode(raw:gsub("\r\n","\n"):gsub("\n","\r\n")),mode="advanced-item",itemText=raw,
			warnings={"Check the imported base, modifiers, item level, influences and patch in Craft of Exile before simulating."}}
	end
	-- CoE requires game-format headers. Never imply a lossy modifier transfer was exact.
	local rarity = item.rarity:lower():gsub("^%l",string.upper)
	lines={"Rarity: "..rarity,item.title or item.baseName}
	if item.title then lines[#lines+1]=item.baseName end
	lines[#lines+1]="--------"
	lines[#lines+1]="Item Level: "..tostring(item.itemLevel or 1)
	lines[#lines+1]="--------"
	for _,info in ipairs(itemLib.influenceInfo.all) do if item[info.key] then lines[#lines+1]=info.display.." Item" end end
	warnings[#warnings+1]="Base-only handoff: existing modifiers, quality and special states are not transferred. Paste an advanced in-game copy in Craft of Exile to transfer the full item."
	if not item.itemLevel then warnings[#warnings+1]="Item level is unknown; the handoff uses level 1. Set the actual item level in Craft of Exile." end
	local paste = table.concat(lines,"\r\n")
	return {url=M.home.."&eimport="..urlEncode(paste),mode="base-only",itemText=paste,warnings=warnings}
end

function M.inspect(raw,query,limit)
	local item=M.item(raw)
	query=(query or ""):lower(); limit=math.min(limit or 30,100)
	local matches,total = {},0
	for id,mod in pairsSortByKey(item.affixes or { }) do
		local lines=table.concat(mod," / ")
		if (id.." "..lines):lower():find(query,1,true) and (not item.itemLevel or (mod.level or 0) <= item.itemLevel) and item:CanHaveMod(mod) then
			total=total+1
			if #matches < limit then matches[#matches+1] = {id=id,text=lines,type=mod.type,level=mod.level,group=mod.group,tags=mod.modTags,spawnWeight=item:GetModSpawnWeight(mod)} end
		end
	end
	return {base=item.baseName,itemLevel=item.itemLevel,rarity=item.rarity,total=total,matches=matches,handoff=M.handoff(raw),
		limitations={"This is PoB's item-editor affix pool, not Craft of Exile's probability engine.","Spawn weights are not success probabilities. Method-specific pools, existing group blocking, fractures, crafted modifiers and special rules require simulator validation.","If item level is unknown, listed modifier levels are not filtered. Unique off-base pools may not have a meaningful spawn weight."}}
end

function M.lines(project)
	local lines={project.title.." | "..project.slot,"Starting item: "..M.item(project.startingItem).baseName,"Target modifiers"}
	for _,goal in ipairs(project.goals) do lines[#lines+1]="- "..goal end
	lines[#lines+1]="Crafting plan (proposed steps; validate the method and costs)"
	for index,step in ipairs(project.steps) do
		lines[#lines+1]=string.format("%d. [%s] %s",index,step.done and "done" or "todo",step.action)
		if step.stopWhen and step.stopWhen ~= "" then lines[#lines+1]="   Stop when: "..step.stopWhen end
		if step.onFailure and step.onFailure ~= "" then lines[#lines+1]="   On failure: "..step.onFailure end
	end
	if project.priceBook then
		local quote=project.priceBook;local count=0;for _ in pairs(quote.values) do count=count+1 end
		lines[#lines+1]=string.format("Resource quotes: %d in %s | %s | %s",count,quote.currency,quote.source,os.date("%Y-%m-%d",quote.quotedAt))
	end
	if project.estimate then local q=project.estimate; lines[#lines+1]=string.format("Estimated total: %.2f %s | %s | quote age %.0fh",q.amount,q.currency,q.source,math.max(0,os.time()-q.quotedAt)/3600) end
	if project.simulation then local s=project.simulation; lines[#lines+1]=string.format("Supplied CoE result: %.0f / %.0f successes | patch %s | observed %.0fh ago",s.successes,s.trials,s.patch,math.max(0,os.time()-s.observedAt)/3600); lines[#lines+1]="External result recorded as supplied; PoB has not rerun or verified this simulation." end
	if project.simulatorExport and project.simulatorExport ~= "" then lines[#lines+1]="Simulator export attached for manual import into Craft of Exile; never executed by PoB." end
	if project.nativeRecipe then
		lines[#lines+1]="Native recipe: "..#project.nativeRecipe.steps.." steps. Open Native crafting to simulate it."
		for index,step in ipairs(project.nativeRecipe.steps) do
			lines[#lines+1]=string.format("%d. %s%s | attempts %d | success -> %d | failure -> %d",index,step.method,step.modId and " ("..step.modId..")" or step.essenceId and " ("..step.essenceId..")" or "",step.maxAttempts or 1,step.onSuccess or index+1,step.onFailure or index+1)
		end
	end
	if project.notes and project.notes ~= "" then lines[#lines+1]=project.notes end
	return lines
end

return M
