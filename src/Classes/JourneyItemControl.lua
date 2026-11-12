-- Compact comparison cards for ordinary and unique items, using local artwork.
local ui=require("Modules.PlanningUI")
local M={}
local artwork
function M.new(controls,key,x,y,w,h,label)
	if not artwork then local file=assert(io.open("Assets/Crafting/items.json","r"));artwork=require("dkjson").decode(file:read("*a")).bases;file:close() end
	local item,art,artW,artH
	local equipped=label=="EQUIPPED NOW"
	local starting=label=="STARTING ITEM"
	local card=new("Control"):Control(ui.anchor,{x,y,w,108});controls[key]=card
	local mods=new("TextListControl"):TextListControl(ui.anchor,{x,y+108,w,h-108},nil,{});controls[key.."Mods"]=mods
	local function fit(value,size,width) while #value>0 and DrawStringWidth(size,"VAR",value)>width do value=value:sub(1,-2) end;return value end
	function card:Draw()
		local cx,cy=self:GetPos();SetDrawColor("^x756647");DrawImage(nil,cx,cy,w,108);SetDrawColor("^x111923");DrawImage(nil,cx+1,cy+1,w-2,106)
		SetDrawColor("^x9BA9BA");DrawString(cx+10,cy+7,"LEFT",12,"VAR",label)
		SetDrawColor(item and (item.rarity=="UNIQUE" and "^xAF6025" or item.rarity=="RARE" and "^xFFFF77" or item.rarity=="MAGIC" and "^x8888FF") or "^xD5DEE8")
		DrawString(cx+10,cy+27,"LEFT",15,"VAR",fit(item and (item.title or item.baseName) or equipped and "Empty equipment slot" or starting and "No starting item" or "No target selected",15,w-20))
		if art then SetDrawColor(1,1,1);DrawImage(art,cx+10+(48-artW)/2,cy+52+(48-artH)/2,artW,artH) end
		SetDrawColor("^xD5DEE8");DrawString(cx+68,cy+54,"LEFT",13,"VAR",fit(item and item.baseName or equipped and "No item equipped" or starting and "Paste your starting item" or "Choose a target item",13,w-78))
		DrawString(cx+68,cy+76,"LEFT",13,"VAR",item and ("Item level "..tostring(item.itemLevel or "unknown")) or equipped and "Current baseline" or starting and "Or use the equipped item" or "Paste an item or link a craft")
	end
	return function(value,other)
		item=value;local lines={}
		if item then
			local entry=artwork[item.baseName];local path=entry and entry.path or "Assets/icon_weapon.png"
			art=NewImageHandle();art:Load(path);local scale=48/math.max(entry and entry.width or 84,entry and entry.height or 84);artW=(entry and entry.width or 84)*scale;artH=(entry and entry.height or 84)*scale
			local peer={};if other then for _,group in ipairs({other.implicitModLines or {},other.explicitModLines or {}}) do for _,mod in ipairs(group) do peer[mod.line]=true end end end
			for _,group in ipairs({item.implicitModLines or {},item.explicitModLines or {}}) do for _,mod in ipairs(group) do lines[#lines+1]={text=mod.line,changed=other and not peer[mod.line]} end end
		else art=nil;lines={equipped and "This slot is empty in the current build." or starting and "The base and its modifiers will appear here." or "An exact target item enables native upgrade measurements."} end
		local rows={};for _,line in ipairs(lines) do local changed=type(line)=="table" and line.changed;local text=type(line)=="table" and line.text or line
			for _,row in ipairs(ui.rows({(changed and (equipped and "- " or "+ ") or "")..text},w-24,13)) do if changed then row[1]=(equipped and "^xE58F8F" or "^x92D39C")..StripEscapes(row[1]) end;rows[#rows+1]=row end
		end
		mods.list=rows;mods.controls.scrollBar.offset=0
	end
end
return M
