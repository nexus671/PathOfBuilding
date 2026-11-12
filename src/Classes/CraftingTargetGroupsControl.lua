-- Editable AND groups with OR alternatives; final item properties remain shared.
local sim=require("Modules.CraftingSimulator")
local ui=require("Modules.PlanningUI")
local M={}
function M.Open(model,state,input,requirements,count,onKeep)
	model=sim.context(model,state)
	local groups=copyTable(input);local properties=requirements and copyTable(requirements);local required=count;local selected=math.min(1,#groups);local member
	local c={};local w,h=math.min(940,main.screenW-40),math.min(650,main.screenH-60);local left=math.floor((w-48)*0.46);local right=left+32;local rightW=w-right-16
	local function button(key,x,y,width,title,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},title,run) end
	ui.description(c,"help",16,28,w-32,44,{"Groups are required together by default (AND). Alternatives within a group match any listed modifier (OR). Choose how many groups must pass, then set item properties separately."},14)
	c.groups=new("TextListControl"):TextListControl(ui.anchor,{16,148,left,h-260},nil,{})
	c.members=new("TextListControl"):TextListControl(ui.anchor,{right,148,rightW,h-260},nil,{})
	ui.label(c,"groupsLabel",16,120,"Requirement groups",14);ui.label(c,"membersLabel",right,120,"Alternatives in selected group",14)
	local function group() return groups[selected] end
	local function show()
		local list={};local chosen=group();member=nil
		for _,id in ipairs(chosen and chosen.anyOf or {}) do local mod=model.byId[id];list[#list+1]={height=60,textSize=14,"^7"..ui.fit(mod and table.concat(mod," / ") or id,rightW-30,14),subtitle=ui.fit(id,rightW-30,13),id=id} end
		c.members.list=#list>0 and list or ui.rows({"Add a requirement group, then add alternative modifiers here."},rightW-28,14)
	end
	local function refresh()
		selected=math.max(1,math.min(selected,#groups));local list={}
		for i,entry in ipairs(groups) do
			local traits={entry.scope=="implicit" and "Implicit" or "Explicit"};if entry.minRoll then traits[#traits+1]="Roll >= "..math.floor(entry.minRoll*100).."%" end
			for _,key in ipairs({"fractured","crafted"}) do if entry[key]~=nil then traits[#traits+1]=(entry[key] and "" or "Not ")..key end end
			list[#list+1]={height=88,textSize=16,x=10,card=true,selected=i==selected,"^7Group "..i.." | "..(entry.negate and "Exclude" or "Require"),subtitle="Match "..(entry.atLeast or 1).." of "..#entry.anyOf.." alternative modifiers",detail=ui.fit(table.concat(traits," | "),left-30,14),index=i}
		end
		c.groups.list=#list>0 and list or ui.rows({"No modifier requirements yet.","Add a group or use item properties only."},left-28,14)
		local choices={{label="All groups required",val=false},{label="Ignore modifier groups",val=0}};for i=1,#groups do choices[#choices+1]={label="At least "..i.." groups",val=i} end
		if required and required>#groups then required=nil end;c.requiredGroups:SetList(choices);c.requiredGroups:SelByValue(required~=nil and required or false,"val")
		show()
	end
	ui.selectable(c.groups,function(row) return row.index end,function(row) selected=row.index;show() end)
	ui.selectable(c.members,function(row) return row.id end,function(row) member=row.id end)
	c.requiredGroups=new("DropDownControl"):DropDownControl(ui.anchor,{16,h-84,left,28},{},function(_,entry) required=entry.val~=false and entry.val or nil end)
	button("newGroup",16,84,math.floor((left-12)/2),"+ Requirement",function()
		require("Classes.CraftingModifierControl").Open(model,state,{action="Create group",choose=function(id)
			assert(#groups<6,"Use up to six groups");local kind=model.byId[id].type;groups[#groups+1]={anyOf={id},scope=(kind=="Corrupted" or kind=="Exarch" or kind=="Eater") and "implicit" or "explicit"};selected=#groups;refresh()
		end})
	end);c.newGroup.enabled=function() return #groups<6 end
	button("deleteGroup",28+math.floor((left-12)/2),84,math.floor((left-12)/2),"Remove group",function() assert(group(),"Choose a group");table.remove(groups,selected);refresh() end);c.deleteGroup.enabled=function() return group()~=nil end
	button("newAlternative",right,84,math.floor((rightW-12)/2),"+ Alternative",function()
		local chosen=assert(group(),"Choose a group");require("Classes.CraftingModifierControl").Open(model,state,{action="Add alternative",choose=function(id)
			assert(require("Modules.CraftingModifiers").scope(model.byId[id])==(chosen.scope or "explicit"),"Choose the same explicit/implicit scope, or create a separate group")
			for _,other in ipairs(chosen.anyOf) do if other==id then return end end;assert(#chosen.anyOf<30,"Use up to thirty alternatives per group");chosen.anyOf[#chosen.anyOf+1]=id;refresh()
		end})
	end);c.newAlternative.enabled=function() return group()~=nil end
	button("deleteAlternative",right+math.floor((rightW-12)/2)+12,84,math.floor((rightW-12)/2),"Remove alternative",function()
		assert(member,"Choose an alternative");local chosen=assert(group());for i=#chosen.anyOf,1,-1 do if chosen.anyOf[i]==member then table.remove(chosen.anyOf,i) end end;if #chosen.anyOf==0 then table.remove(groups,selected) end;refresh()
	end);c.deleteAlternative.enabled=function() return member~=nil end
	button("groupConditions",right,h-84,rightW,"Group conditions & item properties",function()
		require("Classes.CraftingTargetControl").Open(groups,properties,required,function(next,conditions,matching) groups=next;properties=conditions;required=matching;refresh() end,selected)
	end)
	button("keepGroups",16,h-42,220,"Keep targets",function() sim.validateRecipe({steps={{method="alchemy"}},targets=groups,requirements=properties,requiredGroups=required});onKeep(groups,properties,required);main:ClosePopup() end)
	c.keepGroups.enabled=function() return #groups>0 or properties and next(properties)~=nil end
	button("close",w-156,h-42,140,"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keepGroups=true});refresh();main:OpenPopup(w,h,"Crafting target groups",c,nil,nil,"close")
end
return M
