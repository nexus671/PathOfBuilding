-- Independent ghost outcomes using pinned client tables or an observed override.
local F={}
local catalog
local names={transmute="Orb of Transmutation",alteration="Orb of Alteration",augmentation="Orb of Augmentation",regal="Regal Orb",alchemy="Orb of Alchemy",chaos="Chaos Orb",exalt="Exalted Orb",annul="Orb of Annulment",scour="Orb of Scouring",divine="Divine Orb",blessed="Blessed Orb",sacred="Sacred Orb",binding="Orb of Binding",fracture="Fracturing Orb",dominance="Orb of Dominance",conflict="Orb of Conflict",veiled_orb="Veiled Exalted Orb",eldritch_exalt="Eldritch Exalted Orb",eldritch_annul="Eldritch Orb of Annulment",eldritch_chaos="Eldritch Chaos Orb",remembrance="Orb of Remembrance",unravelling="Orb of Unravelling",foulborn_augmentation="Foulborn Orb of Augmentation",foulborn_regal="Foulborn Regal Orb",foulborn_exalt="Foulborn Exalted Orb",ducat_cyaxan="Cyaxan's Ducat",ducat_merrick="Merrick's Ducat",ducat_brinehook="Brinehook's Ducat",ducat_genteel="The Genteel's Ducat",ducat_rotmother="Rotmother's Ducat",ducat_kishara="Kishara's Ducat",ducat_tzamoto="Tzamoto's Ducat"}
function F.data()
	if not catalog then
		local root=GetScriptPath();local file=assert(io.open((root ~= "" and root.."/" or "").."Data/Crafting/Allflame.json","rb"))
		local text=file:read("*a");file:close();catalog=assert(require("dkjson").decode(text))
		catalog.byName={};for id,entry in pairs(catalog.currencies) do catalog.byName[entry.name]=id end
	end
	return catalog
end
function F.extend(M,A,api)
	local model,validate,action,calculate,components,priceKey=M.model,M.validateState,M.action,M.calculate,M.components,M.priceKey
	local function settings(craft) return craft.allflame or craft.method == "ducat_kishara" and {auto=true,upgradeTier=2} end
	function M.allflameProfile(model,state,craft)
		local profile=assert(settings(craft),"Enable Allflame first")
		if not profile.auto then return copyTable(profile) end
		model=M.context(model,state)
		local data=F.data();local id=data.byName[names[craft.method]]
		if craft.method == "essence" then id=craft.essenceId end
		if craft.method == "fossil" then
			local count=#(craft.fossils or {});id=data.byName[({"Primitive Chaotic Resonator","Potent Chaotic Resonator","Powerful Chaotic Resonator","Prime Chaotic Resonator"})[count]]
		end
		if craft.method == "influence_exalt" then for _,info in ipairs(itemLib.influenceInfo.all) do if info.key == craft.influence then id=data.byName[info.display.."'s Exalted Orb"] end end end
		local entry=assert(data.currencies[id],"This currency has no Allflame profile in the current client data")
		local tier=api.integer(profile.upgradeTier or 2,0,2,"Allflame upgrade tier")
		local selected
		for _,row in ipairs(entry.tiers) do if row.tier <= tier and (not selected or row.tier > selected.tier) then selected=row end end
		assert(selected and selected.minOutcomes == selected.outcomes,"This Allflame outcome range needs a verified distribution")
		local class=data.baseClasses[model.item.baseName];local classInfo=assert(data.classes[class],"This item class has no Allflame profile in the current client data")
		local scaling=classInfo.levelScaling and assert(data.levels[tostring(model.item.itemLevel)],"Missing Allflame item-level cost factor") or 0
		local result=copyTable(profile)
		result.outcomes=selected.outcomes;result.gainMin=selected.gainMin;result.gainMax=selected.gainMax
		result.sulphur=math.ceil(selected.baseCost*classInfo.costPercent*(100+scaling)/10000)
		result.currency=id;result.itemClass=class;result.upgradeTier=selected.tier;result.dataPatch=data.patch
		return result
	end
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
		local profile=settings(craft)
		if not profile then return action(model,input,craft,random) end
		assert(names[craft.method] or craft.method == "fossil" or craft.method == "essence" or craft.method == "influence_exalt","This action is not an itemised currency supported by the Allflame model")
		profile=M.allflameProfile(model,input,craft)
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
			state.imprint=nil
			local gain=count > 1 and low+math.floor(random()*(high-low+1)) or 0
			state.intangibility=math.min(100,(state.intangibility or input.intangibility or 0)+gain)
			choices[i]={state=state,itemText=not state.veil and not state.destroyed and M.toItem(model,state).raw or nil}
			local score=0
			if not state.destroyed then for _,target in ipairs(profile.preferredTargets or {}) do if M.matches(state,{target},nil,model) then score=score+1 end end end
			if score > bestScore then best,bestScore=i,score end
		end
		local selected=profile.choiceIndex and math.min(count,profile.choiceIndex) or best
		return choices[selected].state,{choices=choices,allflame={selected=selected,collapsed=collapsed,outcomes=count,sulphur=profile.sulphur,profile=profile,settings=copyTable(settings(craft))}}
	end
	function M.calculate(raw,craft,targets,initialState)
		if not settings(craft) then return calculate(raw,craft,targets,initialState) end
		local itemModel=M.model(raw);local state=initialState and M.validateState(itemModel,initialState) or copyTable(itemModel.initial)
		itemModel=M.context(itemModel,state)
		local profile=M.allflameProfile(itemModel,state,craft)
		M.action(itemModel,state,craft,function() return 0.5 end)
		local plain=copyTable(craft);plain.allflame=nil
		local result=calculate(raw,plain,targets,initialState)
		local preferences=profile.preferredTargets or targets
		for _,group in ipairs(preferences) do assert(not group.minRoll,"Use simulation for Allflame roll-value thresholds") end
		local mass={}
		for _,entry in ipairs(result.outcomes) do
			local candidate=entry.state and copyTable(entry.state) or copyTable(state)
			if not entry.state then
				candidate.affixes[#candidate.affixes+1]={id=entry.id,range=0.5}
				if (M.baseCurrency and M.baseCurrency(craft) or craft.method) == "regal" then candidate.rarity="RARE" end
				if craft.method == "influence_exalt" then candidate.influences={craft.influence} end
			end
			local score=0
			if not candidate.destroyed then for _,group in ipairs(preferences) do if M.matches(candidate,{group},nil,itemModel) then score=score+1 end end end
			entry.selectionScore=score;entry.singleDrawChance=entry.chance
			if entry.state then
				entry.text=candidate.destroyed and "Destroyed" or #candidate.affixes == 1 and table.concat(itemModel.byId[candidate.affixes[1].id]," / ") or "Intangibility reset"
				entry.state=nil -- Gain rolls are marginalised, not a concrete final item.
			end
			mass[score]=(mass[score] or 0)+entry.chance/100
		end
		local cumulative,selected=0,{}
		for score=0,#preferences do
			local nextMass=cumulative+(mass[score] or 0)
			selected[score]=nextMass^profile.outcomes-cumulative^profile.outcomes
			cumulative=nextMass
		end
		local collapse=profile.outcomes > 1 and (state.intangibility or 0)/100 or 0
		local success=0
		for _,entry in ipairs(result.outcomes) do
			local probability=entry.singleDrawChance/100
			if not profile.choiceIndex then probability=probability*(collapse+(1-collapse)*selected[entry.selectionScore]/mass[entry.selectionScore]) end
			entry.chance=100*probability
			if entry.matches then success=success+entry.chance end
		end
		result.successChance=success;result.matchingWeight=nil
		result.exactFor="Finite ghost choices under the stated independent-draw, collapse and selection assumptions"
		result.allflameProfile=profile;result.collapseChance=collapse*100
		result.limitations=copyTable(M.limits)
		return result
	end
	function M.priceKey(craft) return settings(craft) and "allflame:"..priceKey(craft) or priceKey(craft) end
	function M.components(craft,state,model)
		local result=components(craft,state)
		if settings(craft) then
			-- Preserve the ordinary currency component when its default key is used.
			local combined=M.priceKey(craft);if result[combined] then result[priceKey(craft)]=result[combined];result[combined]=nil end
			local profile=M.allflameProfile(model,state,craft)
			local sulphur=api.integer(profile.sulphur,0,1000000000,"Sulphur cost")
			if sulphur > 0 then result.dead_mans_sulphur=sulphur end
		end
		return result
	end
	M.limits[#M.limits+1]="Allflame derives maximum outcomes, Intangibility gain ranges and scaled Sulphur costs from pinned 3.29.3c client tables, or uses an explicit observed override. Ghost outcomes apply independently to the same input. Intangibility can collapse the entire craft to one outcome; only multiple outcomes add Intangibility. Gain ranges are sampled uniformly. Recipes choose the most matching preferred target groups, breaking ties by first outcome, or use an explicit fixed index."
	M.limits[#M.limits+1]="Client tables determine Allflame settings; uniform Intangibility gains and collapse probabilities remain model assumptions. Allflame consumes existing imprints. Intangibility is retained in structured state; native item text alone does not retain it."
end
return F
