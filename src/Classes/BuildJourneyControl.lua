-- A shared home for character progression and acquisition.
local ui=require("Modules.PlanningUI")
local journey=require("Modules.BuildJourney")
local Panel={}
local function button(c,key,x,y,w,label,run)
	c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run);return c[key]
end
local fields={
	milestones={{"title","Milestone"},{"kind","Type",{"task","passives","gems","gear","craft","atlas","quest","ascendancy"}},{"level","Required level"},{"priority","Priority (1 first)"},{"dependencies","Prerequisites (IDs, comma separated)"},{"wishlistId","Gear goal ID"},{"stageId","Guide stage ID"},{"projectId","Craft ID"},{"atlasId","Atlas plan ID"},{"notes","Notes"}},
	wishlist={{"title","Gear goal"},{"slot","Equipment slot"},{"route","Acquire by",{"buy","craft","farm","owned"}},{"stage","Upgrade stage",{"next","final","alternative"}},{"status","Status",{"planned","owned","skipped"}},{"priority","Priority (1 first)"},{"projectId","Craft ID"},{"resourceId","Cost resource ID"},{"estimate","Estimated quantity"},{"reserve","Reserve budget",{"no","yes"}},{"notes","Notes"}},
	resources={{"title","Currency, material or owned base"},{"unit","Unit (optional)"},{"notes","Notes"}},
	ledger={{"resourceId","Resource ID"},{"kind","Record",{"add","spend"}},{"amount","Quantity"},{"projectId","Craft ID (optional)"},{"note","Source / spending note"}},
	stages={{"title","Stage"},{"level","Level"},{"gems","Gems and links"},{"passives","Passives"},{"gear","Gear and acquisition"},{"ascendancy","Ascendancy"},{"quests","Quests and rewards"},{"transition","Switch when"},{"notes","Notes"}},
}
function Panel.Edit(build,key,entry,refresh)
	local saver=build.savers.BuildJourney;local c={};entry=copyTable(entry or {})
	local list=fields[key];local width=math.min(820,main.screenW-40);local height=math.min(544,main.screenH-64)
	local column=math.floor((width-48)/2)
	local linkLists={resourceId=saver.data.resources,wishlistId=saver.data.wishlist,stageId=saver.data.stages,projectId=build.savers.CraftingProjects.projects,atlasId=build.savers.AtlasPlans.plans}
	local linked={}
	for i,field in ipairs(list) do
		local name,label,choices=unpack(field);local x=16+math.floor((i-1)/6)*(column+16);local y=24+((i-1)%6)*68
		if linkLists[name] then
			linked[name]=true;choices={{label="None",val=""}}
			for _,e in ipairs(linkLists[name]) do choices[#choices+1]={label=e.title,val=e.id} end
			if entry[name] then local found=false;for _,e in ipairs(choices) do if e.val==entry[name] then found=true end end;if not found then choices[#choices+1]={label="Missing: "..entry[name],val=entry[name]} end end
			label=label:gsub(" ID","")
		end
		if name=="slot" then choices={};for slot in pairsSortByKey(build.itemsTab.slots) do choices[#choices+1]=slot end end
		ui.label(c,name.."Label",x,y,label,14)
		local value=entry[name]
		if name=="dependencies" then value=table.concat(value or {},", ") elseif name=="reserve" then value=value and "yes" or "no" end
		if choices then c[name]=new("DropDownControl"):DropDownControl(ui.anchor,{x,y+20,column,26},choices);c[name]:SelByValue(value or (linked[name] and "" or choices[1]),linked[name] and "val" or nil)
		else c[name]=new("EditControl"):EditControl(ui.anchor,{x,y+20,column,26},value and tostring(value) or "","",nil,12000) end
		if name=="notes" or key=="stages" and name~="title" and name~="level" then
			c[name].width=column-48
			button(c,name.."Expand",x+column-40,y+20,40,"...",function()
				local editor={};local ew,eh=math.min(800,main.screenW-40),math.min(500,main.screenH-80)
				editor.text=new("EditControl"):EditControl(ui.anchor,{16,28,ew-32,eh-100},c[name].buf,nil,"^%C\t\n",12000,nil,16,true)
				button(editor,"keep",16,eh-48,140,"Keep text",function() c[name]:SetText(editor.text.buf);main:ClosePopup() end)
				button(editor,"cancel",ew-156,eh-48,140,"Cancel",function() main:ClosePopup() end)
				ui.style(editor,{keep=true});main:OpenPopup(ew,eh,label,editor,nil,"text","cancel")
			end)
		end
	end
	ui.description(c,"hint",16,height-96,width-32,38,{"IDs are shown in each detail panel. Keep to update this build; use the normal build Save to persist."},14)
	button(c,"keep",16,height-48,140,"Keep",function()
		local e=copyTable(entry);e.id=e.id or (key.."-"..os.time().."-"..tostring(GetTime())):gsub("[^%w_-]","")
		if not entry.id then
			local used={};for _,old in ipairs(saver.data[key]) do used[old.id]=true end
			local base=e.id;local suffix=1;while used[e.id] do suffix=suffix+1;e.id=base.."-"..suffix end
		end
		for _,field in ipairs(list) do local name=field[1];local v=linked[name] and c[name]:GetSelValueByKey("val") or (field[3] or name=="slot") and c[name]:GetSelValue() or c[name].buf
			if name=="dependencies" then local deps={};for dep in v:gmatch("[^,%s]+") do deps[#deps+1]=dep end;v=deps
			elseif name=="reserve" then v=v=="yes"
			elseif name=="level" or name=="priority" or name=="estimate" or name=="amount" then v=v~="" and assert(tonumber(v),"Enter a number for "..name) or nil
			elseif v=="" then v=nil end
			e[name]=v
		end
		if key=="ledger" then e.at=e.at or os.time() end
		saver:Put(key,e);main:ClosePopup();refresh(e.id)
	end)
	button(c,"cancel",width-156,height-48,140,"Cancel",function() main:ClosePopup() end)
	for _,control in pairs(c) do control.layoutAudit="journey-editor" end
	ui.style(c,{keep=true});main:OpenPopup(width,height,"Journey | "..key,c,nil,nil,"cancel")
end
function Panel.Open(build,source,layout)
	local saver=build.savers.BuildJourney;local c={};local w,h=layout.width,layout.height
	local page=source and source.page or "Overview";local selected=source and source.selected
	local pages={"Overview","Roadmap","Gear","Budget","Leveling"};local keys={Roadmap="milestones",Gear="wishlist",Budget="resources",Leveling="stages"}
	local left=math.floor(math.max(300,math.min(390,w*0.36)));local right=w-left-48
	local function reopen(id) layout.navigate("journey",{page=page,selected=id or selected}) end
	ui.label(c,"heading",16,18,"Your build journey",24)
	ui.description(c,"intro",16,50,w-32,24,{saver.warning or "A roadmap from your current character to the gear and content you want to play."},14)
	for i,name in ipairs(pages) do button(c,"page"..i,16+(i-1)*150,82,140,name,function() page=name;selected=nil;reopen() end);c["page"..i].locked=page==name end
	local data=saver.data;local budget=journey.budget(data);local nextActions=journey.next(data,build)
	local rows={};local entries={};local detail={}
	local function add(e,label)
		entries[#entries+1]=e
		local wrapped=ui.rows({label},left-24,15)
		for i,row in ipairs(wrapped) do row.line=#entries;if i==#wrapped then row.height=row.height+14 end;rows[#rows+1]=row end
	end
	if page=="Overview" then
		local ready,blocked=0,0;for _,e in ipairs(nextActions) do if e.blocked then blocked=blocked+1 else ready=ready+1 end end
		local cardW=math.floor((w-64)/3)
		ui.card(c,"ready",16,128,cardW,"READY TO WORK ON",tostring(ready),"Prerequisites and budget checked")
		ui.card(c,"blocked",32+cardW,128,cardW,"NEEDS ATTENTION",tostring(blocked),"Select a task to see its blockers")
		ui.card(c,"crafts",48+cardW*2,128,cardW,"SAVED CRAFTS",tostring(#build.savers.CraftingProjects.projects),"Continue in the Crafting page")
		for _,e in ipairs(nextActions) do add(e,(e.blocked and "[WAIT] " or "[NEXT] ")..e.title) end
		detail={"What should I do next?","Tasks with met prerequisites come first, then your chosen priority (1 first). This is a planning order, not a measured upgrade score.","Select a task for its reasons, links and next step.","", "Character checks"}
		for _,e in ipairs(require("Modules.BuildInsights").audit(build).dependencies) do detail[#detail+1]=e.text end
	else
		local key=keys[page];local list=copyTable(data[key])
		if page=="Leveling" then table.sort(list,function(a,b) if (a.level or 1)==(b.level or 1) then return a.id<b.id end;return (a.level or 1)<(b.level or 1) end) end
		for _,e in ipairs(list) do add(e,(e.done and "[DONE] " or "")..(e.level and "Lv "..e.level.." | " or "")..e.title) end
		if #rows==0 then detail={"Start your "..page:lower(),"Add an entry below. Your plans travel with the build when you save or export it.","",page=="Gear" and "Equipped gear is shown below; wishlist entries record the next and final pieces you want." or page=="Budget" and "Add each currency, material or base, then record holdings and spending. Estimates and reservations never convert currencies or spend money automatically." or page=="Leveling" and "Write gems, links, gear, passives, ascendancy and quest steps. Calculated AI leveling stages can also be kept from AI builds > Candidates." or "Connect milestones to gear goals, crafts, guide stages and Atlas plans using the IDs in their detail panels."} end
		if page=="Gear" then
			detail[#detail+1]="Current equipment"
			for name,slot in pairsSortByKey(build.itemsTab.slots) do local item=build.itemsTab.items[slot.selItemId];if item then detail[#detail+1]=name..": "..(item.name or item.baseName) end end
		end
	end
	local listY=page=="Overview" and 242 or 128;local selectedEntry
	local function linkedTitle(key,value)
		local list=key=="projectId" and build.savers.CraftingProjects.projects or key=="atlasId" and build.savers.AtlasPlans.plans or key=="stageId" and data.stages or key=="wishlistId" and data.wishlist
		if list then for _,entry in ipairs(list) do if entry.id==value then return entry.title end end;return "Missing: "..value end
		return tostring(value)
	end
	local labels={kind="Type",slot="Slot",route="Acquire by",stage="Upgrade stage",status="Status",level="Level",priority="Priority",projectId="Craft",atlasId="Atlas plan",stageId="Guide stage",wishlistId="Gear goal",gems="Gems and links",passives="Passives",gear="Gear",ascendancy="Ascendancy",quests="Quests",transition="Switch when",notes="Notes"}
	local function show(e)
		selectedEntry=e;selected=e.id;local lines={e.title,"ID: "..e.id}
		if page=="Overview" then
			lines[#lines+1]=e.blocked and "Waiting on the following" or "Ready: prerequisites met; no recorded funding gap."
			for _,reason in ipairs(e.reasons) do lines[#lines+1]=reason end;e=e.entry
		end
		if e.slot then local slot=build.itemsTab.slots[e.slot];local item=slot and build.itemsTab.items[slot.selItemId];lines[#lines+1]="Equipped now: "..(item and (item.name or item.baseName) or "Empty slot") end
		for _,field in ipairs({"kind","slot","route","stage","status","level","priority","projectId","atlasId","stageId","wishlistId","gems","passives","gear","ascendancy","quests","transition","notes"}) do if e[field] then lines[#lines+1]=labels[field]..": "..linkedTitle(field,e[field]) end end
		if e.dependencies and #e.dependencies>0 then lines[#lines+1]="Prerequisites: "..table.concat(e.dependencies,", ") end
		if e.resourceId then lines[#lines+1]=string.format("Estimate: %.2f %s%s",e.estimate,budget[e.resourceId].title,e.reserve and " (reserved)" or "") end
		if page=="Overview" then
			lines[#lines+1]="";lines[#lines+1]="Current character checks"
			local audit=require("Modules.BuildInsights").audit(build)
			for _,check in ipairs(audit.dependencies) do lines[#lines+1]=check.text end
			if #audit.dependencies==0 then lines[#lines+1]="No issues detected by the available dependency checks." end
		end
		if page=="Budget" then
			local r=budget[e.id];lines[#lines+1]=string.format("Owned %.2f | Spent %.2f | Reserved %.2f",r.owned,r.spent,r.reserved);lines[#lines+1]=string.format("Available %.2f | Funding gap %.2f",r.available,r.gap)
			for _,record in ipairs(data.ledger) do if record.resourceId==e.id then lines[#lines+1]=record.kind.." "..record.amount.." | "..(record.projectId or "").." | "..(record.note or "") end end
		end
		c.details.list=ui.rows(lines,right-24,15)
	end
	c.entries=new("TextListControl"):TextListControl(ui.anchor,{16,listY,left,h-listY-72},nil,rows)
	c.entries.onClick=function(row) if row and row.line then show(entries[row.line]) end end
	c.details=new("TextListControl"):TextListControl(ui.anchor,{left+32,listY,right,h-listY-72},nil,ui.rows(detail,right-24,15))
	for _,e in ipairs(entries) do if e.id==selected then show(e);break end end
	if not selectedEntry and entries[1] then show(entries[1]) end
	if page~="Overview" then
		button(c,"add",16,h-48,136,"Add "..(page=="Budget" and "resource" or "entry"),function() Panel.Edit(build,keys[page],nil,reopen) end)
		button(c,"edit",168,h-48,116,"Edit",function() assert(selectedEntry,"Select an entry");Panel.Edit(build,keys[page],selectedEntry,reopen) end)
		c.edit.enabled=function() return selectedEntry~=nil end
	end
	if page=="Roadmap" then button(c,"complete",300,h-48,156,"Toggle complete",function() assert(selectedEntry,"Select a milestone");saver:Complete(selectedEntry.id);reopen() end)
	elseif page=="Budget" then button(c,"record",300,h-48,176,"Record transaction",function() Panel.Edit(build,"ledger",{resourceId=selectedEntry and selectedEntry.id,kind="add"},function() reopen() end) end) end
	if page~="Overview" then
		button(c,"remove",492,h-48,100,"Remove",function()
			assert(selectedEntry,"Select an entry")
			main:OpenConfirmPopup("Remove entry", "Remove "..selectedEntry.title.."? Linked prerequisites and records must be removed first.","Remove",function()
				local replacement=copyTable(data);local list=replacement[keys[page]]
				for i,e in ipairs(list) do if e.id==selectedEntry.id then table.remove(list,i);break end end
				local ok,err=pcall(function() saver:Replace(replacement) end)
				if ok then selected=nil;reopen() else main:OpenMessagePopup("Entry is still linked",tostring(err):match("[^\n]+")) end
			end)
		end)
		c.remove.enabled=function() return selectedEntry~=nil end
	end
	button(c,"openLink",w-200,h-48,184,"Open linked plan",function()
		assert(selectedEntry,"Select an entry");local e=selectedEntry.entry or selectedEntry
		if e.projectId then for _,project in ipairs(build.savers.CraftingProjects.projects) do if project.id==e.projectId then layout.openWorkbench(project);return end end;error("Linked craft is missing")
		elseif e.atlasId then for _,plan in ipairs(build.savers.AtlasPlans.plans) do if plan.id==e.atlasId then layout.navigate("atlas",plan);return end end;error("Linked Atlas plan is missing")
		elseif e.stageId then page="Leveling";selected=e.stageId;reopen();return
		elseif e.wishlistId then page="Gear";selected=e.wishlistId;reopen();return end
		error("This entry has no linked plan")
	end)
	c.openLink.enabled=function() local e=selectedEntry and (selectedEntry.entry or selectedEntry);return e and (e.projectId or e.atlasId or e.stageId or e.wishlistId)~=nil end
	layout.snapshot=function() return {page=page,selected=selected} end
	for _,control in pairs(c) do control.layoutAudit="journey-workspace" end
	ui.style(c,{add=true});layout.mount(w,h,"Journey",c)
end
return Panel
