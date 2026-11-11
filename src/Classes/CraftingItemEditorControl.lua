-- A staged hypothetical starting item; edits never equip gear or spend currency.
local sim=require("Modules.CraftingSimulator")
local Panel={}
function Panel.Open(model,input,onKeep)
	assert(not input.destroyed and not input.veil,"Reset destruction or finish the unveil before editing")
	model=sim.context(model,input)
	local state=copyTable(input);local controls={}
	local function button(key,x,y,w,text,callback)
		controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},text,function()
			local ok,message=pcall(callback);if not ok then main:OpenMessagePopup("Edit hypothetical item",tostring(message):match("^[^\n]+")) end
		end)
	end
	local function edit(key,x,y,w,value,prompt)
		controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},tostring(value or ""),prompt,nil,12)
	end
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Manual edits establish a new recipe start. Cancel discards all edits.")
	controls.current=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,62,744,24},{})
	local candidates={};local seen={}
	local function add(id)
		if not seen[id] then
			local mod=assert(model.byId[id]);candidates[#candidates+1]={label=mod.type.." | "..table.concat(mod," / "),val=id};seen[id]=true
		end
	end
	for _,entry in ipairs(model.mods) do add(entry.id) end
	for _,entry in ipairs(model.bench) do add(entry.id) end
	for _,entry in ipairs(model.essences) do add(entry.modId) end
	for _,entry in ipairs(state.affixes) do add(entry.id) end
	table.sort(candidates,function(a,b) return a.label < b.label end)
	controls.modifier=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,108,744,24},candidates)
	edit("roll",16,154,180,50,"Roll % (0-100)")
	controls.fractured=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{212,154,220,24},{"Not fractured","Fractured"})
	local function refresh()
		local list={}
		for i,entry in ipairs(state.affixes) do list[#list+1]={label=i.." | "..(entry.fractured and "Fractured | " or "")..table.concat(model.byId[entry.id]," / "),val=i} end
		if #list == 0 then list={{label="No explicit modifiers",val=0}} end
		controls.current:SetList(list)
	end
	local function selected()
		local id=assert(controls.modifier:GetSelValueByKey("val"),"Select a modifier")
		local roll=assert(tonumber(controls.roll.buf),"Enter a roll percentage")
		assert(roll >= 0 and roll <= 100,"Use a roll from zero to 100 percent")
		return {id=id,range=roll/100,crafted=id:match("^bench:") ~= nil,fractured=controls.fractured:GetSelValue() == "Fractured"}
	end
	local function commit(candidate) state=sim.validateState(model,candidate);refresh() end
	button("add",16,202,180,"Add modifier",function() local candidate=copyTable(state);candidate.affixes[#candidate.affixes+1]=selected();commit(candidate) end)
	button("replace",212,202,180,"Replace selected",function()
		local index=controls.current:GetSelValueByKey("val");assert(state.affixes[index],"Choose an existing modifier")
		local candidate=copyTable(state);candidate.affixes[index]=selected();commit(candidate)
	end)
	button("remove",408,202,180,"Remove selected",function()
		local index=controls.current:GetSelValueByKey("val");assert(state.affixes[index],"Choose an existing modifier")
		local candidate=copyTable(state);table.remove(candidate.affixes,index);commit(candidate)
	end)
	controls.current.selFunc=function()
		local entry=state.affixes[controls.current:GetSelValueByKey("val")];if not entry then return end
		controls.modifier:SelByValue(entry.id,"val")
		local range=type(entry.range) == "table" and math.min(unpack(entry.range)) or entry.range or 0.5
		controls.roll:SetText(tostring(range*100));controls.fractured:SelByValue(entry.fractured and "Fractured" or "Not fractured")
	end
	for _,entry in ipairs({{"rarityLabel",16,"Rarity"},{"qualityLabel",212,"Quality %"},{"intangibilityLabel",408,"Intangibility %"},{"memoryLabel",584,"Memory strands"}}) do
		controls[entry[1]]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{entry[2],240,0,14},entry[3])
	end
	controls.rarity=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,260,180,24},{"NORMAL","MAGIC","RARE"})
	controls.rarity:SelByValue(state.rarity)
	edit("quality",212,260,180,state.quality or model.item.quality or 0,nil)
	edit("intangibility",408,260,160,state.intangibility or 0,nil)
	edit("memoryStrands",584,260,176,state.memoryStrands or 0,nil)
	controls.corrupted=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,308,376,24},{"Uncorrupted","Corrupted"})
	controls.corrupted:SelByValue(state.corrupted and "Corrupted" or "Uncorrupted")
	local function applyProperties()
		local candidate=copyTable(state);candidate.rarity=controls.rarity:GetSelValue();candidate.corrupted=controls.corrupted:GetSelValue() == "Corrupted"
		for _,key in ipairs({"quality","intangibility","memoryStrands"}) do candidate[key]=assert(tonumber(controls[key].buf),"Invalid "..key) end
		commit(candidate)
	end
	button("properties",408,308,352,"Apply properties to draft",applyProperties)
	button("keep",16,368,260,"Use as recipe starting item",function() applyProperties();onKeep(sim.validateState(model,state));main:ClosePopup() end)
	button("close",644,368,116,"Cancel",function() main:ClosePopup() end)
	refresh();main:OpenPopup(776,416,"Edit hypothetical item",controls,nil,nil,"close")
	return controls
end
return Panel
