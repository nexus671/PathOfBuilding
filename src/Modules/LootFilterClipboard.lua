-- Read visible clipboard properties only. Hidden affix identities remain unknown.
-- cspell:ignore RGBWAD
local M={}
function M.parse(raw,area)
	assert(type(raw)=="string" and #raw>0 and #raw<=24000 and not raw:find("\0"),"Paste a copied game item (up to 24 KiB)")
	raw=raw:gsub("\r\n","\n");local rarity=assert(raw:match("Rarity: (%a+)"),"The clipboard has no item rarity")
	local header=raw:match("Rarity: [^\n]+\n(.-)\n%-%-%-%-%-%-%-%-") or raw:match("Rarity: [^\n]+\n(.*)")
	local names={};for line in (header or ""):gmatch("[^\n]+") do if line=="--------" or line:match("^[%w ]+: ") then break end;names[#names+1]=line end
	assert(#names>0,"The clipboard has no item name")
	local ok,native=pcall(function() return new("Item"):Item(raw) end)
	local base=ok and native.base and native.baseName or nil
	if not base then
		assert(rarity:lower()~="magic","The magic item's base could not be identified; configure it explicitly")
		base=names[#names]
	end
	local class=raw:match("Item Class: ([^\n]+)")
	-- The clipboard's gem labels differ from the filter language's class names.
	class=({["Active Skill Gems"]="Skill Gems",["Support Skill Gems"]="Support Gems"})[class] or class
	local markers={};for line in raw:gmatch("[^\n]+") do markers[line]=true end
	local mapped={normal="Normal",magic="Magic",rare="Rare",unique="Unique",relic="Unique",currency="Normal",gem="Normal",quest="Normal"}
	local item={BaseType=base,Class=class,Rarity=assert(mapped[rarity:lower()],"Unsupported clipboard rarity"),AreaLevel=area,
		Identified=not markers.Unidentified,Corrupted=markers.Corrupted==true or markers["Twice Corrupted"]==true,
		TwiceCorrupted=markers["Twice Corrupted"]==true,Mirrored=markers.Mirrored==true}
	for key,field in pairs({ItemLevel="Item Level",Quality="Quality",StackSize="Stack Size",MapTier="Map Tier"}) do
		local value=tonumber(raw:match(field..":%s*([%+%-]?%d+)"));assert(not value or value==value and math.abs(value)<=1e9,"Invalid clipboard "..field);item[key]=value
	end
	if class and class:find("Gems",1,true) then item.GemLevel=tonumber(raw:match("\nLevel:%s*(%d+)")) end
	local sockets=raw:match("Sockets: ([^\n]+)") or "";local groups={};local colours={};local linked=0
	for group in sockets:gmatch("[^ ]+") do local colors=group:gsub("[^RGBWAD]","");if #colors>0 then groups[#groups+1]=colors;colours[#colours+1]=colors;linked=math.max(linked,#colors) end end
	item.SocketColours=table.concat(colours);item.Sockets=#item.SocketColours;item.SocketGroup=table.concat(groups," ");item.LinkedSockets=linked
	if raw:lower():find("(fractured)",1,true) then item.FracturedItem=true end
	return item
end
return M
