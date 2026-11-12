local M={colors={"Blue","Brown","Cyan","Green","Grey","Orange","Pink","Purple","Red","White","Yellow"},shapes={"Circle","Diamond","Hexagon","Square","Star","Triangle","Cross","Moon","Raindrop","Kite","Pentagon","UpsideDownHouse"}}
function M.validate(settings)
	assert(type(settings)=="table" and settings~=require("dkjson").null,"Invalid global appearance")
	local result={}
	for key,bounds in pairs({minimumFontSize={1,45},alertVolume={0,300},alertId={1,16}}) do local value=settings[key]
		if value~=nil then assert(type(value)=="number" and value==math.floor(value) and value>=bounds[1] and value<=bounds[2],"Invalid "..key);result[key]=value end
	end
	for _,key in ipairs({"disableEffects","disableIcons"}) do assert(settings[key]==nil or type(settings[key])=="boolean","Invalid "..key);result[key]=settings[key] end
	if settings.effectColor then local valid=false;for _,color in ipairs(M.colors) do if color==settings.effectColor then valid=true end end;assert(valid,"Invalid beam colour");result.effectColor=settings.effectColor end
	for _,key in ipairs({"textColor","borderColor","backgroundColor"}) do local value=settings[key]
		if value~=nil then
			assert(type(value)=="table" and #value==4,"Use four RGBA components for "..key);local copy={}
			for k in pairs(value) do assert(type(k)=="number" and k>=1 and k<=4 and k==math.floor(k),"Invalid colour array") end
			for k=1,4 do local v=value[k];assert(type(v)=="number" and v==math.floor(v) and v>=0 and v<=255,"Invalid colour component");copy[k]=v end;result[key]=copy
		end
	end
	return result
end
function M.fromHex(value)
	value=value:gsub("^#","");if not value:match("^%x+$") or #value~=6 and #value~=8 then return end
	local color={};for i=1,#value,2 do color[#color+1]=tonumber(value:sub(i,i+1),16) end;if #color==3 then color[4]=255 end;return color
end
function M.hex(color) local value="";for _,c in ipairs(color or {}) do value=value..string.format("%02X",c) end;return value end
return M
