-- cspell:ignore FFAE
local ui=require("Modules.PlanningUI")
local colourMath=require("Modules.ColourMath")
local appearance=require("Modules.LootFilterAppearanceSettings")
local visual=require("Modules.LootFilterVisuals")
local M={}
function M.Open(initial,onKeep,options)
	options=options or {};local minimum=options.minimumAlpha or 0;assert(type(minimum)=="number" and minimum>=0 and minimum<=255 and minimum==math.floor(minimum),"Invalid minimum opacity")
	local colour=colourMath.rgba(initial);colour[4]=math.max(minimum,colour[4]);local hue,saturation,value,alpha=colourMath.toHSV(colour)
	local c={};local custom={wheel=true,value=true,alpha=true,preview=true};local w,h=660,560
	local keep,sync;local keys={"r","g","b","a"}
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	local function tooltip(control,viewport)
		if not control.dragging and control:IsMouseOver() then local x,y=control:GetPos();local width,height=control:GetSize();SetDrawLayer(nil,100);control:DrawTooltip(x,y,width,height,viewport or main.viewPort);SetDrawLayer(nil,0) end
	end
	local function valid()
		local hex=appearance.fromHex(c.hex.buf);if not hex or hex[4]<minimum then return false end
		for i,key in ipairs(keys) do local n=tonumber(c[key].buf);if not n or n~=math.floor(n) or n<(i==4 and minimum or 0) or n>255 then return false end end;return true
	end
	local function rgba(next,skip)
		colour=colourMath.rgba(next);hue,saturation,value,alpha=colourMath.toHSV(colour,hue);if sync then sync(skip) end
	end
	local function hsv()
		saturation=math.max(0,math.min(1,saturation));value=math.max(0,math.min(1,value));alpha=math.max(minimum,math.min(255,alpha));hue=hue%1
		colour=colourMath.fromHSV(hue,saturation,value,alpha);alpha=colour[4];if sync then sync() end
	end
	ui.description(c,"help",16,28,w-32,40,{"Drag the colour wheel, brightness or opacity bars. Arrow keys adjust a focused selector. Keep colour returns to the editor; Cancel leaves it unchanged."},14)
	ui.label(c,"valueLabel",292,70,"Light",13);ui.label(c,"alphaLabel",340,70,"Alpha",13)
	local function selector(key,x,y,width,height,point,adjust,draw)
		button(key,x,y,width,"",function() end);local control=c[key];control.height=height;control.planningFocusable=true
		function control:OnKeyDown(pressed)
			if pressed=="ESCAPE" then self.dragging=false;main:ClosePopup();return end
			if pressed=="LEFTBUTTON" then self.dragging=false;if not self:IsMouseOver() or key=="wheel" and not point(true) then return end;self.dragging=true;point();return self end
			if pressed=="UP" or pressed=="DOWN" or pressed=="LEFT" or pressed=="RIGHT" then adjust(pressed);hsv();return self end
			return self
		end
		function control:OnKeyUp(pressed) if pressed=="LEFTBUTTON" then if self.dragging then point() end;self.dragging=false end;return self end
		local lost=control.OnFocusLost;function control:OnFocusLost() self.dragging=false;if lost then lost(self) end end
		function control:Draw(viewport) if self.dragging then if IsKeyDown("LEFTBUTTON") then point() else self.dragging=false end end;draw(self);tooltip(self,viewport) end
		control.planningActivate=function() keep() end
	end
	local function wheelPoint(check)
		local x,y=c.wheel:GetPos();local mx,my=GetCursorPos();local dx,dy=mx-x-128,my-y-128;local distance=math.sqrt(dx*dx+dy*dy)
		if check then return distance<=127 end
		if distance>0 then hue=math.atan2(dy,dx)/(2*math.pi) end;saturation=math.min(1,distance/127);hsv()
	end
	selector("wheel",16,84,256,256,wheelPoint,function(key) if key=="LEFT" then hue=hue-1/360 elseif key=="RIGHT" then hue=hue+1/360 elseif key=="UP" then saturation=saturation+0.01 else saturation=saturation-0.01 end end,function(control)
		local x,y=control:GetPos();SetDrawColor(value,value,value,1);DrawImage(visual.image("Assets/LootFilters/colour-wheel.png"),x,y,256,256)
		local px,py=x+128+math.cos(hue*2*math.pi)*saturation*127,y+128+math.sin(hue*2*math.pi)*saturation*127
		visual.box(px-6,py-6,12,12,"^x101010");visual.box(px-5,py-5,10,10,"^xFFFFFF");SetDrawColor(colour[1]/255,colour[2]/255,colour[3]/255,1);DrawImage(nil,px-3,py-3,6,6)
	end)
	c.wheel.tooltipText="Left / Right: hue. Up / Down: saturation. Enter keeps the colour."
	local function barPoint(key)
		local _,y=c[key]:GetPos();local _,my=GetCursorPos();local fraction=math.max(0,math.min(1,(my-y)/256))
		if key=="value" then value=1-fraction else alpha=minimum+(1-fraction)*(255-minimum) end;hsv()
	end
	local function marker(x,y,position) visual.box(x-3,y+math.max(0,math.min(255,position))-2,34,5,"^x101010");visual.box(x-2,y+math.max(0,math.min(255,position))-1,32,3,"^xFFFFFF") end
	selector("value",296,84,28,256,function() barPoint("value") end,function(key) value=value+((key=="UP" or key=="RIGHT") and 0.01 or -0.01) end,function(control)
		local x,y=control:GetPos();local full=colourMath.fromHSV(hue,saturation,1);SetDrawColor(full[1]/255,full[2]/255,full[3]/255,1);DrawImage(visual.image("Assets/LootFilters/colour-value.png"),x,y,28,256);marker(x,y,(1-value)*255)
	end)
	c.value.tooltipText="Brightness: top is fully bright; bottom is black. Arrow keys adjust it."
	selector("alpha",344,84,28,256,function() barPoint("alpha") end,function(key) alpha=alpha+((key=="UP" or key=="RIGHT") and 1 or -1) end,function(control)
		local x,y=control:GetPos();SetDrawColor(1,1,1);DrawImage(visual.image("Assets/LootFilters/colour-checker.png"),x,y,28,256,0,0,28/512,256/512)
		SetDrawColor(colour[1]/255,colour[2]/255,colour[3]/255,1);DrawImage(visual.image("Assets/LootFilters/colour-alpha.png"),x,y,28,256,0,0,1,math.max(1/256,1-minimum/255))
		marker(x,y,minimum==255 and 0 or (255-alpha)/(255-minimum)*255)
	end)
	c.alpha.tooltipText="Opacity: top is solid. Minimum alpha: "..minimum..". Arrow keys adjust it."
	ui.label(c,"previewLabel",400,84,"Selected colour",14)
	c.preview=new("Control"):Control(ui.anchor,{400,112,244,80})
	function c.preview:Draw() local x,y=self:GetPos();SetDrawColor(1,1,1);DrawImage(visual.image("Assets/LootFilters/colour-checker.png"),x,y,244,80,0,0,244/512,80/512);SetDrawColor(colour[1]/255,colour[2]/255,colour[3]/255,colour[4]/255);DrawImage(nil,x,y,244,80) end
	ui.label(c,"hexLabel",400,210,"Hex RGB / RGBA",14)
	c.hex=new("EditControl"):EditControl(ui.anchor,{400,234,244,28},appearance.hex(colour),nil,nil,9,function(text) local next=appearance.fromHex(text);if next and next[4]>=minimum then rgba(next,"hex") end end)
	for i,key in ipairs(keys) do local y=282+(i-1)*34;ui.label(c,key.."Label",400,y,({"Red","Green","Blue",minimum>0 and "Alpha ("..minimum.."-255)" or "Alpha"})[i],14)
		c[key]=new("EditControl"):EditControl(ui.anchor,{528,y-4,116,28},tostring(colour[i]),nil,"%D",3,function(text)
			local n=tonumber(text);if n and n==math.floor(n) and n>=(i==4 and minimum or 0) and n<=255 then local next=copyTable(colour);next[i]=n;rgba(next,key) end
		end)
	end
	sync=function(skip) if skip~="hex" then c.hex:SetText(appearance.hex(colour)) end;for i,key in ipairs(keys) do if skip~=key then c[key]:SetText(tostring(colour[i])) end end end
	ui.label(c,"wheelValues",16,360,"",13);c.wheelValues.label=function() return "^7Hue "..math.floor(hue*360+0.5).." / saturation "..math.floor(saturation*100+0.5).."% / light "..math.floor(value*100+0.5).."%" end
	ui.label(c,"presetLabel",16,394,"Quick colours",14)
	local presets={"FFFFFF","000000","EF6A62","FFAE57","F2D59A","7BD89B","61D8ED","BE8CE8"}
	for i,hex in ipairs(presets) do local key="preset"..i;custom[key]=true;local next=appearance.fromHex(hex);button(key,16+(i-1)*44,420,36,"",function() local chosen=copyTable(next);chosen[4]=alpha;rgba(chosen) end);c[key].height=30;c[key].planningFocusable=true;c[key].tooltipText="#"..hex
		local control=c[key];function control:Draw(viewport) local x,y=self:GetPos();visual.box(x,y,36,30,self.hasFocus and "^x83C8EF" or "^xA0A0A0");SetDrawColor(next[1]/255,next[2]/255,next[3]/255,1);DrawImage(nil,x+2,y+2,32,26);tooltip(self,viewport) end
	end
	ui.label(c,"status",16,478,"",13);c.status.label=function() return "^7"..(valid() and "Keep returns this RGBA colour to the editor." or "Use complete hex and RGB values 0-255; alpha must be "..minimum.."-255.") end
	keep=function() if valid() then onKeep(copyTable(colour));main:ClosePopup() end end
	c.hex.enterFunc=keep;for _,key in ipairs(keys) do c[key].enterFunc=keep end
	button("keep",16,514,220,"Keep colour",keep);c.keep.enabled=valid
	button("cancel",w-156,514,140,"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keep=true},custom);for _,control in pairs(c) do control.layoutAudit="colour-picker" end;main:OpenPopup(w,h,options.title or "Choose colour",c,"keep","hex","cancel");return c
end
return M
