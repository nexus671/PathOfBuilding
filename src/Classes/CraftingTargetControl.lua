-- cspell:ignore RRBG
local sim=require("Modules.CraftingSimulator")
local Panel={}
function Panel.Open(targets,requirements,requiredGroups,onKeep,groupIndex)
	local groups=copyTable(targets);local conditions=copyTable(requirements or {});local controls={}
	local function edit(key,x,y,value,prompt)
		controls[key.."Label"]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},prompt)
		controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y+16,180,24},tostring(value or ""),nil,nil,8)
	end
	local function button(key,x,y,w,text,callback)
		controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},text,function()
			local ok,message=pcall(callback);if not ok then main:OpenMessagePopup("Crafting targets",require("Modules.PlanningUI").errorText(message)) end
		end)
	end
	groupIndex=groupIndex or #groups
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Edit group "..groupIndex..". Blank item-property fields impose no condition.")
	local group=groups[groupIndex]
	if not group then controls.info.label="Set item properties. Blank fields impose no condition." end
	edit("count",16,64,group and group.atLeast or 1,"Matching mods in group")
	edit("roll",212,64,group and group.minRoll and group.minRoll*100 or nil,"Minimum roll % (0-100)")
	controls.mode=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{408,80,200,24},{"Require group","Exclude group"})
	controls.mode:SelByValue(group and group.negate and "Exclude group" or "Require group")
	controls.scope=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,124,376,24},{"Explicit modifiers","Implicit modifiers"})
	controls.scope:SelByValue(group and group.scope == "implicit" and "Implicit modifiers" or "Explicit modifiers")
	edit("groups",408,108,requiredGroups,"Required groups (blank=all)")
	for i,key in ipairs({"fractured","crafted"}) do
		local title=key == "fractured" and "Fractured" or "Crafted"
		controls[key]=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16+(i-1)*294,164,278,24},{"Any "..key.." state",title.." only","Not "..key})
		controls[key]:SelByValue(group and group[key] == true and title.." only" or group and group[key] == false and "Not "..key or "Any "..key.." state")
	end
	local properties={{"openPrefixes","Open prefixes"},{"openSuffixes","Open suffixes"},{"minAffixes","Minimum affixes"},{"maxAffixes","Maximum affixes"},{"minQuality","Minimum quality"},{"sockets","Minimum sockets"},{"links","Minimum linked sockets"},{"minMemoryStrands","Minimum memory strands"},{"maxMemoryStrands","Maximum memory strands"},{"minFractured","Minimum fractured mods"},{"maxFractured","Maximum fractured mods"},{"minIntangibility","Minimum Intangibility"},{"maxIntangibility","Maximum Intangibility"}}
	for i,entry in ipairs(properties) do edit(entry[1],16+(i-1)%3*196,214+math.floor((i-1)/3)*48,conditions[entry[1]],entry[2]) end
	edit("socketColours",212,406,conditions.socketColours,"Socket colours (e.g. RRBG)")
	controls.linkedColours=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{408,422,180,24},{"Anywhere on item","In one linked group"})
	controls.linkedColours:SelByValue(conditions.linkedColours and "In one linked group" or "Anywhere on item")
	controls.corrupted=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,462,572,24},{"Any corruption state","Must be corrupted","Must be uncorrupted"})
	controls.corrupted:SelByValue(conditions.corrupted == true and "Must be corrupted" or conditions.corrupted == false and "Must be uncorrupted" or "Any corruption state")
	local enchantments={{label="Any Harvest enchantment",val=false}}
	for id,craft in pairs(require("Modules.CraftingEnchants").data().crafts) do enchantments[#enchantments+1]={label=(id:find("Body",1,true) and "Body: " or "Weapon: ")..craft.lines[#craft.lines],val=id} end
	table.sort(enchantments,function(a,b) if not a.val then return not not b.val elseif not b.val then return false else return a.label<b.label end end)
	controls.harvestEnchant=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,502,572,24},enchantments)
	controls.harvestEnchant:SelByValue(conditions.harvestEnchant or false,"val")
	button("keep",16,552,220,"Keep target conditions",function()
		if group then
			group.atLeast=assert(tonumber(controls.count.buf),"Enter a matching-mod count")
			group.minRoll=controls.roll.buf ~= "" and assert(tonumber(controls.roll.buf),"Enter a minimum roll percent")/100 or nil
			group.negate=controls.mode:GetSelValue() == "Exclude group";group.scope=controls.scope:GetSelValue() == "Implicit modifiers" and "implicit" or "explicit"
			for _,key in ipairs({"fractured","crafted"}) do local value=controls[key]:GetSelValue();group[key]=nil;if not value:match("^Any ") then group[key]=not value:match("^Not ") end end
		end
		local result={nativeStats=conditions.nativeStats and copyTable(conditions.nativeStats)};for _,entry in ipairs(properties) do local value=controls[entry[1]].buf;if value ~= "" then result[entry[1]]=assert(tonumber(value),"Enter a number for "..entry[2]:lower()) end end
		local corruption=controls.corrupted:GetSelValue();if corruption ~= "Any corruption state" then result.corrupted=corruption == "Must be corrupted" end
		result.harvestEnchant=controls.harvestEnchant:GetSelValueByKey("val") or nil
		if controls.socketColours.buf~="" then result.socketColours=controls.socketColours.buf:upper();result.linkedColours=controls.linkedColours:GetSelValue()=="In one linked group" end
		local required=controls.groups.buf ~= "" and assert(tonumber(controls.groups.buf),"Invalid required group count") or nil
		if not next(result) then result=nil end
		sim.validateRecipe({steps={{method="chaos"}},targets=groups,requirements=result,requiredGroups=required})
		onKeep(groups,result,required);main:ClosePopup()
	end)
	button("close",492,552,116,"Close",function() main:ClosePopup() end)
	button("itemStats",250,552,224,"Weapon and defence goals",function()
		require("Classes.CraftingItemStatsControl").Open(conditions.nativeStats,function(value) conditions.nativeStats=value end)
	end)
	if not group then
		for _,key in ipairs({"count","countLabel","roll","rollLabel","mode","scope","groups","groupsLabel","fractured","crafted"}) do controls[key].enabled=false;controls[key].shown=false end
		for _,control in pairs(controls) do if type(control.y)=="number" and control.y>=214 then control.y=control.y-150 end end
		controls.keep.label="Keep item properties"
	end
	require("Modules.PlanningUI").style(controls,{keep=true})
	main:OpenPopup(624,group and 600 or 450,group and "Crafting target conditions" or "Item properties",controls,nil,nil,"close")
	return controls
end
return Panel
