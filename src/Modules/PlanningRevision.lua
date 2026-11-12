-- Cheap native edit identities. Exact XML hashes still guard proposal application.
local M={}
function M.stamp(build)
	return {output=build.outputRevision,name=build.buildName,level=build.characterLevel,notes=build.notesTab.controls.edit.buf,spec=build.spec,
		items=build.itemsTab.activeItemSetId,skills=build.skillsTab.activeSkillSetId,config=build.configTab.activeConfigSetId,
		journey=build.savers.BuildJourney.data,filters=build.savers.LootFilters.data,atlas=build.savers.AtlasPlans.plans,atlasCount=#build.savers.AtlasPlans.plans,
		crafts=build.savers.CraftingProjects.projects,craftCount=#build.savers.CraftingProjects.projects}
end
function M.same(before,after)
	if not before or not after then return false end
	for key,value in pairs(before) do if after[key]~=value then return false end end
	for key,value in pairs(after) do if before[key]~=value then return false end end
	return true
end
return M
