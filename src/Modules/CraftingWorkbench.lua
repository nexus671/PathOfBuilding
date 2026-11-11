-- Presentation for the crafting workbench. All mutations stay in the simulator.
local M = { }
local anchor = {"TOPLEFT",nil,"TOPLEFT"}
local simulator = require("Modules.CraftingSimulator")
local artwork
local function image(path)
	local handle = NewImageHandle();handle:Load(path);return handle
end
local function text(x,y,size,value,color,width)
	while width and size>12 and DrawStringWidth(size,"VAR",value)>width do size=size-1 end
	if width and DrawStringWidth(size,"VAR",value)>width then
		while #value>0 and DrawStringWidth(size,"VAR",value.."...")>width do value=value:sub(1,-2) end
		value=value.."..."
	end
	SetDrawColor(color or "^xC8C8C8");DrawString(x,y,"LEFT",size,"VAR",value)
end
local function box(x,y,w,h,color)
	SetDrawColor(color);DrawImage(nil,x,y,w,h)
end
local function wrap(list,value,color,width)
	value=StripEscapes(value)
	while #value > 0 do
		local length=#value
		while length > 1 and DrawStringWidth(16,"VAR",value:sub(1,length)) > width do length=length-1 end
		if length < #value then length=value:sub(1,length):match("^.*()%s") or length end
		list[#list+1]={height=19,(color or "^x8888FF")..value:sub(1,length)}
		value=value:sub(length+1):gsub("^%s+","")
	end
end

-- Keep imagery honest: unknown bases use PoB's equipment silhouette, rather
-- than showing a different base's artwork.
local slots={Helmet="helmet",["Body Armour"]="body_armour",Gloves="gloves",Boots="boots",Shield="shield",Ring="ring_left",Amulet="amulet",Belt="belt",Quiver="quiver",Bow="bow"}
function M.item(controls,key,x,y,w,h,model,getState,onClick)
	if not artwork then
		local file=assert(io.open("Assets/Crafting/items.json","r"))
		artwork=assert(require("dkjson").decode(file:read("*a"))).bases;file:close()
	end
	local art,artWidth,artHeight,artPath
	local function setArt(item)
		local entry=artwork[item.baseName] or artwork[item.baseName:gsub(" %b()$","")]
		if entry and not entry.path then entry=nil end
		local path=entry and entry.path or "Assets/icon_"..(slots[item.type] or "weapon")..".png"
		if path ~= artPath then art=image(path);artPath=path end
		local scale=84/math.max(entry and entry.width or 84,entry and entry.height or 84)
		artWidth,artHeight=(entry and entry.width or 84)*scale,(entry and entry.height or 84)*scale
	end
	setArt(model.item)
	local card=new("ButtonControl"):ButtonControl(anchor,{x,y,w,180},"",onClick or function() end)
	controls[key]=card
	local mods=new("TextListControl"):TextListControl(anchor,{x,y+180,w,h-180},nil,{})
	controls[key.."Mods"]=mods
	function card:Draw()
		local cx,cy=self:GetPos();local state=getState();local item=self.preview or model.item
		local rarity=state.rarity or "NORMAL"
		local color=state.destroyed and "^xE07070" or rarity == "RARE" and "^xFFFF77" or rarity == "MAGIC" and "^x8888FF" or "^xC8C8C8"
		box(cx,cy,w,180,color);box(cx+1,cy+1,w-2,178,"^x101016")
		box(cx+2,cy+2,w-4,53,rarity == "RARE" and "^x302B18" or rarity == "MAGIC" and "^x1B1B30" or "^x232326")
		text(cx+16,cy+9,20,state.destroyed and "Item destroyed" or rarity == "RARE" and "Simulated craft" or item.baseName,color,w-32)
		text(cx+16,cy+33,16,rarity == "RARE" and item.baseName or rarity:sub(1,1)..rarity:sub(2):lower().." item",color,w-32)
		SetDrawColor(1,1,1,state.destroyed and 0.2 or 1);DrawImage(art,cx+12+(84-artWidth)/2,cy+66+(84-artHeight)/2,artWidth,artHeight)
		text(cx+110,cy+67,16,"Item level "..item.itemLevel)
		text(cx+110,cy+89,16,"Quality: +"..(state.quality or item.quality or 0).."%")
		text(cx+110,cy+111,16,self.defences or "",nil,w-126)
		local sockets=state.sockets or item.sockets or {}
		for i,socket in ipairs(sockets) do
			local sx=cx+110+(i-1)*24
			if i>1 and socket.group == sockets[i-1].group then box(sx-9,cy+139,12,3,"^xA68B59") end
			box(sx,cy+133,14,14,"^xA68B59")
			box(sx+2,cy+135,10,10,({R="^xE07070",G="^x70BB70",B="^x7070EE",W="^xEEEEEE"})[socket.color] or "^xC8C8C8")
		end
		text(cx+16,cy+159,14,state.destroyed and "Undo or reset to continue" or onClick and self:IsEnabled() and "Click the item to apply the selected currency" or "Outcome preview","^xD3B987")
	end
	local function refresh()
		local state=getState();local lines={}
		if state.destroyed then wrap(lines,"This item was destroyed.","^xE07070",w-30)
		else
			local context=simulator.context(model,state)
			card.preview=context.item;setArt(context.item)
			local item=simulator.toItem(model,state)
			local defences={}
			for _,property in ipairs({"Armour","Evasion","EnergyShield"}) do
				local value=item.armourData and item.armourData[property]
				if value and value>0 then defences[#defences+1]=(property == "EnergyShield" and "ES" or property)..": "..math.floor(value) end
			end
			card.defences=#defences>0 and table.concat(defences," / ") or nil
			for _,line in ipairs(item.implicitModLines or {}) do wrap(lines,itemLib.formatModLine(line,false) or line.line,"^x8888FF",w-30) end
			for _,line in ipairs(item.enchantModLines or {}) do wrap(lines,itemLib.formatModLine(line,false) or line.line,"^xB4B4FF",w-30) end
			if #lines>0 then lines[#lines+1]={height=12,""} end
			for _,entry in ipairs(state.affixes) do
				for _,line in ipairs(context.byId[entry.id] or {}) do
					wrap(lines,itemLib.applyRange(line,entry.range or 0.5),entry.fractured and "^xD6B677" or entry.crafted and "^xB4B4FF" or "^x8888FF",w-30)
				end
			end
			if #state.affixes == 0 then wrap(lines,"No explicit modifiers","^xAAAAAA",w-30) end
			if state.veil then wrap(lines,"Veiled modifier - select Unveil to reveal choices","^xD3B987",w-30) end
			if state.corrupted then wrap(lines,"Corrupted","^xE07070",w-30) end
			if (state.intangibility or 0)>0 then wrap(lines,"Intangibility: "..state.intangibility.."%","^xD3B987",w-30) end
			if (state.memoryStrands or 0)>0 then wrap(lines,"Memory strands: "..state.memoryStrands,"^xD3B987",w-30) end
		end
		mods.list=lines;mods.controls.scrollBar.offset=0
	end
	return refresh
end

local currencies={
	{"transmute","Transmute"},{"alteration","Alteration"},{"augmentation","Augment"},{"regal","Regal"},{"alchemy","Alchemy"},{"chaos","Chaos"},
	{"exalt","Exalted"},{"annul","Annul"},{"scour","Scour"},{"divine","Divine"},{"vaal","Vaal"},{"chromatic","Chromatic"},
}
function M.currencies(controls,selectMethod,currentMethod,isShown,usage)
	for i,entry in ipairs(currencies) do
		local method,caption=unpack(entry)
		local control=new("ButtonControl"):ButtonControl(anchor,{16+(i-1)%6*70,94+math.floor((i-1)/6)*65,66,61},"",function() selectMethod(method) end)
		controls["currency_"..method]=control;control.shown=isShown
		local art=image("Assets/Crafting/"..method..".png")
		control.tooltipText=simulator.labels[method] or caption
		function control:Draw(viewPort)
			local x,y=self:GetPos();local selected=currentMethod() == method
			box(x,y,66,61,selected and "^xD3B987" or self:IsMouseOver() and "^xAAAAAA" or "^x4E473A")
			box(x+1,y+1,64,59,selected and "^x302B20" or "^x18181C")
			SetDrawColor(1,1,1);DrawImage(art,x+14,y+2,38,38)
			SetDrawColor("^xDDDDDD");DrawString(x+33,y+44,"CENTER_X",13,"VAR",caption)
			local count=usage(method)
			if count>0 then text(x+48,y+3,12,tostring(count),"^xFFFF77") end
			if self:IsMouseOver() then self:DrawTooltip(x,y,66,61,viewPort) end
		end
	end
end
return M
