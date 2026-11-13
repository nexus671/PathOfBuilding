local ui=require("Modules.PlanningUI")
local policy=require("Modules.LootFilterCampaign")
local visual=require("Modules.LootFilterVisuals")
local art=require("Modules.CraftingWorkbench")
local M={}
local names={
	["One Handed Axe"]="1H axes",["One Handed Mace"]="1H maces",["One Handed Sword"]="1H swords",["Two Handed Axe"]="2H axes",["Two Handed Mace"]="2H maces",["Two Handed Sword"]="2H swords",
	["Thrusting Sword"]="Thrusting swords",["Rune Dagger"]="Rune daggers",["Fishing Rod"]="Fishing rods",["Energy shield"]="Energy shield",["Armour / Energy shield"]="Armour / ES",["Evasion / Energy shield"]="Evasion / ES",["All three defences"]="Armour / Evasion / ES",
}
function M.Open(build,value,onKeep)
	local current=policy.validate(value or policy.defaults());local selected={weapons={},defences={},recipes={}};local c={};local custom={}
	local w,h=math.min(1080,main.screenW-40),math.min(700,main.screenH-60);local column=math.floor((w-48)/2);local right=column+32
	local function selections(next) for key in pairs(selected) do selected[key]={};for _,name in ipairs(next[key]) do selected[key][name]=true end end end;selections(current)
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	ui.description(c,"help",16,28,w-212,48,{"Choose the base families and recipe pickups you want. These Show rules supplement your preset; personal rules and tiers keep priority. Nothing is automatically hidden."},14)
	button("enabled",w-180,28,164,"",function() current.enabled=not current.enabled end);c.enabled.label=function() return current.enabled and "Policy enabled" or "Policy disabled" end;c.enabled.locked=function() return current.enabled end
	local fields={{"minAreaLevel","From area",1},{"maxAreaLevel","Through area",70},{"minDropLevel","Minimum base level",0},{"minLinks","Minimum links",0},{"upgradeWindow","Upgrade window",15}}
	local fieldWidth=math.floor((w-48)/6)
	for i,field in ipairs(fields) do local key,title=field[1],field[2];local x=16+(i-1)*(fieldWidth+4);ui.label(c,key.."Label",x,96,title,12)
		c[key]=new("EditControl"):EditControl(ui.anchor,{x,120,fieldWidth-4,28},tostring(current[key]),nil,"%D",3)
	end
	button("equipped",16+5*(fieldWidth+4),120,w-32-5*(fieldWidth+4),"Use equipped",function() selections(policy.equipped(build)) end)
	c.upgradeWindow.tooltipText="0 keeps every selected base. Otherwise, five-area bands raise the required base DropLevel as you progress. A band starts at area level minus this window."
	c.minDropLevel.tooltipText="The game's base DropLevel, rather than the item's character requirements. Applies to base families, not recipe pickups."
	ui.label(c,"weaponsLabel",16,162,"Weapons, shields and quivers",16);ui.label(c,"defencesLabel",right,162,"Armour families",16)
	local families=policy.families()
	for _,group in ipairs({{"weapons",policy.weapons,16,column,3},{"defences",policy.defences,right,column,2}}) do
		local key,choices,x,width,cols=unpack(group);local tile=math.floor((width-(cols-1)*6)/cols)
		for i,name in ipairs(choices) do local id=key..i;local px,py=x+(i-1)%cols*(tile+6),188+math.floor((i-1)/cols)*44
			button(id,px,py,tile,"",function() selected[key][name]=not selected[key][name] or nil end);local control=c[id];control.height=38;control.planningFocusable=true;custom[id]=true;control.tooltipText=name.." | "..#(families[key][name] or {}).." bundled bases"
			local path,iw,ih;local baseName=(families[key][name] or {})[1];if baseName then local base=data.itemBases[baseName];path,iw,ih=art.itemArt({baseName=baseName,type=base.type}) end
			function control:Draw()
				local x,y=self:GetPos();local active=selected[key][name];visual.box(x,y,tile,38,self.hasFocus and "^x83C8EF" or active and "^xC7AD74" or "^x3F566F");visual.box(x+1,y+1,tile-2,36,active and "^x302B20" or "^x192635")
				if path then local scale=24/math.max(iw,ih);SetDrawColor(1,1,1);DrawImage(visual.image(path),x+6+(24-iw*scale)/2,y+7,iw*scale,ih*scale) end
				visual.text(x+36,y+12,12,names[name] or name,active and "^xF3D89D" or "^xD5DEE8",tile-42)
			end
		end
	end
	ui.label(c,"recipesLabel",right,378,"Recipe and socket pickups",14)
	for i,name in ipairs(policy.recipes) do
		button("recipe"..i,right,404+(i-1)*26,column,name,function() selected.recipes[name]=not selected.recipes[name] or nil end);c["recipe"..i].height=22;c["recipe"..i].locked=function() return selected.recipes[name] end
	end
	local function read()
		local next=copyTable(current)
		for key,values in pairs(selected) do next[key]={};for name in pairs(values) do next[key][#next[key]+1]=name end end
		for _,field in ipairs(fields) do next[field[1]]=assert(tonumber(c[field[1]].buf),"Enter every level/link setting") end;return policy.validate(next)
	end
	ui.description(c,"summary",16,h-112,column,64,{"Upgrade windows use five-area bands. Recipe pickups follow only the area range. No vendor proceeds, hidden modifiers or economy value are assumed."},13)
	button("keep",16,h-42,220,"Keep pickup policy",function() local next=read();policy.rules(next);onKeep(next);main:ClosePopup() end)
	button("reset",252,h-42,180,"Remove policy",function() onKeep(nil);main:ClosePopup() end)
	button("close",w-156,h-42,140,"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keep=true},custom);for _,control in pairs(c) do control.layoutAudit="filter-campaign-policy" end;main:OpenPopup(w,h,"Campaign and base-family pickups",c,nil,nil,"close");return c
end
return M
