-- Normalized HSV for the native colour picker; persisted colours remain RGBA bytes.
local M={}
local function finite(value) assert(type(value)=="number" and value==value and math.abs(value)<math.huge,"Invalid colour value");return value end
local function unit(value) return math.max(0,math.min(1,finite(value))) end
function M.rgba(value)
	assert(type(value)=="table","Use an RGB or RGBA colour")
	return require("Modules.LootFilterAppearanceSettings").validate({textColor={value[1],value[2],value[3],value[4] or 255}}).textColor
end
function M.toHSV(value,previousHue)
	local colour=M.rgba(value);local r,g,b=colour[1]/255,colour[2]/255,colour[3]/255
	local maximum,minimum=math.max(r,g,b),math.min(r,g,b);local delta=maximum-minimum;local hue=previousHue or 0
	if delta>0 then
		if maximum==r then hue=((g-b)/delta)%6 elseif maximum==g then hue=(b-r)/delta+2 else hue=(r-g)/delta+4 end;hue=hue/6
	end
	return finite(hue)%1,maximum==0 and 0 or delta/maximum,maximum,colour[4]
end
function M.fromHSV(hue,saturation,value,alpha)
	hue=finite(hue)%1;saturation=unit(saturation);value=unit(value);alpha=math.floor(math.max(0,math.min(255,finite(alpha or 255)))+0.5)
	local sector=hue*6;local chroma=value*saturation;local x=chroma*(1-math.abs(sector%2-1));local m=value-chroma
	local r,g,b
	if sector<1 then r,g,b=chroma,x,0 elseif sector<2 then r,g,b=x,chroma,0 elseif sector<3 then r,g,b=0,chroma,x
	elseif sector<4 then r,g,b=0,x,chroma elseif sector<5 then r,g,b=x,0,chroma else r,g,b=chroma,0,x end
	return {math.floor((r+m)*255+0.5),math.floor((g+m)*255+0.5),math.floor((b+m)*255+0.5),alpha}
end
return M
