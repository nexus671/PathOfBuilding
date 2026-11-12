-- Focused Journey views: comparison, actionable checks and readable stage guides.
local ui=require("Modules.PlanningUI")
local M={}
local function button(c,key,x,y,w,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run) end
function M.paste(build,entry,done)
	local c={};local w,h=math.min(820,main.screenW-40),math.min(520,main.screenH-48)
	c.text=new("EditControl"):EditControl(ui.anchor,{16,30,w-32,h-110},entry.targetItem or "",nil,"^%C\t\n",24000,nil,16,true)
	button(c,"paste",16,h-64,140,"Paste item",function() c.text:SetText(Paste()) end)
	button(c,"keep",172,h-64,160,"Keep target",function() local replacement=copyTable(entry);replacement.targetItem=c.text.buf;build.savers.BuildJourney:Put("wishlist",replacement);main:ClosePopup();done() end)
	button(c,"close",w-156,h-64,140,"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keep=true});main:OpenPopup(w,h,"Wishlist target item",c,nil,"text","close")
end
function M.compare(build,metric,perCost,choose)
	local c={};local w,h=math.min(1160,main.screenW-40),math.min(700,main.screenH-48)
	local upgrades=require("Modules.JourneyUpgrades");local data=build.savers.BuildJourney.data;local budget=require("Modules.BuildJourney").budget(data)
	local entries=upgrades.sorted(build,metric,perCost);local measured=upgrades.current(build);local fresh=upgrades.fresh(build)
	local columns={{x=8},{x=w*0.13},{x=w*0.39},{x=w*0.59},{x=w*0.73}}
	local rows={{height=30,textSize=16,"^7Slot","^7Goal","^7Cost","^7Measured gain","^7Status"}}
	for _,entry in ipairs(entries) do
		local row=fresh and measured.entries[entry.id];local key=metric=="priority" and "LifeUnreserved" or metric;local value
		if row and row.status=="calculated" then if perCost then value=row.perCost[key] else value=row.delta[key] end end
		local cost=ui.fit(entry.resourceId and string.format("%.2f %s",entry.estimate,budget[entry.resourceId].title) or "Unknown",w*0.20-20,15)
		local title=ui.fit(entry.title,w*0.25-16,15)
		rows[#rows+1]={height=40,textSize=15,entry=entry,"^7"..entry.slot,"^7"..title,"^7"..cost,"^7"..(value and string.format("%+.2f%s",value,perCost and " / unit" or "") or "Unmeasured"),"^7"..(row and row.eligible==false and "Needs review" or entry.status)}
	end
	c.entries=new("TextListControl"):TextListControl(ui.anchor,{16,66,w-32,h-140},columns,rows)
	local selected;ui.selectable(c.entries,function(row) return row.entry and row.entry.id end,function(row) selected=row.entry end)
	ui.description(c,"hint",16,26,w-32,28,{"Use the Gear sort controls to choose a metric. Costs retain their supplied resource units."},14)
	button(c,"choose",16,h-48,180,"Open selected goal",function() assert(selected,"Select a goal");main:ClosePopup();choose(selected.id) end)
	button(c,"close",w-156,h-48,140,"Back to Gear",function() main:ClosePopup() end)
	if rows[2] then c.entries.planningSelect(rows[2]) end
	ui.style(c,{choose=true});main:OpenPopup(w,h,"Compare wishlist upgrades",c,nil,"entries","close")
end
function M.issues(build,entry)
	local result=require("Modules.JourneyUpgrades").current(build);local row=result and result.entries[entry.id]
	local lines={entry.title};if row then for _,issue in ipairs(row.issues or {}) do lines[#lines+1]=issue end;for _,issue in ipairs(row.introduced or {}) do lines[#lines+1]=issue.text end;if row.reason then lines[#lines+1]=row.reason end end
	local c={};local w,h=math.min(840,main.screenW-40),math.min(500,main.screenH-48)
	c.details=new("TextListControl"):TextListControl(ui.anchor,{16,32,w-32,h-110},nil,ui.rows(lines,w-56))
	button(c,"goals",16,h-48,170,"Goals and budget",function() require("Classes.BuildProposalControl").Goals(build) end)
	button(c,"checks",202,h-48,170,"Build checks",function() require("Classes.BuildProposalControl").Analysis(build) end)
	button(c,"close",w-156,h-48,140,"Back to Gear",function() main:ClosePopup() end)
	ui.style(c);main:OpenPopup(w,h,"Why this goal needs review",c,nil,nil,"close")
end
function M.guide(build,stage)
	for _,current in ipairs(build.savers.BuildJourney.data.stages) do if current.id==stage.id then stage=current;break end end
	local c={};local w,h=math.min(920,main.screenW-40),math.min(700,main.screenH-48);local draft=copyTable(stage)
	ui.label(c,"title",16,26,"Level "..draft.level.." | "..draft.title,22)
	local gems={};for _,gem in pairs(build.data.gems) do if draft.gems and draft.gems:find(gem.name,1,true) then gems[#gems+1]=gem end end
	table.sort(gems,function(a,b) return a.name<b.name end)
	local chips=new("Control"):Control(ui.anchor,{16,64,w-32,64});c.gemLinks=chips
	function chips:Draw()
		local x,y=self:GetPos();local px,py=0,0
		for _,gem in ipairs(gems) do local width=DrawStringWidth(14,"VAR",gem.name)+28;if px+width>w-40 then px=0;py=py+28 end
			if py+24<=64 then SetDrawColor("^x233142");DrawImage(nil,x+px,y+py,width,24);SetDrawColor(gem.tags.strength and "^xE58F8F" or gem.tags.dexterity and "^x92D39C" or "^x95B9FF");DrawImageQuad(nil,x+px+5,y+py+12,x+px+10,y+py+7,x+px+15,y+py+12,x+px+10,y+py+17);DrawString(x+px+20,y+py+4,"LEFT",14,"VAR",gem.name);px=px+width+8 end
		end
	end
	local function refresh()
		local lines={};local function section(label,value) if value and value~="" then lines[#lines+1]=label;for line in value:gmatch("[^\r\n]+") do lines[#lines+1]="  "..line end;lines[#lines+1]="" end end
		section("Gems and written links",draft.gems);section("Passives",draft.passives);section("Gear and acquisition",draft.gear);section("Ascendancy",draft.ascendancy);section("Switch when",draft.transition);section("Notes",draft.notes)
		c.details.list=ui.rows(lines,math.floor(w*0.56)-28)
		local rows={};local done={};for _,title in ipairs(draft.questChecks or {}) do done[title]=true end
		for line in (draft.quests or ""):gmatch("[^\r\n]+") do for _,row in ipairs(ui.rows({(done[line] and "[x] " or "[ ] ")..line},math.floor(w*0.40)-30)) do row.quest=line;row.selected=row.quest==c.quests.selectedKey;rows[#rows+1]=row end end
		if #rows==0 then rows=ui.rows({"Add quest rewards and tasks in Edit stage."},math.floor(w*0.40)-30) end
		c.quests.list=rows
	end
	c.details=new("TextListControl"):TextListControl(ui.anchor,{16,140,math.floor(w*0.56),h-214},nil,{})
	ui.label(c,"questsTitle",math.floor(w*0.56)+32,116,"Quest checklist")
	c.quests=new("TextListControl"):TextListControl(ui.anchor,{math.floor(w*0.56)+32,140,math.floor(w*0.40)-16,h-214},nil,{})
	ui.selectable(c.quests,function(row) return row.quest end,function() end,function(row)
		local done={};for _,title in ipairs(draft.questChecks or {}) do done[title]=true end;done[row.quest]=not done[row.quest] or nil
		draft.questChecks={};for line in (draft.quests or ""):gmatch("[^\r\n]+") do if done[line] then draft.questChecks[#draft.questChecks+1]=line end end
		build.savers.BuildJourney:Put("stages",draft);refresh()
	end)
	button(c,"close",w-180,h-48,164,"Back to Leveling",function() main:ClosePopup() end)
	refresh();ui.style(c);main:OpenPopup(w,h,"Leveling guide",c,nil,nil,"close")
end
return M
