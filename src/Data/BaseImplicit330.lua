-- Patch-note overrides until regenerated 3.30 base data is available.
-- https://www.pathofexile.com/forum/view-thread/4013680
local changes={
	["Apothecary's Gloves"]={"(14-18)% increased Damage over Time","+(14-18)% to Damage over Time Multiplier",true},
	["Fingerless Silk Gloves"]={"(12-16)% increased Spell Damage","(20-26)% increased Spell Damage"},
	["Gripped Gloves"]={"(14-18)% increased Projectile Attack Damage","(22-28)% increased Projectile Attack Damage"},
	["Spiked Gloves"]={"(16-20)% increased Melee Damage","(24-30)% increased Melee Damage"},
	["Fugitive Boots"]={"+(13-17)% to Chaos Resistance","+(17-23)% to Chaos Resistance"},
	["Two-Toned Boots (Armour/Evasion)"]={"+(8-12)% to Fire and Cold Resistances","+(16-20)% to Fire and Cold Resistances"},
	["Two-Toned Boots (Armour/Energy Shield)"]={"+(8-12)% to Fire and Lightning Resistances","+(16-20)% to Fire and Lightning Resistances"},
	["Two-Toned Boots (Evasion/Energy Shield)"]={"+(8-12)% to Cold and Lightning Resistances","+(16-20)% to Cold and Lightning Resistances"},
	["Bone Helmet"]={"Minions deal (15-20)% increased Damage","Minions deal (20-30)% increased Damage"},
	["Marble Amulet"]={"Regenerate (1.2-1.6)% of Life per second","Regenerate (1.4-2)% of Life per second"},
	["Seaglass Amulet"]={"(10-15)% faster start of Energy Shield Recharge","(20-30)% faster start of Energy Shield Recharge"},
	["Vanguard Belt"]={"+(260-320) to Armour and Evasion Rating","+(260-480) to Armour and Evasion Rating"},
	["Crystal Belt"]={"+(60-80) to maximum Energy Shield","+(60-100) to maximum Energy Shield"},
	["Amethyst Ring"]={"+(17-23)% to Chaos Resistance","+(13-19)% to Chaos Resistance"},
}
return function(bases)
	for name,entry in pairs(changes) do
		local base=assert(bases[name],"Missing base for 3.30 patch: "..name)
		if base.implicit==entry[1] or base.implicit==entry[2] then
			if entry[3] and base.implicit==entry[1] then base.implicitIds={} end
			base.implicit=entry[2];base.blessed330={old=entry[1],current=entry[2]}
		end
	end
	local quiver=assert(bases["Artillery Quiver"])
	if quiver.implicit=="(20-30)% increased Totem Placement speed" then
		quiver.implicit="Attack Skills have +1 to maximum number of Summoned Totems"
		quiver.implicitIds={};quiver.implicitModTypes={{}}
	end
end
