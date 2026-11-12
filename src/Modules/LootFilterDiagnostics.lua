-- Report provable priority conflicts. Do not guess overlap for different predicates.
local stable=require("Modules.PlanningData")
local M={}
function M.shadowing(parsed)
	local seen,diagnostics={},{};local terminal
	for _,rule in ipairs(parsed.rules) do
		local conditions={}
		for _,condition in ipairs(rule.conditions) do local values=copyTable(condition.values);table.sort(values);conditions[#conditions+1]=stable.encode({keyword=condition.keyword,operator=condition.operator,values=values}) end
		table.sort(conditions);local key=table.concat(conditions,"\n");local prior=terminal or seen[key]
		if prior then diagnostics[#diagnostics+1]={line=rule.line,shadowedBy=prior.line,warning="This block cannot be reached: a preceding terminating block at line "..prior.line.." matches the same conditions"..(terminal and " or every item." or ".")}
		elseif not rule.continue then seen[key]=rule;if #conditions==0 then terminal=rule end end
	end
	return diagnostics
end
return M
