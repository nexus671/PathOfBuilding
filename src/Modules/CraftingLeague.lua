-- Current league services with no ordinary currency equivalent.
local L={}
function L.extend(M,A,api)
	local labels={beast_talisman_fracture="Bestiary: fracture a Talisman",ducat_tzamoto="Tzamoto's Ducat",ducat_kishara="Kishara's Ducat"}
	for method,label in pairs(labels) do M.methods[#M.methods+1]=method;M.labels[method]=label end;table.sort(M.methods)
	local action,options=M.action,M.actionOptions
	function M.action(model,input,craft,random)
		if not labels[craft.method] then return action(model,input,craft,random) end
		model=M.context(model,input)
		assert(not input.destroyed and not input.mirrored and not input.veil,"Use an intact, non-mirrored item without a pending unveil")
		local state=copyTable(input)
		if craft.method == "beast_talisman_fracture" then
			local count=api.integer(craft.count or 1,1,2,"Talisman fractures")
			assert(model.item.base.tags.talisman and state.rarity == "RARE","This Bestiary craft requires a rare Talisman")
			assert(#state.affixes >= (count == 1 and 4 or 6),"The one-fracture craft requires four modifiers; the two-fracture craft requires six")
			local eligible={}
			for i,entry in ipairs(state.affixes) do assert(not entry.fractured,"Use a Talisman without existing fractured modifiers");eligible[#eligible+1]=i end
			for _=1,count do local index=math.floor(random()*#eligible)+1;state.affixes[table.remove(eligible,index)].fractured=true end
		elseif craft.method == "ducat_kishara" then
			assert(not state.corrupted and #state.affixes > 0,"Kishara requires an uncorrupted item with at least one modifier")
			state.affixes={copyTable(state.affixes[math.floor(random()*#state.affixes)+1])};state.imprint=nil
		else
			assert((state.intangibility or 0) > 0,"The item has no Intangibility to remove")
			if random() < 0.5 then state.intangibility=0
			else state.destroyed=true;state.affixes={};state.imprint=nil;state.implicits=nil;state.corruptedImplicits=nil end
		end
		return state
	end
	local transition=M.action
	function M.actionOptions(model,state,method)
		if method == "beast_talisman_fracture" then return {
			{label="Fracture one modifier (at least four affixes)",action={method=method,count=1}},
			{label="Fracture two modifiers (six affixes)",action={method=method,count=2}}} end
		return options(model,state,method)
	end
	local calculate=M.calculate
	function M.calculate(raw,craft,targets,initialState)
		if not labels[craft.method] then return calculate(raw,craft,targets,initialState) end
		M.validateRecipe({steps={craft},targets=targets})
		local model=M.model(raw);local state=initialState and M.validateState(model,initialState) or copyTable(model.initial)
		model=M.context(model,state)
		-- Validate before enumerating; use this layer's transition to avoid ghost selection.
		transition(model,state,craft,function() return 0.5 end)
		local outcomes={}
		local function keep(nextState)
			outcomes[#outcomes+1]={state=nextState,matches=M.matches(nextState,targets,nil,model),weight=1}
		end
		if craft.method == "beast_talisman_fracture" then
			local count=craft.count or 1
			for i=1,#state.affixes do
				for j=(count == 2 and i+1 or i),(count == 2 and #state.affixes or i) do
					local nextState=copyTable(state);nextState.affixes[i].fractured=true;nextState.affixes[j].fractured=true;keep(nextState)
				end
			end
		elseif craft.method == "ducat_kishara" then
			for i=1,#state.affixes do keep(transition(model,state,craft,function() return (i-0.5)/#state.affixes end)) end
		else
			keep(transition(model,state,craft,function() return 0.25 end));keep(transition(model,state,craft,function() return 0.75 end))
		end
		local hits=0;for _,entry in ipairs(outcomes) do entry.chance=100/#outcomes;if entry.matches then hits=hits+1 end end
		return {exactFor="Complete finite outcomes under the stated transition assumptions",successChance=100*hits/#outcomes,totalWeight=#outcomes,matchingWeight=hits,outcomes=outcomes,dataPatch=M.dataPatch,limitations=copyTable(M.limits)}
	end

	local priceKey=M.priceKey
	function M.priceKey(craft) if craft.method == "beast_talisman_fracture" then return craft.method..":"..tostring(craft.count or 1) end;return priceKey(craft) end
	M.limits[#M.limits+1]="Talisman Bestiary fractures sample distinct modifiers uniformly on a non-fractured rare Talisman, including corrupted Talismans. Tzamoto uses an assumed 50/50 Intangibility reset or terminal destruction."
end
return L
