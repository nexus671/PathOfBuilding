-- Compact comparison cards for ordinary and unique items, using local artwork.
local ui=require("Modules.PlanningUI")
local M={}
local artwork
function M.new(controls,key,x,y,w,h,label)
	if not artwork then local file=assert(io.open("Assets/Crafting/items.json","r"));artwork=require("dkjson").decode(file:read("*a")).bases;file:close() end
	local item,art,artW,artH
	local equipped=label=="EQUIPPED NOW"
	local card=new("Control"):Control(ui.anchor,{x,y,w,108});controls[key]=card
	local mods=new("TextListControl"):TextListControl(ui.anchor,{x,y+108,w,h-108},nil,{});controls[key.."Mods"]=mods
	local function fit(value,size,width) while #value>0 and DrawStringWidth(size,"VAR",value)>width do value=value:sub(1,-2) end;return value end
	function card:Draw()
		local cx,cy=self:GetPos();SetDrawColor("^x756647");DrawImage(nil,cx,cy,w,108);SetDrawColor("^x111923");DrawImage(nil,cx+1,cy+1,w-2,106)
		SetDrawColor("^x9BA9BA");DrawString(cx+10,cy+7,"LEFT",12,"VAR",label)
		SetDrawColor(item and (item.rarity=="UNIQUE" and "^xAF6025" or item.rarity=="RARE" and "^xFFFF77" or item.rarity=="MAGIC" and "^x8888FF") or "^xD5DEE8")
		DrawString(cx+10,cy+27,"LEFT",15,"VAR",fit(item and (item.title or item.baseName) or equipped and "Empty equipment slot" or "No target selected",15,w-20))
		if art then SetDrawColor(1,1,1);DrawImage(art,cx+10+(48-artW)/2,cy+52+(48-artH)/2,artW,artH) end
		SetDrawColor("^xD5DEE8");DrawString(cx+68,cy+54,"LEFT",13,"VAR",fit(item and item.baseName or equipped and "No item equipped" or "Choose a target item",13,w-78))
		DrawString(cx+68,cy+76,"LEFT",13,"VAR",item and ("Item level "..tostring(item.itemLevel or "unknown")) or equipped and "Current baseline" or "Paste an item or link a craft")
	end
	return function(value)
		item=value;local lines={}
		if item then
			local entry=artwork[item.baseName];local path=entry and entry.path or "Assets/icon_weapon.png"
			art=NewImageHandle();art:Load(path);local scale=48/math.max(entry and entry.width or 84,entry and entry.height or 84);artW=(entry and entry.width or 84)*scale;artH=(entry and entry.height or 84)*scale
			for _,group in ipairs({item.implicitModLines or {},item.explicitModLines or {}}) do for _,mod in ipairs(group) do lines[#lines+1]=mod.line end end
		else art=nil;lines={equipped and "This slot is empty in the current build." or "An exact target item enables native upgrade measurements."} end
		mods.list=ui.rows(lines,w-24,13);mods.controls.scrollBar.offset=0
	end
end
return M
