-- Intrinsic item goals use the same native properties as the workbench cards.
local M={}
M.fields={
	{"PhysicalDPS","Physical DPS"},{"ElementalDPS","Elemental DPS"},
	{"ChaosDPS","Chaos DPS"},{"TotalDPS","Total weapon DPS"},
	{"AttackRate","Attacks per second"},{"CritChance","Critical chance (%)"},
	{"Armour","Armour"},{"Evasion","Evasion"},
	{"EnergyShield","Energy shield"},{"Ward","Ward"},
}
local known={};for _,field in ipairs(M.fields) do known[field[1]]=true end
function M.validate(goals)
	assert(type(goals)=="table" and next(goals),"Choose at least one minimum item stat")
	for key,value in pairs(goals) do
		assert(known[key],"Unknown item stat")
		assert(type(value)=="number" and value==value and value>=0 and value<=10000000,"Enter a minimum item stat between 0 and 10000000")
	end
	return goals
end
function M.values(sim,model,state)
	if state.destroyed or state.veil then return {} end
	local item=sim.toItem(model,state);local weapon=item.weaponData and item.weaponData[1];local result={}
	for i,field in ipairs(M.fields) do
		local key=field[1];local source=i<=6 and weapon or i>6 and item.armourData
		if source then result[key]=source[key] or 0 end
	end
	return result
end
function M.matches(sim,model,state,goals)
	local values=M.values(sim,model,state)
	for key,minimum in pairs(goals) do if values[key]==nil or values[key]<minimum then return false end end
	return true
end
return M
