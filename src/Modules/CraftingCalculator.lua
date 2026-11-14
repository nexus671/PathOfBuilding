-- Prefer finite enumeration; label bounded sampling explicitly for other crafts.
local C={}
function C.extend(M)
	local calculate=M.calculate
	local finite={recombine_predictable=true,augmentation=true,regal=true,exalt=true,influence_exalt=true,beast_talisman_fracture=true,ducat_kishara=true,ducat_tzamoto=true}
	function M.calculate(raw,craft,targets,initialState,options)
		options=options or {}
		local method=M.baseCurrency(craft)
		if craft.method=="annul" and not craft.allflame then
			M.validateRecipe({steps={craft},targets=targets,requirements=options.requirements,requiredGroups=options.requiredGroups})
			local model=M.model(raw);local state=initialState and M.validateState(model,initialState) or model.initial
			if M.context then model=M.context(model,state) end
			if M.hasPartialLock(model,state) then
				local branches=M.partialAnnulBranches(model,state)
				if branches then
					local outcomes,success={},0
					for _,branch in ipairs(branches) do
						local draw=0;local result=M.action(model,state,craft,function()
							draw=draw+1;if draw<=#branch.draws then return branch.draws[draw] end
							assert(draw==#branch.draws+1,"Unexpected Annulment draw");return branch.removalDraw
						end)
						local hit=M.matches(result,targets,nil,model,options.requirements,options.requiredGroups)
						if hit then success=success+branch.probability end
						local entry=state.affixes[branch.index];local mod=model.byId[entry.id]
						outcomes[#outcomes+1]={id=entry.id,chance=100*branch.probability,weight=branch.probability,matches=hit,text="Remove: "..table.concat(mod," / "),state=result}
					end
					return {exactFor="One Annulment under the model's uniform lock-selection and removal assumptions",sampled=false,successChance=100*success,totalWeight=1,matchingWeight=success,
						outcomes=outcomes,sampleState=outcomes[1].state,sampleItem=M.toItem(model,outcomes[1].state).raw,dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
				end
			end
			if not M.hasPartialLock(model,state) then
			local choices=M.annulCandidates(model,state);local count=#choices
			assert(state.rarity~="NORMAL","Annulment requires a magic or rare item")
			assert(count>0,"No modifier can be removed")
			local outcomes,hits={},0
			for i,index in ipairs(choices) do
				local result=M.action(model,state,craft,function() return (i-0.5)/count end)
				local hit=M.matches(result,targets,nil,model,options.requirements,options.requiredGroups)
				if hit then hits=hits+1 end
				local entry=state.affixes[index];local mod=model.byId[entry.id]
				outcomes[#outcomes+1]={id=entry.id,chance=100/count,weight=1,matches=hit,text="Remove: "..table.concat(mod," / "),state=result}
			end
			return {exactFor="One Annulment under the model's uniform removable-modifier assumption",sampled=false,successChance=100*hits/count,totalWeight=count,matchingWeight=hits,
				outcomes=outcomes,sampleState=outcomes[1].state,sampleItem=M.toItem(model,outcomes[1].state).raw,dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
			end
		end
		if method=="omen_trichromatism" and not craft.allflame then
			local model=M.model(raw);local state=initialState and M.validateState(model,initialState) or model.initial
			if #(state.sockets or {})==3 then
				M.validateRecipe({steps={craft},targets=targets,requirements=options.requirements,requiredGroups=options.requiredGroups})
				local outcomes,hits={},0
				for first=1,3 do for second=1,2 do
					local draws={(first-0.5)/3,(second-0.5)/2};local at=0
					local result=M.action(model,state,craft,function() at=at+1;return assert(draws[at],"Unexpected socket-placement draw") end)
					local hit=M.matches(result,targets,nil,model,options.requirements,options.requiredGroups)
					if hit then hits=hits+1 end
					outcomes[#outcomes+1]={chance=100/6,weight=1,matches=hit,text="RGB placement "..(#outcomes+1),state=result}
				end end
				return {exactFor="Six socket placements under the stated uniform-position model",sampled=false,successChance=100*hits/6,totalWeight=6,matchingWeight=hits,
					outcomes=outcomes,sampleState=outcomes[1].state,sampleItem=M.toItem(model,outcomes[1].state).raw,dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
			end
		end
		if (method=="socket_bench" or method=="socket_white_bench" or method=="omen_connections" or method=="beast_max_links") and not craft.allflame then
			M.validateRecipe({steps={craft},targets=targets,requirements=options.requirements,requiredGroups=options.requiredGroups})
			local model=M.model(raw);local result=M.perform(raw,craft,options.seed,initialState)
			local hit=M.matches(result.state,targets,nil,model,options.requirements,options.requiredGroups)
			return {exactFor="One deterministic socket craft on the supplied item",sampled=false,successChance=hit and 100 or 0,
				totalWeight=1,matchingWeight=hit and 1 or 0,sampleState=result.state,sampleItem=result.itemText,
				outcomes={{chance=100,weight=1,matches=hit,text=M.labels[method],state=result.state}},dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
		end
		local sampled=not finite[method] or options.requirements~=nil or options.requiredGroups~=nil
		for _,list in ipairs({targets,craft.allflame and craft.allflame.preferredTargets or {}}) do
			for _,group in ipairs(list) do if group.minRoll ~= nil then sampled=true end end
		end
		if not sampled then return calculate(raw,craft,targets,initialState) end
		-- A calculator always applies its action, even when the input already matches.
		local partialHarvest=false
		if method=="harvest_reforge" or method=="harvest_augment" then
			local model=M.model(raw);local state=initialState and M.validateState(model,initialState) or model.initial
			partialHarvest=M.hasPartialLock(M.context(model,state),state)
		end
		-- Partial-lock selection can make only some attempts invalid. Let the
		-- simulator report those transition errors instead of rejecting the
		-- entire calculation based on one arbitrarily seeded preflight.
		if not partialHarvest then M.perform(raw,craft,options.seed,initialState) end
		local result=M.simulate(raw,{steps={craft},targets=targets,initialState=initialState,requirements=options.requirements,requiredGroups=options.requiredGroups},
			{trials=options.trials or 1000,maxActions=1,seed=options.seed,forceFirstAction=true,checkpoint=options.checkpoint})
		result.sampled=true;result.outcomes={}
		result.estimateFor="One action, sampled from the supplied state under the stated transition assumptions"
		return result
	end
end
return C
