local categories=require("Modules.LootFilterCategoryStyles")
local appearance=require("Modules.LootFilterAppearanceSettings")
local M={}
function M.Open(profile,onKeep)
	local current={};for _,entry in ipairs(profile.categoryStyles or {}) do current[entry.category]=entry end
	local counts={};for _,entry in ipairs(require("Modules.LootFilterStructure").outline(profile).entries) do counts[entry.category]=(counts[entry.category] or 0)+1 end
	local entries={}
	for _,name in ipairs(require("Modules.LootFilterLibrary").categories) do if name~="All items" then
		local policy=current[name];local lines={name,(counts[name] or 0).." active blocks in this category.",policy and (policy.enabled==false and "Saved style is disabled." or "Custom style is active.") or "Uses the preset's original styles.","Changes affect declared styles in this category at their existing priority.","Whole-filter appearance applies after category settings. Continue inheritance and pickup conditions stay unchanged.","Categories follow preset labels and rule conditions. Check Customize to see where an imported rule is grouped."}
		if policy then for _,key in ipairs({"textColor","borderColor","backgroundColor"}) do if policy.appearance[key] then lines[#lines+1]=({textColor="Text colour",borderColor="Border colour",backgroundColor="Background colour"})[key]..": "..appearance.hex(policy.appearance[key]) end end end
		entries[#entries+1]={id=name,label=name.." | "..(counts[name] or 0).." blocks",category=policy and "Custom styles" or "Preset styles",details=lines}
	end end
	require("Classes.PlanningBrowserControl").Open("Category appearance",entries,{action="Edit category",choose=function(entry)
		main:ClosePopup();local policy=current[entry.id];local form=copyTable(profile);form.appearance=policy and policy.appearance or nil
		require("Classes.LootFilterGlobalControl").Open(form,function(next) onKeep(categories.install(profile,entry.id,next.appearance)) end,{
			title=entry.id.." appearance",help="Change declared styles in "..entry.id.." without moving rules. Whole-filter overrides still apply last. Blank colours keep existing styles; Restore original removes this category's settings.",previewAppearance=profile.appearance,
			validate=function(settings) local next=categories.install(profile,entry.id,settings);local _,report=require("Modules.LootFilters").compile(next);for _,d in ipairs(report.diagnostics) do assert(not d.error,d.error) end end,
		})
	end,closeOnChoose=false})
end
return M
