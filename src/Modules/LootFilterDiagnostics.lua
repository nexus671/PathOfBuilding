-- Report provable priority conflicts. Do not guess overlap for different predicates.
local stable=require("Modules.PlanningData")
local M={}
function M.shadowing(parsed)
	local seen,diagnostics={},{};local terminal
	for _,rule in ipairs(parsed.rules) do
		local conditions={}
		for _,condition in ipairs(rule.conditions) do
			local count=(condition.keyword=="HasExplicitMod" or condition.keyword=="HasEnchantment") and not (condition.quoted and condition.quoted[1]) and tonumber(condition.values[1])
			local values={};for i=count and 2 or 1,#condition.values do values[#values+1]=stable.encode({value=condition.values[i],quoted=condition.quoted and condition.quoted[i] or false}) end
			table.sort(values);conditions[#conditions+1]=stable.encode({keyword=condition.keyword,operator=condition.operator,count=count,values=values})
		end
		table.sort(conditions);local key=table.concat(conditions,"\n");local prior=terminal or seen[key]
		if prior then diagnostics[#diagnostics+1]={line=rule.line,shadowedBy=prior.line,warning="This block cannot be reached: a preceding terminating block at line "..prior.line.." matches the same conditions"..(terminal and " or every item." or ".")}
		elseif not rule.continue then seen[key]=rule;if #conditions==0 then terminal=rule end end
	end
	return diagnostics
end
return M
