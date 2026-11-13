-- Cheap preconditions for browsing. Applying an action still validates every option.
local sim=require("Modules.CraftingSimulator")
local M={}
local normal={transmute=true,alchemy=true,binding=true}
local magic={alteration=true,augmentation=true,regal=true,foulborn_augmentation=true,foulborn_regal=true}
local rare={chaos=true,exalt=true,veiled_orb=true,fracture=true,influence_exalt=true,awakener=true,dominance=true,bench_reroll=true,eldritch_exalt=true,eldritch_annul=true,eldritch_chaos=true,foulborn_exalt=true,tainted_chaos=true,tainted_exalt=true,harvest_reforge=true,harvest_augment=true}
local flask={transmute=true,alteration=true,augmentation=true,annul=true,scour=true,divine=true,blessed=true,quality=true}
local socket={chromatic=true,tainted_chromatic=true,socket_colour_bench=true,tainted_jeweller=true,tainted_fusing=true}
function M.check(method,state,model)
	if state.destroyed then return false,"Undo or reset the destroyed item." end
	if state.mirrored then return false,"Mirrored items cannot be crafted." end
	if state.veil and method~="unveil" then return false,"Finish the pending unveil first." end
	if method=="unveil" then return state.veil~=nil,state.veil and "Choose one of the offered modifiers." or "This item has no pending unveil." end
	local tainted=method:find("tainted_",1,true)~=nil
	if tainted and not state.corrupted then return false,"Requires a corrupted item." end
	if state.corrupted and not tainted and method~="socket_bench" and method~="socket_colour_bench" and method~="beast_talisman_fracture" and method~="ducat_tzamoto" then return false,"Requires an uncorrupted item." end
	model=sim.context(model,state);local item=model.item;local kind=item.type
	if (kind=="Flask" or kind=="Tincture") and not flask[method] and method~="ducat_tzamoto" and method~="ducat_kishara" then return false,"This method is unavailable for flasks and tinctures." end
	local reason=sim.methodReason(model,state,method);if reason then return false,reason end
	if normal[method] and state.rarity~="NORMAL" then return false,"Requires a normal item." end
	if magic[method] and state.rarity~="MAGIC" then return false,"Requires a magic item." end
	if rare[method] and state.rarity~="RARE" then return false,"Requires a rare item." end
	if (method=="annul" or method=="divine" or method=="scour" or method=="veiled_orb" or method=="ducat_kishara") and #state.affixes==0 then return false,"Requires an item with modifiers." end
	local fractured,crafted=false,false;for _,entry in ipairs(state.affixes) do fractured=fractured or entry.fractured;crafted=crafted or entry.crafted end
	local influenced=state.influences and #state.influences>0
	if method=="bench" then return sim.benchAvailable(model,state) end
	if method=="essence" then return sim.essenceAvailable(model,state) end
	if method=="harvest_reforge" or method=="harvest_augment" then local options,reason=sim.harvestChoices(model,state,method);return #options>0,reason end
	if method=="harvest_resistance" then local options,reason=sim.resistanceOptions(model,state);return #options>0,reason end
	if method=="harvest_enchant" and #sim.actionOptions(model,state,method)==0 then return false,"Harvest quality enchantments require an eligible weapon or body armour." end
	if method=="exalt" or method=="augmentation" or method=="foulborn_exalt" or method=="foulborn_augmentation" then if #state.affixes>=sim.capacities(model,state).total then return false,"There is no open modifier slot." end end
	if method=="fracture" then
		if #state.affixes<4 then return false,"Fracturing requires at least four modifiers." end
		if influenced or fractured or item.synthesised then return false,"Requires a non-influenced, non-synthesised item without fractures." end
	end
	if method=="influence_exalt" and (influenced or fractured or item.synthesised or item.itemLevel<68 or not item.base.influenceTags) then return false,"Requires an eligible uninfluenced, non-fractured base of item level 68 or higher." end
	if method=="restore_imprint" and not state.imprint then return false,"No saved imprint exists for this working item." end
	if method=="beast_imprint" and (state.rarity~="MAGIC" or fractured) then return false,"Imprinting requires a non-fractured magic item." end
	if method=="remove_crafted" and not crafted then return false,"This item has no bench-crafted modifiers." end
	if method=="beast_aspect" then
		if kind=="Jewel" then return false,"Aspect crafts require equipment." end
		local suffixes=0;for _,entry in ipairs(state.affixes) do if model.byId[entry.id].type=="Suffix" then suffixes=suffixes+1 end end
		if suffixes>=sim.capacities(model,state).Suffix then return false,"Requires an open suffix." end
	end
	if socket[method] then
		if #(state.sockets or {})==0 then return false,"Add sockets before using this action." end
		for _,entry in ipairs(state.sockets) do if entry.color=="A" then return false,"Abyssal sockets need a separate socket model." end end
	end
	if method=="socket_bench" and (item.base.socketLimit or 0)<2 then return false,"This base has no supported socket-count or link craft." end
	if method=="socket_colour_bench" and #(state.sockets or {})<2 then return false,"Requires at least two sockets." end
	if method=="tainted_fusing" then
		local sockets=state.sockets;local counts,max={},0;for _,entry in ipairs(sockets) do counts[entry.group]=(counts[entry.group] or 0)+1;max=math.max(max,counts[entry.group]) end
		if #sockets<2 or max==#sockets then return false,"Requires at least two sockets that are not fully linked." end
	end
	if method=="catalyst" or method=="tainted_catalyst" then if kind~="Ring" and kind~="Amulet" and kind~="Belt" then return false,"Catalysts require a ring, amulet or belt." end end
	if method=="quality" or method=="tainted_quality" then
		if not item.base.armour and not data.weaponTypeInfo[kind] and (tainted or kind~="Flask" and kind~="Tincture") then return false,"Quality currency requires eligible armour, a weapon, flask or tincture." end
		if not tainted and (state.quality or 0)>=20 then return false,"Ordinary quality currency cannot exceed 20%." end
	end
	if method=="vaal" or method=="locus" then if kind=="Jewel" or kind=="Flask" or kind=="Tincture" then return false,"This corruption model currently supports ordinary equipment." end end
	if method=="blessed" and (#item.implicitModLines==0 or state.implicits) then return false,"This item has no supported base implicit to reroll." end
	if method=="sacred" then
		local variable=false
		for _,property in ipairs({"Armour","Evasion","EnergyShield","Ward"}) do
			local armour=item.base.armour;local low=armour and armour[property.."BaseMin"];local high=armour and armour[property.."BaseMax"]
			if low and high and high>low then variable=true;break end
		end
		if not variable then return false,"Sacred Orbs require armour with variable base defences." end
	end
	if method=="conflict" and (not state.implicits or #state.implicits~=2) then return false,"Conflict requires both Eldritch implicits." end
	if method:find("eldritch",1,true) then
		if kind~="Helmet" and kind~="Body Armour" and kind~="Gloves" and kind~="Boots" then return false,"Eldritch currencies require a helmet, body armour, gloves or boots." end
		if method=="eldritch_implicit" and (influenced or item.synthesised) then return false,"Cannot combine Eldritch implicits with this influence or synthesis." end
		if model.unresolvedEldritch and not state.implicits then return false,"Supply structured tiers for the ambiguous imported Eldritch implicits." end
		if method~="eldritch_implicit" then local a,b=0,0;for _,entry in ipairs(state.implicits or {}) do if entry.side=="Exarch" then a=entry.tier else b=entry.tier end end;if a==b then return false,"One Eldritch influence must be dominant." end end
	end
	if method=="ducat_tzamoto" and (state.intangibility or 0)==0 then return false,"There is no Intangibility to remove." end
	if method=="beast_talisman_fracture" and (not item.base.tags.talisman or state.rarity~="RARE" or #state.affixes<4 or fractured) then return false,"Requires a rare Talisman with at least four modifiers and no existing fractures." end
	return true
end
return M
