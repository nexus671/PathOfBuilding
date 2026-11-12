-- Prefer finite enumeration; label bounded sampling explicitly for other crafts.
local C={}
function C.extend(M)
	local calculate=M.calculate
	local finite={recombine_predictable=true,augmentation=true,regal=true,exalt=true,influence_exalt=true,beast_talisman_fracture=true,ducat_kishara=true,ducat_tzamoto=true}
	function M.calculate(raw,craft,targets,initialState,options)
		options=options or {}
		local method=M.baseCurrency(craft)
		local sampled=not finite[method] or options.requirements~=nil or options.requiredGroups~=nil
		for _,list in ipairs({targets,craft.allflame and craft.allflame.preferredTargets or {}}) do
			for _,group in ipairs(list) do if group.minRoll ~= nil then sampled=true end end
		end
		if not sampled then return calculate(raw,craft,targets,initialState) end
		-- A calculator always applies its action, even when the input already matches.
		M.perform(raw,craft,options.seed,initialState)
		local result=M.simulate(raw,{steps={craft},targets=targets,initialState=initialState,requirements=options.requirements,requiredGroups=options.requiredGroups},
			{trials=options.trials or 1000,maxActions=1,seed=options.seed,forceFirstAction=true,checkpoint=options.checkpoint})
		result.sampled=true;result.outcomes={}
		result.estimateFor="One action, sampled from the supplied state under the stated transition assumptions"
		return result
	end
end
return C
