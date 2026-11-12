-- Portable item snapshots. A saved item is a state, not a lossy item-text export.
-- cspell:ignore jsontype
local M={}
function M.run(state)
	return {schemaVersion=1,state=copyTable(state),initial=copyTable(state),history={},actions={},configured={},sequence=0,targets={},requirements={minAffixes=0}}
end
function M.validate(entries)
	assert(type(entries)=="table" and entries~=require("dkjson").null,"Item inventory must be an array")
	local meta=getmetatable(entries);assert(not meta or meta.__jsontype~="object","Item inventory must be an array")
	local result,ids,models={},{},{}
	for key in pairs(entries) do assert(type(key)=="number" and key==math.floor(key) and key>=1 and key<=#entries,"Item inventory must be an array") end
	for _,entry in ipairs(entries) do
		assert(type(entry)=="table","Invalid inventory item")
		for key,limit in pairs({id=64,title=120,slot=80,baseItem=24000}) do assert(type(entry[key])=="string" and #entry[key]<=limit and entry[key]:match("%S"),"Invalid inventory "..key) end
		assert(entry.id:match("^[%w_-]+$") and not ids[entry.id],"Invalid or duplicate inventory ID");ids[entry.id]=true
		assert(type(entry.at)=="number" and entry.at>=0 and entry.at<=4102444800 and entry.at==math.floor(entry.at),"Invalid inventory time")
		local run=require("Modules.CraftingCheckpoint").validate(entry.baseItem,M.run(entry.state),models)
		result[#result+1]={id=entry.id,title=entry.title,slot=entry.slot,baseItem=entry.baseItem,at=entry.at,state=run.state}
	end
	return result
end
function M.capture(project,state,title)
	return M.validate({{id="item-"..require("sha1")(tostring({})..os.time()):sub(1,20),title=title or project.title,slot=project.slot,baseItem=project.startingItem,at=os.time(),state=state}})[1]
end
function M.project(entry)
	entry=M.validate({entry})[1]
	return {id="craft-"..require("sha1")(tostring({})..os.time()):sub(1,20),title=entry.title,slot=entry.slot,startingItem=entry.baseItem,goals={},steps={},run=M.run(entry.state)}
end
function M.entries(projects,query)
	local result={};query=(query or ""):lower()
	for _,project in ipairs(projects) do for _,entry in ipairs(project.inventory or {}) do
		if (entry.title.." "..entry.slot.." "..project.title.." "..entry.baseItem):lower():find(query,1,true) then result[#result+1]={project=project,item=entry} end
	end end
	table.sort(result,function(a,b) if a.item.at~=b.item.at then return a.item.at>b.item.at end;return a.project.id..a.item.id<b.project.id..b.item.id end)
	return result
end
return M
