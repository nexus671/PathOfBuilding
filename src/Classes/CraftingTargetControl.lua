local sim=require("Modules.CraftingSimulator")
local Panel={}
function Panel.Open(targets,requirements,requiredGroups,onKeep)
	local groups=copyTable(targets);local conditions=copyTable(requirements or {});local controls={}
	local function edit(key,x,y,value,prompt)
		controls[key.."Label"]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},prompt)
		controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y+16,180,24},tostring(value or ""),nil,nil,8)
	end
	local function button(key,x,y,w,text,callback)
		controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},text,function()
			local ok,message=pcall(callback);if not ok then main:OpenMessagePopup("Crafting targets",tostring(message):match("^[^\n]+")) end
		end)
	end
	controls.info=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,0,14},"Edit the last target group. Blank property fields impose no condition.")
	local group=groups[#groups]
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
	controls.corrupted=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,462,572,24},{"Any corruption state","Must be corrupted","Must be uncorrupted"})
	controls.corrupted:SelByValue(conditions.corrupted == true and "Must be corrupted" or conditions.corrupted == false and "Must be uncorrupted" or "Any corruption state")
	button("keep",16,506,220,"Keep target conditions",function()
		if group then
			group.atLeast=assert(tonumber(controls.count.buf),"Enter a matching-mod count")
			group.minRoll=controls.roll.buf ~= "" and assert(tonumber(controls.roll.buf),"Enter a minimum roll percent")/100 or nil
			group.negate=controls.mode:GetSelValue() == "Exclude group";group.scope=controls.scope:GetSelValue() == "Implicit modifiers" and "implicit" or "explicit"
			for _,key in ipairs({"fractured","crafted"}) do local value=controls[key]:GetSelValue();group[key]=nil;if not value:match("^Any ") then group[key]=not value:match("^Not ") end end
		end
		local result={};for _,entry in ipairs(properties) do local value=controls[entry[1]].buf;if value ~= "" then result[entry[1]]=assert(tonumber(value),"Invalid "..entry[2]) end end
		local corruption=controls.corrupted:GetSelValue();if corruption ~= "Any corruption state" then result.corrupted=corruption == "Must be corrupted" end
		local required=controls.groups.buf ~= "" and assert(tonumber(controls.groups.buf),"Invalid required group count") or nil
		if not next(result) then result=nil end
		sim.validateRecipe({steps={{method="chaos"}},targets=groups,requirements=result,requiredGroups=required})
		onKeep(groups,result,required);main:ClosePopup()
	end)
	button("close",492,506,116,"Close",function() main:ClosePopup() end)
	main:OpenPopup(624,554,"Crafting target conditions",controls,nil,nil,"close")
	return controls
end
return Panel
