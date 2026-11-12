-- Opt-in drawing and input adapter for headless control tests. No desktop input.
local M = { }
local fontNames = { VAR="Liberation Sans", ["VAR BOLD"]="Liberation Sans Bold", FIXED="Bitstream Vera Sans Mono",
	FONTIN="Fontin", ["FONTIN ITALIC"]="Fontin Italic", ["FONTIN SC"]="Fontin SmallCaps", ["FONTIN SC ITALIC"]="Fontin SmallCaps Italic" }
local palette = { [0]={0,0,0,1}, {1,0,0,1}, {0,1,0,1}, {1,1,0,1}, {0,0,1,1}, {0,1,1,1}, {1,0,1,1}, {1,1,1,1}, {0.5,0.5,0.5,1}, {1,0.5,0,1} }
local function escape(text)
	local hex = text:match("^%^x(%x%x%x%x%x%x)")
	if hex then return {tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,1},8 end
	local index = text:match("^%^(%d)")
	if index then return copyTable(palette[tonumber(index)]),2 end
end

function M.install(options)
	assert(launch and launch.headless,"HeadlessUI requires HeadlessWrapper; it cannot control a desktop")
	options = options or { }
	local ui = {width=options.width or 1280,height=options.height or 752,commands={},keys={},cursorX=-100,cursorY=-100,clock=0}
	local originals, fonts = { }, { }
	local images = setmetatable({},{__mode="k"})
	local previousWidth, previousHeight, previousViewport = main.screenW, main.screenH, main.viewPort
	local function replace(name, value) originals[name]=_G[name];_G[name]=value end
	local function font(height, name)
		local family = assert(fontNames[name],"Unknown headless font: "..tostring(name))
		if not fonts[family] then
			local file = assert(io.open((options.fontRoot or "../runtime/SimpleGraphic/Fonts").."/"..family..".tgf","r"))
			local sizes, current, index = { }, nil, 0
			for line in file:lines() do
				local size = tonumber(line:match("^HEIGHT (%d+)"))
				if size then current={height=size,glyphs={}};sizes[#sizes+1]=current;index=0
				else
					local x,y,w,left,right = line:match("^GLYPH%s+(%d+)%s+(%d+)%s+(%d+)%s+([%-0-9]+)%s+([%-0-9]+)")
					if x then current.glyphs[index]={tonumber(x),tonumber(y),tonumber(w),tonumber(left),tonumber(right)};index=index+1 end
				end
			end
			file:close();fonts[family]=sizes
		end
		local best=fonts[family][1]
		for _,size in ipairs(fonts[family]) do if math.abs(size.height-height)<math.abs(best.height-height) then best=size end end
		return best,family
	end
	local function measure(height, name, text)
		text=tostring(text):gsub("[\194-\244][\128-\191]*","?")
		local data=font(height,name);local width,maximum,index=0,0,1
		while index<=#text do
			local _,length=escape(text:sub(index))
			if length then index=index+length
			else
				local code=text:byte(index);local glyph=data.glyphs[code] or data.glyphs[63]
				if code==10 then maximum=math.max(maximum,width);width=0
				else width=math.ceil(width+(glyph[3]+glyph[4]+glyph[5])*(code==9 and 4 or 1)*height/data.height) end
				index=index+1
			end
		end
		return math.max(maximum,width)
	end
	local color, viewport, layer, sublayer = {1,1,1,1}, {0,0,ui.width,ui.height}, 0, 0
	local function record(command)
		command.color=copyTable(color);command.clip=copyTable(viewport);command.layer=layer;command.sublayer=sublayer
		command.order=#ui.commands+1;ui.commands[#ui.commands+1]=command
	end
	local nativeImage=NewImageHandle
	replace("NewImageHandle",function()
		local handle=nativeImage();local load=handle.Load
		function handle:Load(path,...) images[self]=path;return load(self,path,...) end
		return handle
	end)
	replace("GetScreenSize",function() return ui.width,ui.height end)
	replace("GetVirtualScreenSize",function() return ui.width,ui.height end)
	replace("GetCursorPos",function() return ui.cursorX,ui.cursorY end)
	replace("SetCursorPos",function(x,y) ui.cursorX,ui.cursorY=x,y end)
	replace("IsKeyDown",function(key) return ui.keys[key] or false end)
	replace("GetTime",function() return ui.clock end)
	replace("Copy",function(text) ui.clipboard=text end)
	replace("Paste",function() return ui.clipboard end)
	replace("DrawStringWidth",measure)
	replace("DrawStringCursorIndex",function(height,name,text,x)
		for i=1,#text do if measure(height,name,text:sub(1,i))>x then return i-1 end end
		return #text
	end)
	replace("SetDrawColor",function(r,g,b,a) color=type(r)=="string" and assert(escape(r),"Unknown colour escape") or {r,g,b,a or 1} end)
	replace("GetDrawColor",function() return unpack(color) end)
	replace("SetViewport",function(x,y,w,h) viewport=x and {x,y,w,h} or {0,0,ui.width,ui.height} end)
	replace("SetDrawLayer",function(value,sub) layer=value or layer;sublayer=sub or 0 end)
	replace("GetDrawLayer",function() return layer end)
	replace("DrawImage",function(handle,x,y,w,h,left,top,right,bottom)
		record({kind="rect",x=x+viewport[1],y=y+viewport[2],width=w,height=h,textured=handle~=nil,asset=images[handle],uv=left and {left,top,right,bottom} or nil})
	end)
	replace("DrawImageQuad",function(handle,...)
		local points={...};for i=1,8,2 do points[i]=points[i]+viewport[1];points[i+1]=points[i+1]+viewport[2] end
		record({kind="polygon",points=points,textured=handle~=nil})
	end)
	replace("DrawString",function(x,y,align,height,name,text)
		text=tostring(text):gsub("[\194-\244][\128-\191]*","?")
		local width=measure(height,name,text)
		if align=="CENTER" then x=math.floor((viewport[3]-width)/2+x)
		elseif align=="RIGHT" then x=math.floor(viewport[3]-width-x)
		elseif align=="CENTER_X" then x=math.floor(x-width/2)
		elseif align=="RIGHT_X" then x=math.floor(x-width) end
		local size,family=font(height,name)
		record({kind="text",x=math.floor(x+0.5)+viewport[1],y=math.floor(y)+viewport[2],width=width,height=height,
			font=family,fontHeight=size.height,text=text})
		local index=1
		while index<=#text do local nextColor,length=escape(text:sub(index));if length then color=nextColor;index=index+length else index=index+1 end end
	end)
	main.screenW,main.screenH=ui.width,ui.height
	main.viewPort={x=0,y=0,width=ui.width,height=ui.height}
	function ui:bind(host) self.boundHost=host;return self end
	function ui:resize(width,height)
		self.width,self.height=width,height;main.screenW,main.screenH=width,height
		main.viewPort={x=0,y=0,width=width,height=height}
		return self
	end
	function ui:activeHost()
		if main.popups[1] then return main.popups[1] end
		if self.boundHost and self.boundHost.OnFrame then return main.modes.BUILD end
		return assert(self.boundHost,"No popup or bound UI host")
	end
	local function controlsFor(host)
		local controls={}
		for key,control in pairs(host.controls or {}) do if host.viewMode~="PLANNER" or select(2,control:GetPos())<32 then controls[key]=control end end
		if host.viewMode=="PLANNER" and host.planningWorkspace then
			for key,control in pairs(host.planningWorkspace.controls) do controls[key]=control end
		end
		return controls
	end
	function ui:dispatch(host,events)
		if host.OnFrame then host:OnFrame(events) elseif host.ProcessInput then host:ProcessInput(events,main.viewPort) else host:ProcessControlsInput(events,main.viewPort) end
	end
	function ui:frame(host)
		self.commands={};color={1,1,1,1};viewport={0,0,self.width,self.height};layer,sublayer=0,0
		self.clock=self.clock+16
		host=host or self:activeHost()
		if type(host)=="function" then host(main.viewPort);host={} elseif host.OnFrame then host:OnFrame({}) else host:Draw(main.viewPort,{}) end
		self.controls={};self.regions={}
		for key,control in pairs(controlsFor(host)) do if control:IsShown() then
			local x,y=control:GetPos();local w,h=control:GetSize()
			if control.columns and control.list then self.regions[#self.regions+1]={x,y,w,h} end
			self.controls[#self.controls+1]={key=key,x=x,y=y,width=w,height=h,group=control.layoutAudit,enabled=control:IsEnabled() and true or false}
		end end
		table.sort(self.controls,function(a,b) return tostring(a.key)<tostring(b.key) end)
		return self
	end
	function ui:click(key)
		local host=self:activeHost();local control=assert(controlsFor(host)[key],"Unknown control "..key)
		assert(control:IsShown() and control:IsEnabled(),"Control is hidden or disabled: "..key)
		local x,y=control:GetPos();local w,h=control:GetSize()
		assert(x>=0 and y>=0 and x+w<=self.width and y+h<=self.height,"Control is outside the window: "..key)
		self.cursorX,self.cursorY=x+w/2,y+h/2
		self:dispatch(host,{{type="KeyDown",key="LEFTBUTTON"}},main.viewPort)
		self:dispatch(host,{{type="KeyUp",key="LEFTBUTTON"}},main.viewPort)
		return self
	end
	function ui:key(key)
		local host=self:activeHost()
		self:dispatch(host,{{type="KeyDown",key=key}},main.viewPort)
		self:dispatch(host,{{type="KeyUp",key=key}},main.viewPort)
		return self
	end
	function ui:clickAt(x,y,doubleClick)
		self.cursorX,self.cursorY=x,y;self:frame()
		local host=self:activeHost()
		self:dispatch(host,{{type="KeyDown",key="LEFTBUTTON",doubleClick=doubleClick}})
		self:dispatch(host,{{type="KeyUp",key="LEFTBUTTON"}})
		return self
	end
	function ui:dragAt(x,y,dx,dy)
		self.cursorX,self.cursorY=x,y;self:frame()
		local host=self:activeHost()
		self:dispatch(host,{{type="KeyDown",key="RIGHTBUTTON"}})
		self.cursorX,self.cursorY=x+dx,y+dy;self:frame()
		self:dispatch(host,{{type="KeyUp",key="RIGHTBUTTON"}})
		return self
	end
	function ui:choose(key,value,member)
		local host=self:activeHost();local control=assert(controlsFor(host)[key]);local target
		for i,entry in ipairs(control.list) do if (member and entry[member] or entry)==value then target=i;break end end
		assert(target,"Dropdown choice not found: "..tostring(value));if control.tabKeys then return self:click(assert(control.tabKeys[value],"Missing navigation tab")) end;self:click(key)
		local attempts=0
		while control.selIndex~=target do
			attempts=attempts+1;assert(attempts<=#control.list+1,"Dropdown selection did not advance")
			self:key(control.selIndex<target and "DOWN" or "UP")
			if self:activeHost()~=host then return self end
		end
		self:key("ESCAPE");return self
	end
	function ui:text(key,text)
		self:click(key);self.keys.CTRL=true;self:key("a");self.keys.CTRL=nil
		if text=="" then self:key("BACK") end
		local host=self:activeHost()
		for char in text:gmatch("[\1-\127\194-\244][\128-\191]*") do self:dispatch(host,{{type="Char",key=char}},main.viewPort) end
		return self
	end
	function ui:write(path)
		local file=assert(io.open(path,"w"));file:write(require("dkjson").encode({schemaVersion=1,width=self.width,height=self.height,
			commands=self.commands,controls=self.controls,regions=self.regions,limitations={"Text uses bundled bitmap-font metrics and atlases. Untracked textures and non-ASCII glyphs are placeholders; this is not a GPU screenshot."}}));file:close()
	end
	function ui:restore()
		for name,value in pairs(originals) do _G[name]=value end
		main.screenW,main.screenH,main.viewPort=previousWidth,previousHeight,previousViewport
	end
	return ui
end
return M
