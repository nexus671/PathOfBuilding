-- Predictable recombination is calibrated to the success percentage displayed
-- in game. No unverified per-class constant is silently substituted.
local P={}
local function family(id) return id:gsub("_+$",""):gsub("Maven.*$",""):gsub("%d+$","") end
function P.extend(M,A,api)
	M.methods[#M.methods+1]="recombine_predictable";M.labels.recombine_predictable="Predictable recombination (observed odds)";table.sort(M.methods)
	local originalAction,originalCalculate=M.action,M.calculate
	local function prepare(model,input,craft)
		model=M.context(model,input)
		local donor=M.model(assert(craft.donorItem,"Paste a donor item"))
		assert(model.item.type == donor.item.type and model.item.base.subType == donor.item.base.subType,"Recombination requires the same item class and subtype")
		assert(model.item.type ~= "Jewel" and model.item.type ~= "Flask" and model.item.type ~= "Tincture" and not model.item.synthesised and not donor.item.synthesised,"This predictable model supports non-synthesised equipment")
		for _,state in ipairs({input,donor.initial}) do assert(not state.corrupted and not state.mirrored and not state.destroyed and not state.veil,"Use uncorrupted, non-mirrored items without a pending unveil") end
		local selected=assert(craft.selectedMods,"Choose modifiers from each item")
		local models,states={model,donor},{input,donor.initial}
		local entries={{},{}};local groups={};local total=0
		for side,key in ipairs({"left","right"}) do
			local ids=selected[key];assert(type(ids) == "table" and #ids >= 1 and #ids <= 5,"Select at least one modifier from each input")
			for _,id in ipairs(ids) do
				local found;for _,entry in ipairs(states[side].affixes) do if entry.id == id then found=entry;break end end
				assert(found and not found.fractured,"Select a non-fractured modifier present on that input")
				for _,group in ipairs(A.data().mods[id] and A.data().mods[id].groups or {models[side].byId[id].group}) do assert(not groups[group],"Selected modifiers conflict");groups[group]=true end
				entries[side][#entries[side]+1]=copyTable(found);total=total+1
			end
		end
		assert(total <= 6,"Select at most six modifiers")
		local factors={};local outcomes={}
		for host=1,2 do
			local state=copyTable(states[host]);state.rarity="RARE";state.affixes={};state.imprint=nil
			for _,entry in ipairs(states[host].affixes) do if entry.fractured then state.affixes[#state.affixes+1]=copyTable(entry) end end
			for _,list in ipairs(entries) do for _,entry in ipairs(list) do state.affixes[#state.affixes+1]=copyTable(entry) end end
			local seen,c,valid={},{Prefix=0,Suffix=0},true
			for _,entry in ipairs(state.affixes) do
				local mod=models[host].byId[entry.id];assert(mod,"Modifier missing on the selected base")
				c[mod.type]=c[mod.type]+1
				for _,group in ipairs(A.data().mods[entry.id] and A.data().mods[entry.id].groups or {mod.group}) do if seen[group] then valid=false end;seen[group]=true end
			end
			local caps=M.capacities(models[host],state);if c.Prefix > caps.Prefix or c.Suffix > caps.Suffix then valid=false end
			local empty=copyTable(states[host]);empty.rarity="RARE";empty.affixes={};empty.memoryActive=nil
			local pool=M.pool(models[host],empty);local weights,sums={}, {Prefix=0,Suffix=0}
			for _,entry in ipairs(pool) do weights[entry.id]=entry.weight;local kind=models[host].byId[entry.id].type;sums[kind]=sums[kind]+entry.weight end
			local opposite=3-host;local product=1
			for _,entry in ipairs(entries[opposite]) do
				local mod=models[host].byId[entry.id];local cumulative=0
				if not weights[entry.id] then valid=false else
					for _,candidate in ipairs(pool) do if family(candidate.id) == family(entry.id) and models[host].byId[candidate.id].level >= mod.level then cumulative=cumulative+candidate.weight end end
				end
				product=product*(sums[mod.type] > 0 and cumulative/sums[mod.type] or 0)
			end
			local factorial=1;for i=2,#entries[opposite] do factorial=factorial*i end
			factors[host]=valid and product*factorial/(total-1) or 0
			state.baseItem=M.toItem(models[host],states[host]).raw;outcomes[host]=state
		end
		local reported=craft.reportedSuccessChance
		assert(type(reported) == "number" and reported == reported and reported >= 0 and reported <= 100,"Enter the in-game success percentage for exactly these inputs and selections")
		local wanted=reported/100
		local function chance(constant) return math.min(0.5,factors[1]*constant/2),math.min(0.5,factors[2]*constant/2) end
		local low,high=0,1
		while high < 1e18 do local left,right=chance(high);if left+right >= wanted then break end;high=high*2 end
		local maximumLeft,maximumRight=chance(high);assert(maximumLeft+maximumRight+1e-8 >= wanted,"Reported chance is incompatible with these selected modifiers and native base restrictions")
		for _=1,64 do local middle=(low+high)/2;local left,right=chance(middle);if left+right < wanted then low=middle else high=middle end end
		local left,right=chance((low+high)/2)
		return {left=left,right=right,states=outcomes,models=models,reportedSuccessChance=reported}
	end
	function M.action(model,input,craft,random)
		if craft.method ~= "recombine_predictable" then return originalAction(model,input,craft,random) end
		local result=prepare(model,input,craft);local pick=random();local state
		if pick < result.left then state=result.states[1] elseif pick < result.left+result.right then state=result.states[2]
		else state=copyTable(input);state.destroyed=true;state.affixes={};state.imprint=nil end
		state.origin=model.initial.origin;return state
	end
	function M.calculate(raw,craft,targets,initialState)
		if craft.method ~= "recombine_predictable" then return originalCalculate(raw,craft,targets,initialState) end
		local model=M.model(raw);local input=initialState and M.validateState(model,initialState) or model.initial
		local result=prepare(model,input,craft);local outcomes={};local success=0
		for host,key in ipairs({"left","right"}) do
			local hit=M.matches(result.states[host],targets,nil,result.models[host]);local probability=result[key]
			if hit then success=success+probability end
			outcomes[#outcomes+1]={chance=probability*100,matches=hit,text=(host == 1 and "Recipient: " or "Donor: ")..result.models[host].item.baseName}
		end
		return {exactFor="Calibrated predictable model, conditional on the supplied in-game success percentage; base shares remain model-dependent",successChance=success*100,reportedSuccessChance=result.reportedSuccessChance,destructionChance=(1-result.left-result.right)*100,outcomes=outcomes,limitations=copyTable(M.limits)}
	end
	M.limits[#M.limits+1]="Predictable recombination requires the in-game success percentage for the exact inputs and selected modifiers. The shared class constant is fitted to that observation; inferred base shares use the community transfer formula. This does not independently predict the game's displayed chance."
end
return P
