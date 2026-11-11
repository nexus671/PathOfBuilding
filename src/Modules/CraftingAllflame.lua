-- Independent ghost outcomes, using settings observed at Vesper for this craft.
local F={}
local currencies={transmute=true,alteration=true,augmentation=true,regal=true,alchemy=true,chaos=true,exalt=true,annul=true,scour=true,divine=true,essence=true,fossil=true,fracture=true,influence_exalt=true,awakener=true,veiled_orb=true,dominance=true,eldritch_implicit=true,eldritch_exalt=true,eldritch_annul=true,eldritch_chaos=true,blessed=true,sacred=true,binding=true,quality=true,catalyst=true,chromatic=true,remembrance=true,unravelling=true,foulborn_augmentation=true,foulborn_regal=true,foulborn_exalt=true,ducat_cyaxan=true,ducat_brinehook=true,ducat_genteel=true,ducat_merrick=true,ducat_rotmother=true}
function F.extend(M,A,api)
	local model,validate,action,calculate,components,priceKey=M.model,M.validateState,M.action,M.calculate,M.components,M.priceKey
	function M.model(raw)
		assert(type(raw) == "string" and #raw <= 24000,"Invalid starting item")
		local value=tonumber(raw:match("\nIntangibility: (%d+)%%?"))
		local result=model(raw:gsub("\r?\nIntangibility: %d+%%?",""))
		result.initial.intangibility=value or 0
		if value then api.integer(value,0,100,"intangibility");result.initial.origin=require("sha1")(raw) end
		return result
	end
	function M.validateState(model,state)
		if state.intangibility then api.integer(state.intangibility,0,100,"intangibility") end
		return validate(model,state)
	end
	function M.action(model,input,craft,random)
		local profile=craft.allflame
		if not profile then return action(model,input,craft,random) end
		assert(currencies[craft.method],"This action is not an itemised currency supported by the Allflame model")
		assert(not input.corrupted and not input.mirrored and not input.destroyed and not input.veil,"Allflame requires a modifiable item with no pending unveil")
		local count=api.integer(profile.outcomes,1,4,"observed maximum ghost outcomes")
		local low=api.integer(profile.gainMin,0,100,"observed minimum Intangibility gain")
		local high=api.integer(profile.gainMax,low,100,"observed maximum Intangibility gain")
		api.integer(profile.sulphur,0,1000000000,"observed Sulphur cost")
		if profile.choiceIndex then api.integer(profile.choiceIndex,1,4,"ghost choice") end
		if profile.preferredTargets then M.validateRecipe({steps={{method=craft.method}},targets=profile.preferredTargets}) end
		local collapsed=count > 1 and (input.intangibility or 0) > 0 and random()*100 < input.intangibility
		if collapsed then count=1 end
		local plain=copyTable(craft);plain.allflame=nil
		local choices={};local best,bestScore=1,-1
		for i=1,count do
			local state=action(model,copyTable(input),plain,random)
			local gain=count > 1 and low+math.floor(random()*(high-low+1)) or 0
			state.intangibility=math.min(100,(input.intangibility or 0)+gain)
			choices[i]={state=state,itemText=not state.veil and not state.destroyed and M.toItem(model,state).raw or nil}
			local score=0
			if not state.destroyed then for _,target in ipairs(profile.preferredTargets or {}) do if M.matches(state,{target},nil,model) then score=score+1 end end end
			if score > bestScore then best,bestScore=i,score end
		end
		local selected=profile.choiceIndex and math.min(count,profile.choiceIndex) or best
		return choices[selected].state,{choices=choices,allflame={selected=selected,collapsed=collapsed,outcomes=count,sulphur=profile.sulphur}}
	end
	function M.calculate(raw,craft,targets,initialState)
		assert(not craft.allflame,"Use bounded simulation for Allflame outcome selection; next-affix enumeration describes one currency draw")
		return calculate(raw,craft,targets,initialState)
	end
	function M.priceKey(craft) return craft.allflame and "allflame:"..priceKey(craft) or priceKey(craft) end
	function M.components(craft,state)
		local result=components(craft,state)
		if craft.allflame then
			-- Preserve the ordinary currency component when its default key is used.
			local combined=M.priceKey(craft);if result[combined] then result[priceKey(craft)]=result[combined];result[combined]=nil end
			local sulphur=api.integer(craft.allflame.sulphur,0,1000000000,"observed Sulphur cost")
			if sulphur > 0 then result.dead_mans_sulphur=sulphur end
		end
		return result
	end
	M.limits[#M.limits+1]="Allflame uses supplied Vesper settings: maximum outcomes, Intangibility gain range and Sulphur cost. Ghost outcomes apply independently to the same input. Intangibility can collapse the entire craft to one outcome; only multiple outcomes add Intangibility. Gain ranges are sampled uniformly. Recipes choose the most matching preferred target groups, breaking ties by first outcome, or use an explicit fixed index."
	M.limits[#M.limits+1]="Allflame settings are observations, not a verified automatic per-currency table. Intangibility is retained in structured state; native item text alone does not retain it. Awakener reset interactions still need validation."
end
return F
