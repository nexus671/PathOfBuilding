-- Searchable base-filter catalogue and deterministic example drops. No drop-rate model.
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local sha1=require("sha1")
local M={categories={"All items","Build targets","Campaign","Currency","Special currency","Equipment","Unique items","Flasks","Tinctures","Jewels","Divination cards","Maps & fragments","Gems","Recipes","League items","Other"}}
function M.category(rule)
	if rule.origin then return "Build targets" end
	local text=(rule.text or ""):lower()
	if text:find("divination cards",1,true) or text:find("%$type%-%>cards") then return "Divination cards" end
	if text:find("tinctures",1,true) then return "Tinctures" end
	if text:find("flasks",1,true) then return "Flasks" end
	if text:find("jewels",1,true) then return "Jewels" end
	if text:find("%$type%-%>recipes") or text:find("%$type%-%>recipe") then return "Recipes" end
	if text:find("%$type%-%>currency") and (text:find("fossil",1,true) or text:find("essence",1,true) or text:find("resonator",1,true) or text:find("catalyst",1,true)) then return "Special currency" end
	if text:find("%$type%-%>uniques") or text:find("rarity == unique",1,true) or text:find("rarity unique",1,true) then return "Unique items" end
	if text:find("%$type%-%>currency") or text:find("stackable currency",1,true) then return "Currency" end
	if text:find("%$type%-%>maps") or text:find("%$type%-%>fragments") or text:find("%$type%-%>scarab") or text:find('"maps"',1,true) or text:find("map fragments",1,true) then return "Maps & fragments" end
	if text:find("%$type%-%>gems") or text:find("skill gems",1,true) or text:find("support gems",1,true) then return "Gems" end
	if text:find("viscera",1,true) or text:find("enshrouded",1,true) or text:find("%$type%-%>league") then return "League items" end
	if text:find("rarity",1,true) or text:find("%$type%-%>rares") or text:find("%$type%-%>uniques") or text:find("sockets",1,true) then return "Equipment" end
	return "Other"
end
local classExamples={["Body Armours"]="Vaal Regalia",Helmets="Iron Hat",Gloves="Wool Gloves",Boots="Wool Shoes",Wands="Driftwood Wand",Shields="Splintered Tower Shield",Rings="Iron Ring",Amulets="Amber Amulet",Belts="Leather Belt",Jewels="Cobalt Jewel",Maps="Strand Map",["Map Fragments"]="Breach Thread",["Skill Gems"]="Arcane Link",["Support Gems"]="Added Fire Damage Support",["Stackable Currency"]="Chaos Orb",Tinctures="Prismatic Tincture"}
-- Filter class names from the pinned RePoE item_classes.json (ae6d85a5).
-- Native base types use different names for several weapon families.
local nativeClasses={Helmet="Helmets",["Body Armour"]="Body Armours",Gloves="Gloves",Boots="Boots",Shield="Shields",Ring="Rings",Amulet="Amulets",Belt="Belts",Quiver="Quivers",Bow="Bows",Claw="Claws",Dagger="Daggers",["Rune Dagger"]="Rune Daggers",Wand="Wands",Sceptre="Sceptres",Staff="Staves",Warstaff="Warstaves",["Thrusting Sword"]="Thrusting One Hand Swords",["One Handed Sword"]="One Hand Swords",["One Handed Axe"]="One Hand Axes",["One Handed Mace"]="One Hand Maces",["Two Handed Sword"]="Two Hand Swords",["Two Handed Axe"]="Two Hand Axes",["Two Handed Mace"]="Two Hand Maces",Tincture="Tinctures"}
local function baseClass(name)
	local base=data and data.itemBases and data.itemBases[name]
	if base then
		local kind=base.subType=="Thrusting" and "Thrusting Sword" or (base.subType=="Rune Dagger" or base.subType=="Warstaff") and base.subType or base.type
		if nativeClasses[kind] then return nativeClasses[kind] end
	end
	for class,example in pairs(classExamples) do if example==name then return class end end
end
function M.sample(rule,block)
	local item={BaseType="Chaos Orb",Class="Stackable Currency",Rarity="Normal",ItemLevel=86,AreaLevel=83,DropLevel=1,Quality=0,StackSize=1,Sockets=0,SocketGroup="",LinkedSockets=0,Width=1,Height=1,UnidentifiedItemTier=0,HasInfluence={"None"},HasExplicitMod={},HasEnchantment={},EnchantmentPassiveNode="",BaseDefencePercentile=50}
	for key in pairs(parser.booleans) do item[key]=false end
	for key in pairs(parser.numeric) do if item[key]==nil then item[key]=0 end end
	local hasBase,hasClass=false,false
	if rule then block=block or parser.parse(rule.text).rules[1];if block then for _,c in ipairs(block.conditions) do
		local value=c.values[1]
		if c.keyword=="BaseType" then hasBase=true elseif c.keyword=="Class" then hasClass=true end
		if parser.numeric[c.keyword] then local n=tonumber(value);item[c.keyword]=n and (c.operator==">" and n+1 or c.operator=="<" and n-1 or n) or value
		elseif c.keyword=="Rarity" then item.Rarity=value
		elseif parser.booleans[c.keyword] then item[c.keyword]=value=="True"
		elseif c.keyword=="HasInfluence" then item[c.keyword]=copyTable(c.values)
		elseif c.keyword=="BaseType" or c.keyword=="Class" or c.keyword=="SocketGroup" then item[c.keyword]=value end
	end end end
	if not hasBase then
		if hasClass then item.BaseType=classExamples[item.Class] or item.Class
		elseif item.LinkedSockets>=5 or type(item.SocketGroup)=="string" and item.SocketGroup~="" then item.BaseType="Vaal Regalia";item.Class="Body Armours"
		elseif item.Rarity=="Unique" then item.BaseType="Leather Belt";item.Class="Belts" end
	elseif not hasClass then item.Class=baseClass(item.BaseType) end
	return item
end
function M.catalog(profile)
	local raw=filters.migratedBase(profile);local entries={};local ids={}
	for i,block in ipairs(parser.parse(raw).rules) do
		local text=table.concat(block.rawLines,"\n");local example
		local tier=block.rawLines[1]:match("%$tier%-%>([%w_-]+)") or "Base rule"
		local title;local named=false
		for _,condition in ipairs(block.conditions) do if condition.keyword=="BaseType" then title=condition.values[1]..(#condition.values>1 and " +"..(#condition.values-1) or "");named=true;break end end
		if not named then
			example=M.sample({text=text},block);title=example.LinkedSockets>=5 and tostring(example.LinkedSockets).."-link equipment" or example.BaseType
			if #block.conditions==0 then title=block.continue and "Style remaining items" or block.action.." remaining items" end
		end
		tier=tier:match("^t%d+$") and "Tier "..tier:sub(2) or "Preset rule"
		title=title:gsub("%-%>"," / "):gsub("_"," ")
		local key="base-"..sha1(text):sub(1,20);ids[key]=(ids[key] or 0)+1
		local rule={id=key..(ids[key]>1 and "-"..ids[key] or ""),title=title,text=text,enabled=true}
		local entry={rule=rule,category=M.category(rule),tier=tier,sample=example,block=block,base=true}
		-- Most views need names and conditions only. Materialise example properties on demand.
		setmetatable(entry,{__index=function(self,key) if key=="sample" then local value=M.sample(self.rule,self.block);rawset(self,key,value);return value end end});entries[#entries+1]=entry
	end
	return entries
end
function M.personal(profile)
	local entries={};for _,rule in ipairs(profile.rules) do entries[#entries+1]={rule=rule,category=M.category(rule),tier=rule.origin and "Build target" or "Personal rule",sample=M.sample(rule),block=parser.parse(rule.text).rules[1]} end;return entries
end
function M.campaign(profile)
	local entries={};for _,rule in ipairs(require("Modules.LootFilterCampaign").rules(profile.campaign,profile.theme)) do entries[#entries+1]={rule=rule,category="Campaign",tier="Pickup policy",sample=M.sample(rule),block=parser.parse(rule.text).rules[1],base=true} end;return entries
end
function M.entries(profile,source,category,query)
	local result={};for _,entry in ipairs(source or {}) do
		if (category==nil or category=="All items" or entry.category==category) and (entry.rule.title.." "..entry.rule.text):lower():find((query or ""):lower(),1,true) then result[#result+1]=entry end
	end;return result
end
function M.appearance(rule,changes)
	local block=assert(parser.parse(rule.text).rules[1]);local lines={block.action}
	for _,condition in ipairs(block.conditions) do
		local values={};for _,value in ipairs(condition.values) do values[#values+1]=(parser.strings[condition.keyword] and not tonumber(value) or value:find("%s")) and filters.quote(value) or value end
		lines[#lines+1]="    "..condition.keyword.." "..condition.operator.." "..table.concat(values," ")
	end
	local styles=copyTable(block.styles);for key,value in pairs(changes) do styles[key]=value~=false and value or nil end
	local keys={};for key in pairs(styles) do keys[#keys+1]=key end;table.sort(keys)
	for _,key in ipairs(keys) do local value=styles[key];local output=key:match("^CustomAlertSound") and (filters.quote(value[1])..(#value>1 and " "..table.concat(value," ",2) or "")) or table.concat(value," ");lines[#lines+1]="    "..key.." "..output end
	if block.continue then lines[#lines+1]="    Continue" end
	local nextRule=copyTable(rule);nextRule.text=table.concat(lines,"\n");nextRule.origin=nil;return nextRule
end
local examples={
	{"Divine Orb","Stackable Currency"},{"Chaos Orb","Stackable Currency"},{"Orb of Alchemy","Stackable Currency"},{"Orb of Alteration","Stackable Currency"},
	{"Frayed Thread","Stackable Currency"},{"Breach Thread","Map Fragments"},{"Enshrouded Quiver","Enshrouded Items"},{"Coven Queen's Crown","Viscera"},
	{"Iron Hat","Helmets","Rare"},{"Vaal Regalia","Body Armours","Rare"},{"Leather Belt","Belts","Unique"},{"Iron Ring","Rings","Magic"},
	{"Arcane Link","Skill Gems"},{"Orb of Fusing","Stackable Currency"},{"Scroll of Wisdom","Stackable Currency"},{"Chromatic Orb","Stackable Currency"},
}
function M.scene(profile,build,kind,seed,area,itemLevel)
	local list={}
	if kind=="Build targets" then for _,rule in ipairs(filters.generate(build,profile)) do list[#list+1]=M.sample(rule) end end
	for i=1,#examples do local example=examples[(i+(seed or 0)-1)%#examples+1];local item=M.sample();item.BaseType=example[1];item.Class=example[2];item.Rarity=example[3] or "Normal";item.AreaLevel=area or 83
		if kind~="Currency" or item.Class=="Stackable Currency" then list[#list+1]=item end
	end
	for _,item in ipairs(list) do item.AreaLevel=area or 83;item.ItemLevel=itemLevel or 86 end
	return list
end
return M
