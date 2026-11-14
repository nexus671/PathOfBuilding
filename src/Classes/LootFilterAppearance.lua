-- cspell:ignore FFAE
local ui=require("Modules.PlanningUI")
local library=require("Modules.LootFilterLibrary")
local parser=require("Modules.LootFilterParser")
local visual=require("Modules.LootFilterVisuals")
local appearance=require("Modules.LootFilterAppearanceSettings")
local M={}
local function button(c,key,x,y,w,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,w,28},label,run) end
function M.Open(rule,save,conditions,options)
	options=options or {}
	local c={};local w,h=math.min(880,main.screenW-40),math.min(580,main.screenH-60)
	local original=parser.parse(rule.text).rules[1];local changes={};local sample=library.sample(rule)
	local function nextRule() local next=library.appearance(rule,changes);next.title=c.title.buf;return next end
	ui.label(c,"heading",16,24,"Make this drop yours",22)
	c.title=new("EditControl"):EditControl(ui.anchor,{16,56,w-200,28},rule.title,nil,nil,160)
	c.action=new("DropDownControl"):DropDownControl(ui.anchor,{w-168,56,152,28},{"Show","Hide","Minimal"});c.action:SelByValue(original.action)
	c.preview=new("Control"):Control(ui.anchor,{16,100,w-32,112})
	function c.preview:Draw() local x,y=self:GetPos();local width,height=self:GetSize();visual.floor(x,y,width,height);visual.chip(x+width*0.2,y+8,width*0.6,height-8,sample,{action=c.action:GetSelValue(),styles=parser.parse(nextRule().text).rules[1].styles}) end
	local palette={"FFFFFF","F2D59A","EF6A62","FFAE57","61D8ED","7BD89B","7C9FF2","BE8CE8"}
	local defaultText=copyTable(visual.defaultTextColor(sample));defaultText[4]=255
	local columns={{"textHex","Text colour","SetTextColor",defaultText},{"borderHex","Border colour","SetBorderColor",{120,140,150,255}},{"backgroundHex","Background","SetBackgroundColor",{8,12,14,255}}}
	local column=math.floor((w-64)/3);local custom={}
	local function decode(value)
		value=value:gsub("^#","");if not value:match("^%x+$") or #value~=6 and #value~=8 then return nil end
		local rgba={};for i=1,#value,2 do rgba[#rgba+1]=tostring(tonumber(value:sub(i,i+1),16)) end;if #rgba==3 then rgba[4]="255" end;return rgba
	end
	for index,entry in ipairs(columns) do local key,label,style,fallback=unpack(entry);local x=16+(index-1)*(column+16)
		ui.label(c,key.."Label",x,232,label,16)
		local value=appearance.rgba(style,original.styles[style] or fallback);local hex="";for i=1,4 do hex=hex..string.format("%02X",value[i]) end
		c[key]=new("EditControl"):EditControl(ui.anchor,{x,350,column-76,28},hex,nil,nil,9,function(value) local rgba=decode(value);if rgba then changes[style]=rgba end end)
		button(c,key.."Pick",x+column-68,350,68,"Pick",function()
			local values=decode(c[key].buf) or original.styles[style] or fallback;local rgba=appearance.rgba(style,values)
			require("Classes.ColourPickerControl").Open(rgba,function(colour) c[key]:SetText(require("Modules.LootFilterAppearanceSettings").hex(colour),true) end,{title=label,minimumAlpha=style=="SetTextColor" and options.mode=="Ruthless" and 80 or 0})
		end)
		for i,color in ipairs(palette) do local name=key.."Color"..i;local control=new("ButtonControl"):ButtonControl(ui.anchor,{x+((i-1)%4)*44,262+math.floor((i-1)/4)*40,34,32},"",function() c[key]:SetText(color.."FF");changes[style]=decode(color.."FF") end)
			c[name]=control;custom[name]=true;control.planningFocusable=true;control.tooltipText=label.." #"..color
			function control:Draw() local cx,cy=self:GetPos();visual.box(cx,cy,34,32,self.hasFocus and "^xF3D89D" or self:IsMouseOver() and "^xDAE4EE" or "^x4B5968");local rgb=decode(color);SetDrawColor(tonumber(rgb[1])/255,tonumber(rgb[2])/255,tonumber(rgb[3])/255);DrawImage(nil,cx+3,cy+3,28,26) end
		end
	end
	ui.label(c,"hexHint",16,386,"Hex colours include opacity in the final two digits (FF = solid).",14)
	ui.label(c,"sizeLabel",16,414,"Label size",14)
	c.size=new("SliderControl"):SliderControl(ui.anchor,{16,440,column,24},function(value) changes.SetFontSize={tostring(math.floor(1+value*44+0.5))} end);c.size.val=math.max(0,math.min(1,((tonumber(original.styles.SetFontSize and original.styles.SetFontSize[1]) or 32)-1)/44))
	c.sizeLabel.label=function() return "^7Label size: "..tostring(changes.SetFontSize and changes.SetFontSize[1] or original.styles.SetFontSize and original.styles.SetFontSize[1] or 32) end
	ui.label(c,"soundLabel",32+column,414,"Drop sound",14)
	local sounds={"Keep sound","Silent"};for i=1,16 do sounds[#sounds+1]="Alert "..i end
	c.sound=new("DropDownControl"):DropDownControl(ui.anchor,{32+column,440,column,26},sounds,function(index)
		if index==1 then changes.PlayAlertSound=nil;changes.CustomAlertSound=nil;changes.CustomAlertSoundOptional=nil;changes.PlayAlertSoundPositional=nil
		else if index==2 then changes.PlayAlertSound={"None"};changes.CustomAlertSound={"None"} else changes.PlayAlertSound={tostring(index-2),"200"};changes.CustomAlertSound=false end;changes.CustomAlertSoundOptional=false;changes.PlayAlertSoundPositional=false end
	end)
	ui.label(c,"iconLabel",48+column*2,414,"Map icon",14)
	local shapes={"Keep icon","None"};for _,shape in ipairs(require("Modules.LootFilterAppearanceSettings").shapes) do shapes[#shapes+1]=shape end
	c.icon=new("DropDownControl"):DropDownControl(ui.anchor,{48+column*2,440,column,26},shapes,function(index,value) local prior=original.styles.MinimapIcon;if index==1 then changes.MinimapIcon=nil elseif index==2 then changes.MinimapIcon={"-1"} else changes.MinimapIcon={prior and prior[1]~="-1" and prior[1] or "1",prior and prior[2] or "Cyan",value} end end)
	button(c,"effects",16,482,w-32,"More sound, icon and beam options",function()
		require("Classes.LootFilterEffectsControl").Open(parser.parse(nextRule().text).rules[1].styles,sample,function(styles)
			for _,key in ipairs({"PlayAlertSound","PlayAlertSoundPositional","CustomAlertSound","CustomAlertSoundOptional","MinimapIcon","PlayEffect"}) do changes[key]=styles[key] or false end
			c.sound:SelByValue("Keep sound");c.icon:SelByValue("Keep icon")
		end)
	end)
	button(c,"conditions",16,h-48,180,"Advanced conditions",function() local next=nextRule();next.text=next.text:gsub("^%a+",c.action:GetSelValue());main:ClosePopup();conditions(next,save) end)
	button(c,"cancel",w-320,h-48,140,"Cancel",function() main:ClosePopup() end)
	button(c,"keepRule",w-164,h-48,148,"Keep appearance",function()
		for _,entry in ipairs(columns) do assert(decode(c[entry[1]].buf),"Enter a valid hex colour") end
		local next=nextRule();next.text=next.text:gsub("^%a+",c.action:GetSelValue());save(next);main:ClosePopup()
	end)
	ui.style(c,{keepRule=true},custom);visual.layers(c,{preview=true});main:OpenPopup(w,h,"Drop appearance",c,nil,"title","cancel")
end
return M
