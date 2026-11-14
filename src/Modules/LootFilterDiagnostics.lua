-- Report provable priority conflicts. Do not guess overlap for different predicates.
local M={}
-- Length prefixes keep arbitrary quoted values distinct without JSON-encoding
-- a new table for every value in every rule.
local function field(value) value=tostring(value);return #value..":"..value end
function M.shadowing(parsed)
	local seen,diagnostics={},{};local terminal
	for _,rule in ipairs(parsed.rules) do
		local conditions={}
		if not terminal then for _,condition in ipairs(rule.conditions) do
			local count=(condition.keyword=="HasExplicitMod" or condition.keyword=="HasEnchantment") and not (condition.quoted and condition.quoted[1]) and tonumber(condition.values[1])
			local values={};for i=count and 2 or 1,#condition.values do values[#values+1]=field(condition.values[i])..(condition.quoted and condition.quoted[i] and "1" or "0") end
			table.sort(values);conditions[#conditions+1]=field(condition.keyword)..field(condition.operator)..field(count)..field(table.concat(values))
		end end
		table.sort(conditions);local parts={};for _,condition in ipairs(conditions) do parts[#parts+1]=field(condition) end
		local key=table.concat(parts);local prior=terminal or seen[key]
		if prior then diagnostics[#diagnostics+1]={line=rule.line,shadowedBy=prior.line,warning="This block cannot be reached: a preceding terminating block at line "..prior.line.." matches the same conditions"..(terminal and " or every item." or ".")}
		elseif not rule.continue then seen[key]=rule;if #conditions==0 then terminal=rule end end
	end
	return diagnostics
end
return M
