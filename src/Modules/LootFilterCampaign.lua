-- Offline family policies derived from the bundled native bases, never prices.
-- cspell:ignore jsontype
local M={defences={"Armour","Evasion","Energy shield","Armour / Evasion","Armour / Energy shield","Evasion / Energy shield","All three defences","Ward"},recipes={"Three-colour linked equipment","Six-socket equipment","Six-link equipment","Quality gems"}}
local knownWeapons={"Bow","Claw","Dagger","Rune Dagger","Fishing Rod","One Handed Axe","One Handed Mace","One Handed Sword","Thrusting Sword","Sceptre","Staff","Warstaff","Two Handed Axe","Two Handed Mace","Two Handed Sword","Wand","Shield","Quiver"}
M.weapons=knownWeapons
local armourTypes={Helmet=true,["Body Armour"]=true,Gloves=true,Boots=true,Shield=true}
function M.weapon(base)
	if base.subType=="Rune Dagger" or base.subType=="Warstaff" then return base.subType elseif base.subType=="Thrusting" then return "Thrusting Sword" end
	if base.weapon or base.type=="Shield" or base.type=="Quiver" then return base.type end
end
function M.defence(base)
	if not armourTypes[base.type] or not base.armour then return end
	local a=base.armour;local function has(kind) return (a[kind.."BaseMin"] or a[kind.."BaseMax"] or 0)>0 end
	if has("Ward") then return "Ward" end
	local mask=(has("Armour") and 1 or 0)+(has("Evasion") and 2 or 0)+(has("EnergyShield") and 4 or 0)
	return ({[1]="Armour",[2]="Evasion",[4]="Energy shield",[3]="Armour / Evasion",[5]="Armour / Energy shield",[6]="Evasion / Energy shield",[7]="All three defences"})[mask]
end
function M.defaults() return {enabled=true,weapons={},defences={},recipes={},minAreaLevel=1,maxAreaLevel=70,minDropLevel=0,minLinks=0,upgradeWindow=15} end
function M.validate(value)
	assert(type(value)=="table" and value~=require("dkjson").null,"Invalid campaign policy")
	local result=M.defaults();assert(value.enabled==nil or type(value.enabled)=="boolean","Invalid campaign enable setting");result.enabled=value.enabled~=false
	for key,choices in pairs({weapons=M.weapons,defences=M.defences,recipes=M.recipes}) do
		local input=value[key];if input==nil then input={} end;assert(type(input)=="table" and input~=require("dkjson").null,"Invalid campaign families");local meta=getmetatable(input);assert(not meta or meta.__jsontype~="object","Campaign families must be arrays")
		for index in pairs(input) do assert(type(index)=="number" and index==math.floor(index) and index>=1 and index<=#input,"Campaign families must be arrays") end
		local seen={};for _,name in ipairs(input) do local valid=false;for _,choice in ipairs(choices) do if choice==name then valid=true end end;assert(valid and not seen[name],"Invalid or duplicate campaign family");seen[name]=true end
		result[key]={};for _,name in ipairs(choices) do if seen[name] then result[key][#result[key]+1]=name end end
	end
	for key,bounds in pairs({minAreaLevel={1,100},maxAreaLevel={1,100},minDropLevel={0,100},minLinks={0,6},upgradeWindow={0,100}}) do
		local n=value[key];if n~=nil then assert(type(n)=="number" and n==math.floor(n) and n>=bounds[1] and n<=bounds[2],"Invalid campaign "..key);result[key]=n end
	end
	assert(result.minAreaLevel<=result.maxAreaLevel,"Campaign area range is reversed");return result
end
local cache
function M.families()
	if cache then return cache end
	cache={weapons={},defences={}}
	for name,base in pairs(data.itemBases) do if not base.hidden then
		for key,family in pairs({weapons=M.weapon(base),defences=M.defence(base)}) do if family then cache[key][family]=cache[key][family] or {};cache[key][family][#cache[key][family]+1]=name end end
	end end
	for _,groups in pairs(cache) do for _,names in pairs(groups) do table.sort(names) end end;return cache
end
function M.equipped(build)
	local result=M.defaults();local weapons,defences={},{}
	for name,slot in pairs(build.itemsTab.slots) do if not name:find("Swap",1,true) then local item=build.itemsTab.items[slot.selItemId]
		if item and item.base then local a,b=M.weapon(item.base),M.defence(item.base);if a then weapons[a]=true end;if b then defences[b]=true end end
	end end
	for _,name in ipairs(M.weapons) do if weapons[name] then result.weapons[#result.weapons+1]=name end end
	for _,name in ipairs(M.defences) do if defences[name] then result.defences[#result.defences+1]=name end end;return result
end
function M.rules(value,theme)
	if not value then return {} end;local policy=M.validate(value);if not policy.enabled then return {} end
	local filters=require("Modules.LootFilters");local result={};local families=M.families()
	local function rule(id,title,conditions)
		local entry=filters.rule("campaign-"..id,title,conditions,nil,theme)
		entry.text=entry.text:gsub("\n%s*PlayAlertSound[^\n]*",""):gsub("\n%s*MinimapIcon[^\n]*",""):gsub("\n%s*PlayEffect[^\n]*",""):gsub("SetFontSize 42","SetFontSize 32")
		result[#result+1]=entry
	end
	for _,key in ipairs({"weapons","defences"}) do for _,family in ipairs(policy[key]) do
		local names=families[key][family];if names and #names>0 then
			local quoted={};for _,name in ipairs(names) do quoted[#quoted+1]=filters.quote(name) end
			local step=policy.upgradeWindow>0 and 5 or policy.maxAreaLevel-policy.minAreaLevel+1
			for from=policy.minAreaLevel,policy.maxAreaLevel,step do
				local through=math.min(policy.maxAreaLevel,from+step-1);local minimum=math.max(policy.minDropLevel,policy.upgradeWindow>0 and from-policy.upgradeWindow or 0)
				local conditions={"BaseType == "..table.concat(quoted," "),"Rarity <= Rare","AreaLevel >= "..from,"AreaLevel <= "..through}
				if minimum>0 then conditions[#conditions+1]="DropLevel >= "..minimum end;if policy.minLinks>0 then conditions[#conditions+1]="LinkedSockets >= "..policy.minLinks end
				rule(require("sha1")(key..family):sub(1,16).."-"..from,family.." / areas "..from.."-"..through,conditions)
			end
		end
	end end
	local recipes={
		["Three-colour linked equipment"]={"SocketGroup RGB","Rarity <= Rare"},
		["Six-socket equipment"]={"Sockets 6","Rarity <= Rare"},
		["Six-link equipment"]={"LinkedSockets 6","Rarity <= Rare"},
		["Quality gems"]={'Class == "Skill Gems" "Support Gems"',"Quality >= 1"},
	}
	for i,name in ipairs(M.recipes) do for _,chosen in ipairs(policy.recipes) do if name==chosen then local conditions=copyTable(recipes[name]);conditions[#conditions+1]="AreaLevel >= "..policy.minAreaLevel;conditions[#conditions+1]="AreaLevel <= "..policy.maxAreaLevel;rule("recipe-"..i,name,conditions) end end end
	return result
end
return M
