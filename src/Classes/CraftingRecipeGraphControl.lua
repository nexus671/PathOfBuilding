-- Direct route editing: drag labelled success/failure ports onto destination cards.
local ui=require("Modules.PlanningUI")
local routes=require("Modules.CraftingRoutes")
local art=require("Modules.CraftingWorkbench")
local visual=require("Modules.LootFilterVisuals")
local M={}
function M.Open(input,options)
	local recipe=copyTable(input);local history=require("Modules.PlanningHistory").new(recipe)
	local c={};local w,h=math.min(1080,main.screenW-40),math.min(720,main.screenH-60);local selected=#recipe.steps>0 and 1 or nil;local all=false
	local function button(key,x,y,width,title,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},title,run) end
	ui.description(c,"help",16,28,w-32,40,{"Drag S (success) or F (failure) onto a step or Finish. Route edits are staged here; Keep recipe in the editor persists them. Wheel scrolls the diagram."},14)
	local canvas=new("Control"):Control(ui.anchor,{16,120,w-32,h-224});c.routeCanvas=canvas;canvas.scroll=0
	function canvas:IsMouseOver() return self:IsShown() and self:IsMouseInBounds() end
	local function layout()
		local cols=math.max(1,math.floor((canvas.width-16)/264));local nodeW=(canvas.width-72-(cols-1)*44)/cols;local nodes={}
		for i=1,#recipe.steps+1 do nodes[i]={index=i,x=36+(i-1)%cols*(nodeW+44),y=32+math.floor((i-1)/cols)*156-canvas.scroll,w=nodeW,h=94} end
		canvas.content=48+math.ceil((#recipe.steps+1)/cols)*156;canvas.nodes=nodes;return nodes
	end
	local function hit(px,py)
		if px<0 or py<0 or px>canvas.width or py>canvas.height then return end
		for _,node in ipairs(layout()) do if px>=node.x and px<=node.x+node.w+8 and py>=node.y and py<=node.y+node.h then return node end end
	end
	local function commit(next)
		history:record(next);recipe=next;options.change(copyTable(recipe))
	end
	local function line(x1,y1,x2,y2,color)
		local dx,dy=x2-x1,y2-y1;local length=math.max(1,math.sqrt(dx*dx+dy*dy));local ox,oy=-dy/length,dx/length
		SetDrawColor(color);DrawImageQuad(nil,x1+ox,y1+oy,x2+ox,y2+oy,x2-ox,y2-oy,x1-ox,y1-oy)
	end
	function canvas:Draw()
		local x,y=self:GetPos();local nodes=layout();SetViewport(x,y,self.width,self.height);visual.box(0,0,self.width,self.height,"^x101822")
		for _,edge in ipairs(routes.edges(recipe)) do if all or edge.source==selected or edge.target==selected then
			local a,b=nodes[edge.source],nodes[edge.target];local success=edge.kind=="success";local color=success and "^x78D5A0" or "^xE49B91";local sy=a.y+(success and 30 or 64);local ty=b.y+(success and 40 or 60)
			local outX=a.x+a.w+(success and 16 or 20);local inX=b.x-(success and 12 or 16);local lane=success and a.y-12 or a.y+a.h+18
			line(a.x+a.w,sy,outX,sy,color);line(outX,sy,outX,lane,color);line(outX,lane,inX,lane,color);line(inX,lane,inX,ty,color);line(inX,ty,b.x-6,ty,color)
			SetDrawColor(color);DrawImageQuad(nil,b.x,ty,b.x-7,ty-5,b.x-7,ty+5,b.x-7,ty+5)
		end end
		for _,node in ipairs(nodes) do if node.y+node.h>0 and node.y<self.height then
			local step=recipe.steps[node.index];visual.box(node.x,node.y,node.w,node.h,node.index==selected and "^xC5AB74" or "^x3F566F");visual.box(node.x+1,node.y+1,node.w-2,node.h-2,"^x192635")
			local path=step and art.icon(step.method,step,options.model);if path then SetDrawColor(1,1,1);DrawImage(visual.image(path),node.x+10,node.y+10,28,28) end
			visual.text(node.x+46,node.y+10,15,step and node.index..". "..art.actionLabel(step) or "Finish","^xF0D8A1",node.w-62)
			visual.text(node.x+10,node.y+44,13,step and ((step.maxAttempts or 1)==1 and "1 attempt per visit" or "Up to "..step.maxAttempts.." attempts") or "End this recipe","^xD5DEE8",node.w-28)
			visual.text(node.x+10,node.y+68,12,step and ((step.untilTargets or step.untilRequirements) and "Repeat until conditions match" or "One action per visit") or "Inspect the final item","^xA6B3C6",node.w-28)
			if step then for _,port in ipairs({{"S",30,"^x78D5A0"},{"F",64,"^xE49B91"}}) do visual.box(node.x+node.w-6,node.y+port[2]-7,14,14,port[3]);visual.text(node.x+node.w-3,node.y+port[2]-6,12,port[1],"^x0A121A") end end
		end end
		if self.drag then local px,py=GetCursorPos();local source=nodes[self.drag.source];line(source.x+source.w,source.y+(self.drag.kind=="success" and 30 or 64),px-x,py-y,"^xF0D8A1") end
		SetViewport()
	end
	function canvas:OnKeyDown(key)
		if not self:IsMouseOver() then return end
		if key=="LEFTBUTTON" then local x,y=self:GetPos();local px,py=GetCursorPos();px,py=px-x,py-y;local node=hit(px,py)
			if node and recipe.steps[node.index] then selected=node.index;c.graphStep:SelByValue(selected,"val")
				if px>=node.x+node.w-10 then local sy=node.y+30;local fy=node.y+64;if math.abs(py-sy)<12 or math.abs(py-fy)<12 then self.drag={source=node.index,kind=math.abs(py-sy)<math.abs(py-fy) and "success" or "failure"} end end
			end
			return self
		end
	end
	function canvas:OnKeyUp(key)
		if key=="LEFTBUTTON" and self.drag then local x,y=self:GetPos();local px,py=GetCursorPos();local node=hit(px-x,py-y);local drag=self.drag;self.drag=nil
			if node then commit(routes.set(recipe,drag.source,drag.kind,node.index)) end;return self
		elseif (key=="WHEELUP" or key=="WHEELDOWN") and self:IsMouseOver() then layout();self.scroll=math.max(0,math.min(math.max(0,self.content-self.height),self.scroll+(key=="WHEELUP" and -100 or 100)));return self end
	end
	function canvas:OnFocusLost() self.drag=nil end
	button("graphAll",16,76,180,"Show all routes",function() all=not all end);c.graphAll.label=function() return all and "Show selected routes" or "Show all routes" end
	local steps={};for i,step in ipairs(recipe.steps) do steps[#steps+1]={label=i..". "..art.actionLabel(step),val=i} end
	c.graphStep=new("DropDownControl"):DropDownControl(ui.anchor,{208,76,w-224,28},steps,function(_,entry) selected=entry.val;layout();local node=canvas.nodes[selected];if node.y<0 or node.y+node.h>canvas.height then canvas.scroll=math.max(0,canvas.scroll+node.y-16) end end)
	c.graphStep.enabled=#steps>0
	ui.label(c,"legend",16,h-84,"S: success | F: failure / exhausted attempts | Final targets or action budget can stop the recipe early.",12)
	ui.label(c,"graphStatus",16,h-64,"",12)
	c.graphStatus.label=function()
		local text="Append an action in the recipe editor to start this graph."
		if selected then local parts={};for _,edge in ipairs(routes.edges(recipe)) do if edge.source==selected then parts[#parts+1]=edge.label.." -> "..(edge.target>#recipe.steps and "Finish" or "Step "..edge.target) end end;text="Step "..selected.." | "..table.concat(parts," | ") end
		return "^7"..ui.fit(text,w-32,14)
	end
	button("graphUndo",16,h-42,68,"Undo",function() recipe=history:step(true);options.change(copyTable(recipe)) end);c.graphUndo.enabled=function() return #history.undo>0 end
	button("graphRedo",96,h-42,68,"Redo",function() recipe=history:step(false);options.change(copyTable(recipe)) end);c.graphRedo.enabled=function() return #history.redo>0 end
	button("graphEdit",180,h-42,220,"Edit selected step",function() if selected then options.edit(selected) end end);c.graphEdit.enabled=function() return selected~=nil end
	button("close",w-156,h-42,140,"Back to recipe",function() main:ClosePopup() end)
	ui.style(c,{graphEdit=true});main:OpenPopup(w,h,"Crafting recipe flow graph",c,nil,nil,"close")
end
return M
