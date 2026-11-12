local ui=require("Modules.PlanningUI")
local planner=require("Modules.AtlasPlanner")
local targets=require("Modules.AtlasTargets")
local M={}
function M.Open(build,options)
	local c={};local w,h=math.min(940,main.screenW-40),math.min(650,main.screenH-60);local selected;local lastPreview;local previewCurrent=false
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	ui.description(c,"help",16,28,w-32,44,{"Mark desired nodes and excluded paths, then preview all connections together. Rebuilding from the start can refund old allocations; nothing changes until Use preview."},14)
	c.desired=new("TextListControl"):TextListControl(ui.anchor,{16,124,math.floor((w-48)*0.48),h-298},nil,{})
	local detailX=32+math.floor((w-48)*0.48);local detailW=w-detailX-16
	c.details=new("TextListControl"):TextListControl(ui.anchor,{detailX,124,detailW,h-298},nil,{})
	local function showDetails(plan,preview)
		local summary=targets.summary(plan);local lines={#(plan.desired or {}).." desired | "..#(plan.avoided or {}).." avoided",preview and "Preview investment" or "Current allocated investment"}
		if preview then local diff=require("Modules.AtlasStrategy").compare(options.current(),plan);lines[#lines+1]=#diff.added.." points added | "..#diff.removed.." points refunded"
			for _,node in ipairs(diff.added) do if node.kind=="notable" or node.kind=="keystone" then lines[#lines+1]="+ "..node.name end end
		end
		for _,row in ipairs(summary.mechanics) do lines[#lines+1]=row.name..": "..row.total.." points | "..row.notable.." notables | "..row.small.." small | "..row.gateway.." gateways" end
		lines[#lines+1]=summary.connectedDesired.." / "..summary.desired.." desired nodes connected"
		for _,keystone in ipairs(summary.keystones) do lines[#lines+1]="Keystone: "..keystone.name;for _,stat in ipairs(keystone.stats) do lines[#lines+1]=stat end end
		for _,warning in ipairs(summary.warnings) do lines[#lines+1]=warning end
		lines[#lines+1]="Counts describe allocations, not effective map odds or farming income.";c.details.list=ui.rows(lines,detailW-28,14)
	end
	local function refresh()
		local plan=options.current();local tree=planner.tree(plan.version);local rows={};local prior=selected;selected=nil
		for _,kind in ipairs({"desired","avoided"}) do for _,id in ipairs(plan[kind] or {}) do local node=tree.nodes[id];local row={height=46,textSize=14,"^7"..ui.fit(node.name,c.desired.width-30,14),subtitle=kind=="desired" and "Desired" or "Avoided",id=id,kind=kind};rows[#rows+1]=row;if prior and prior.id==id and prior.kind==kind then selected=row end end end
		c.desired.list=#rows>0 and rows or ui.rows({"No desired nodes yet.","Add the selected tree node or select a mechanic's notables."},c.desired.width-28,14)
		previewCurrent=false;lastPreview=nil;showDetails(plan)
	end
	ui.selectable(c.desired,function(row) return row.id end,function(row) selected=row end)
	button("targetAdd",16,84,180,"Add selected node",function() local id=assert(options.selected(),"Select a tree node first");options.change(targets.toggle(options.current(),id,"desired"));refresh() end)
	c.targetAdd.enabled=function() local id=options.selected();return id~=nil and id~=planner.tree(options.current().version).start end
	c.targetAdd.label=function() local id=options.selected();for _,wanted in ipairs(options.current().desired or {}) do if wanted==id then return "Unmark selected node" end end;return "Mark selected node" end
	c.targetAdd.tooltipText="Select a node on the tree or in search results first. This toggles its desired-route preference."
	button("targetRemove",208,84,180,"Remove preference",function() assert(selected,"Choose a preference");options.change(targets.toggle(options.current(),selected.id,selected.kind));selected=nil;refresh() end)
	c.targetRemove.enabled=function() return selected~=nil end
	c.targetMechanic=new("DropDownControl"):DropDownControl(ui.anchor,{detailX,h-156,detailW-150,28},require("Modules.AtlasStrategy").mechanics)
	button("targetMechanicAdd",w-154,h-156,138,"Toggle notables",function() options.change(targets.mechanic(options.current(),c.targetMechanic:GetSelValue()));refresh() end)
	c.targetMode=new("DropDownControl"):DropDownControl(ui.anchor,{16,h-156,c.desired.width,28},{"Select nodes","Mark desired","Mark avoided"},function(_,value) options.mode(value);end);c.targetMode:SelByValue(options.mode())
	c.routeMode=new("DropDownControl"):DropDownControl(ui.anchor,{16,h-114,c.desired.width,28},{"Retain existing allocations","Rebuild from start"})
	button("targetCalculate",detailX,h-114,132,"Recalculate",function() targets.start(build,options.current(),c.routeMode:GetSelValue()=="Rebuild from start") end)
	button("targetPause",detailX+144,h-114,100,"Pause",function() local state=targets.jobs[build];if state and state.thread then state.paused=not state.paused end end)
	c.targetPause.label=function() local state=targets.jobs[build];return state and state.paused and "Resume" or "Pause" end
	c.targetPause.enabled=function() return targets.jobs[build] and targets.jobs[build].thread~=nil end
	button("targetCancel",detailX+256,h-114,detailW-256,"Cancel job",function() targets.cancel(build) end)
	c.targetCancel.enabled=c.targetPause.enabled
	ui.label(c,"progress",16,h-70,"",14)
	c.progress.label=function()
		targets.tick(build);local state=targets.jobs[build];if not state then return "^7Shift-click a tree node to mark it as desired." end
		if state.result then previewCurrent=require("Modules.PlanningData").hash(options.current())==state.baseHash
			if previewCurrent and lastPreview~=state.result then lastPreview=state.result;showDetails(state.result.plan,true) end
		end
		local text=state.error or state.status;if state.paused then text="Paused" elseif state.thread then text=text.." | order "..(state.progress.order or 1).." / "..(state.progress.orders or "?") elseif state.result then text=text.." | "..#state.result.plan.nodes.." allocated points" end
		if state.result and not previewCurrent then text="Plan changed. Recalculate before using the preview." end
		return "^7"..ui.fit(text,w-36,14)
	end
	button("targetApply",16,h-42,220,"Use preview",function() local plan=targets.apply(build,options.current());options.change(plan);targets.jobs[build]=nil;main:ClosePopup() end)
	c.targetApply.enabled=function() return targets.jobs[build] and targets.jobs[build].result~=nil and previewCurrent end
	button("close",w-156,h-42,140,"Back to tree",function() main:ClosePopup() end)
	ui.style(c,{targetApply=true});refresh();main:OpenPopup(w,h,"Atlas desired nodes and routes",c,nil,nil,"close")
end
return M
