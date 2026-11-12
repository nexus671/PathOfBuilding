-- Native visual language for the filter workbench: ink panels, stone and loot labels.
local ui=require("Modules.PlanningUI")
local M={}
M.colors={Cyan={0.2,0.8,0.95},Red={0.95,0.25,0.2},Green={0.35,0.9,0.4},Blue={0.3,0.5,1},White={1,1,1},Yellow={1,0.9,0.2},Orange={1,0.55,0.2},Pink={1,0.4,0.75},Purple={0.7,0.4,1},Brown={0.6,0.4,0.2},Grey={0.6,0.6,0.6}}
local images={}
function M.image(path) if not images[path] then local image=NewImageHandle();image:Load(path);images[path]=image end;return images[path] end
function M.box(x,y,w,h,color) SetDrawColor(color);DrawImage(nil,x,y,w,h) end
function M.text(x,y,size,value,color,width)
	SetDrawColor(color or "^xDCE4EC");DrawString(x,y,"LEFT",size,"VAR",width and ui.fit(value,width,size) or value)
end
function M.floor(x,y,w,h)
	M.box(x,y,w,h,"^x111719")
	for row=0,math.ceil(h/46)-1 do for col=0,math.ceil(w/94)-1 do
		local left=x+col*94;local top=y+row*46;local shade=((row*17+col*31)%7)/500
		local tw,th=math.min(90,x+w-left-2),math.min(42,y+h-top-2)
		if tw>0 and th>0 then SetDrawColor(0.085+shade,0.105+shade,0.11+shade);DrawImage(nil,left+2,top+2,tw,th) end
		local edge=math.min(84,x+w-left-4)
		if edge>0 and y+h-top>3 then SetDrawColor(0.14+shade,0.16+shade,0.16+shade);DrawImage(nil,left+4,top+3,edge,1) end
	end end
	M.box(x,y,w,2,"^x536065");M.box(x,y+h-2,w,2,"^x273338")
end
function M.chip(x,y,w,h,item,result,selected)
	local styles=result and result.styles or {};local hidden=result and result.action=="Hide";local unknown=result and (result.status=="unknown" or result.status=="invalid")
	local size=math.max(14,math.min(26,math.floor((tonumber(styles.SetFontSize and styles.SetFontSize[1]) or 28)*0.65)))
	local name=item.BaseType or "Example item";while size>14 and DrawStringWidth(size,"VAR",name)>w-22 do size=size-1 end;name=ui.fit(name,w-22,size)
	local width=math.min(w-8,DrawStringWidth(size,"VAR",name)+18);local left=x+(w-width)/2;local top=y+(h-32)/2
	local function color(key,fallback) local value=styles[key] or fallback;SetDrawColor((tonumber(value[1]) or 255)/255,(tonumber(value[2]) or 255)/255,(tonumber(value[3]) or 255)/255,hidden and 0.35 or (tonumber(value[4]) or 255)/255) end
	if styles.PlayEffect and styles.PlayEffect[1]~="None" and not hidden then local color=M.colors[styles.PlayEffect[1]] or M.colors.Cyan
		for i=1,3 do SetDrawColor(color[1],color[2],color[3],0.12+i*0.08);DrawImage(nil,x+w/2-9+i*2,y+1,18-i*4,math.max(1,h/2-6)) end
	end
	if selected then M.box(left-3,top-3,width+6,38,"^xEAD29D") end
	color("SetBorderColor",{100,110,115});DrawImage(nil,left-1,top-1,width+2,34)
	color("SetBackgroundColor",{8,12,14});DrawImage(nil,left,top,width,32)
	color("SetTextColor",{220,225,215});DrawString(x+w/2,top+(32-size)/2,"CENTER_X",size,"VAR",name)
	if unknown then M.text(x+w-20,y+2,14,"?","^xE5B66A") end
	local icon=styles.MinimapIcon;if icon and tonumber(icon[1]) and tonumber(icon[1])>=0 and not hidden then
		local color=M.colors[icon[2]] or M.colors.White;SetDrawColor(unpack(color));local cx,cy=left+width-3,top-10
		if icon[3]=="Square" then DrawImage(nil,cx-4,cy-4,8,8)
		elseif icon[3]=="Triangle" then DrawImageQuad(nil,cx,cy-5,cx+5,cy+4,cx-5,cy+4,cx-5,cy+4)
		elseif icon[3]=="Circle" or icon[3]=="Star" then
			local count=icon[3]=="Star" and 10 or 12;local points={};for i=1,count do local radius=icon[3]=="Star" and i%2==0 and 2 or 5;local angle=(i-1)*math.pi*2/count-math.pi/2;points[i]={cx+math.cos(angle)*radius,cy+math.sin(angle)*radius} end
			for i=1,count do local a,b=points[i],points[i%count+1];DrawImageQuad(nil,cx,cy,a[1],a[2],b[1],b[2],b[1],b[2]) end
		else DrawImageQuad(nil,cx,cy-4,cx+4,cy,cx,cy+4,cx-4,cy) end
	end
end
function M.tile(control,entry,selected)
	local x,y=control:GetPos();local w,h=control:GetSize();local hovered=control:IsMouseOver()
	M.box(x,y,w,h,selected and "^xB19A68" or hovered and "^x637384" or "^x2C3945")
	M.box(x+1,y+1,w-2,h-2,selected and "^x263547" or "^x14202C")
	M.text(x+14,y+10,15,entry.rule.title,selected and "^xF3D89D" or "^xD9E3EE",w-28)
	M.text(x+14,y+h-24,12,entry.category.."  /  "..entry.tier,"^x9EAFC0",w-28)
end
function M.layers(controls,backgrounds)
	for key,control in pairs(controls) do if control.Draw then local draw=control.Draw
		function control:Draw(...) SetDrawLayer(nil,backgrounds and backgrounds[key] and 0 or 2);draw(self,...);SetDrawLayer(nil,0) end
	end end
end
return M
