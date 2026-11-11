-- Native item emulator and bounded recipe trials, isolated from equipped items.
local simulator=require("Modules.CraftingSimulator")
local Panel={ }
local function button(controls,key,x,y,w,label,callback)
	controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function()
		local ok,err=pcall(callback)
		if not ok then main:OpenMessagePopup("Native crafting",tostring(err):match("^[^\n]+")) end
	end)
end
local function edit(controls,key,x,y,w,h,value,prompt,limit)
	controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",prompt,nil,limit,nil,h > 24 and 16 or nil)
end
local function rows(lines)
	local result={ }
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=StripEscapes(part)
			while #part > 50 do result[#result+1]={height=18,part:sub(1,50)}; part=part:sub(51) end
			result[#result+1]={height=18,part}
		end
	end
	return result
end
local function label(controls,key,x,y,text)
	controls[key]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},text)
end

function Panel.Open(build,project)
	local draft=copyTable(project)
	local model=simulator.model(draft.startingItem)
	local state=draft.nativeRecipe and draft.nativeRecipe.initialState and simulator.validateState(model,draft.nativeRecipe.initialState) or copyTable(model.initial)
	local initial=copyTable(state)
	local targets=draft.nativeRecipe and copyTable(draft.nativeRecipe.targets) or { }
	local requirements=draft.nativeRecipe and draft.nativeRecipe.requirements and copyTable(draft.nativeRecipe.requirements)
	local requiredGroups=draft.nativeRecipe and draft.nativeRecipe.requiredGroups
	local controls,history,actions={},{},{}
	local configured={}
	local sequence=0
	local lastSimulation
	local height=math.max(520,math.min(700,main.screenH-60))
	label(controls,"intro",16,24,"Native crafting: emulated items stay separate from your build until reviewed.")
	controls.output=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{448,92,416,height-160},nil,{})
	local function refresh(extra)
		local lines={ }
		if extra then for _,line in ipairs(extra) do lines[#lines+1]=line end end
		if state.destroyed then lines[#lines+1]="The hypothetical item was destroyed. Undo or reset to continue.";controls.output.list=rows(lines);return end
		local item=simulator.toItem(model,state)
		lines[#lines+1]=""
		lines[#lines+1]=item.baseName.." | "..state.rarity.." | item level "..item.itemLevel
		lines[#lines+1]="Memory strands: "..(state.memoryStrands or 0)
		lines[#lines+1]="Intangibility: "..(state.intangibility or 0).."%"
		for _,entry in ipairs(state.affixes) do
			local mod=model.byId[entry.id]
			local values={ }
			for _,line in ipairs(mod) do values[#values+1]=itemLib.applyRange(line,entry.range or 0.5) end
			lines[#lines+1]=mod.type..(entry.fractured and " (fractured)" or entry.crafted and " (crafted)" or "")..": "..table.concat(values," / ")
		end
		if state.veil then lines[#lines+1]="Pending unveil: choose Unveil to see the offered choices." end
		for _,entry in ipairs(state.implicits or {}) do lines[#lines+1]=entry.side.." tier "..entry.tier..": "..table.concat(model.byId[entry.id]," / ") end
		lines[#lines+1]=""; lines[#lines+1]="Target groups ("..(requiredGroups or "all").." required)"
		for index,group in ipairs(targets) do
			local names={ }
			for _,id in ipairs(group.anyOf) do names[#names+1]=model.byId[id] and table.concat(model.byId[id]," / ") or id end
			lines[#lines+1]=index..". "..(group.negate and "Exclude " or "Require ")..(group.atLeast or 1).." | "..table.concat(names," OR ")..(group.minRoll and " | minimum roll "..(group.minRoll*100).."%" or "")
		end
		for key,value in pairsSortByKey(requirements or {}) do lines[#lines+1]=key..": "..tostring(value) end
		lines[#lines+1]=""
		lines[#lines+1]="See Coverage for model assumptions and remaining gaps."
		controls.output.list=rows(lines)
	end
	label(controls,"methodLabel",16,64,"Crafting action")
	local methods={ }
	for _,method in ipairs(simulator.methods) do methods[#methods+1]={label=simulator.labels[method],val=method} end
	controls.method=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,84,416,24},methods)
	label(controls,"optionLabel",16,124,"Action options (dropdown search is available)")
	controls.option=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,144,416,24},{})
	local function updateOptions()
		local method=controls.method:GetSelValueByKey("val")
		controls.option:SetList(simulator.actionOptions(model,state,method))
	end
	controls.method.selFunc=updateOptions
	controls.option.enabled=function() return #controls.option.list > 0 end
	controls.option.selFunc=function() configured[controls.method:GetSelValueByKey("val")]=nil end
	label(controls,"seedLabel",16,184,"Seed")
	edit(controls,"seed",16,204,130,24,"104729","Seed",12)
	local function action()
		local method=controls.method:GetSelValueByKey("val")
		local option=controls.option:GetSelValue()
		return copyTable(configured[method] or option and option.action or {method=method})
	end

	button(controls,"apply",162,204,130,"Apply currency",function()
		sequence=sequence+1
		local craft=action();local usedSeed=assert(tonumber(controls.seed.buf),"Invalid seed")+sequence-1
		local result=simulator.perform(draft.startingItem,craft,usedSeed,state)
		local function keep(nextState,index)
			history[#history+1]=copyTable(state);if #history > 40 then table.remove(history,1) end
			if index then craft.allflame.choiceIndex=index end
			state=nextState;actions[#actions+1]=craft;updateOptions();refresh({"Last action seed: "..usedSeed})
		end
		if result.choices and #result.choices > 1 then
			local popup={};local choices={}
			for i=1,#result.choices do choices[i]={label="Ghost outcome "..i,val=i} end
			popup.choice=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,628,24},choices)
			popup.preview=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,70,628,300},nil,{})
			local function showChoice()
				local choice=result.choices[popup.choice:GetSelValueByKey("val")];local lines={"Intangibility: "..choice.state.intangibility.."%"}
				for line in (choice.itemText or (choice.state.veil and "Pending unveil" or "Destroyed")):gmatch("[^\r\n]+") do lines[#lines+1]=line end
				popup.preview.list=rows(lines)
			end
			popup.choice.selFunc=showChoice;showChoice()
			button(popup,"keep",16,390,200,"Keep ghost outcome",function() local index=popup.choice:GetSelValueByKey("val");keep(result.choices[index].state,index);main:ClosePopup() end)
			button(popup,"close",528,390,116,"Cancel",function() main:ClosePopup() end)
			main:OpenPopup(660,440,"Allflame outcomes",popup,nil,nil,"close")
		else keep(result.state) end
	end)
	button(controls,"undo",308,204,124,"Undo currency",function() assert(#history > 0,"No currency action to undo"); state=table.remove(history); table.remove(actions); updateOptions(); refresh() end)
	button(controls,"allflame",16,410,416,"Allflame: enter observed Vesper settings",function()
		local craft=action();local profile=craft.allflame or {};local popup={}
		label(popup,"hint",16,28,"Use the maximum outcomes, gain range and cost shown for this craft.")
		edit(popup,"outcomes",16,60,140,24,tostring(profile.outcomes or ""),"Max outcomes 1-4",12)
		edit(popup,"gainMin",172,60,140,24,tostring(profile.gainMin or ""),"Min gain %",12)
		edit(popup,"gainMax",328,60,140,24,tostring(profile.gainMax or ""),"Max gain %",12)
		edit(popup,"sulphur",16,100,296,24,tostring(profile.sulphur or ""),"Dead Man's Sulphur cost",12)
		label(popup,"policy",16,144,"Recipes prefer the most matching current target groups; ties keep the first.")
		button(popup,"use",16,186,200,"Use Allflame settings",function()
			local values={};for _,key in ipairs({"outcomes","gainMin","gainMax","sulphur"}) do values[key]=assert(tonumber(popup[key].buf),"Enter all four observed settings") end
			assert(values.outcomes == math.floor(values.outcomes) and values.outcomes >= 1 and values.outcomes <= 4,"Choose one to four outcomes")
			assert(values.gainMin >= 0 and values.gainMax >= values.gainMin and values.gainMax <= 100,"Invalid Intangibility gain range")
			if #targets > 0 then values.preferredTargets=copyTable(targets) end
			craft.allflame=values;configured[craft.method]=craft;main:ClosePopup();refresh({"Allflame settings enabled for "..simulator.labels[craft.method]})
		end)
		button(popup,"disable",232,186,200,"Use ordinary currency",function() craft.allflame=nil;configured[craft.method]=craft;main:ClosePopup() end)
		button(popup,"close",448,186,116,"Cancel",function() main:ClosePopup() end)
		main:OpenPopup(660,236,"Observed Allflame settings",popup,nil,nil,"close")
	end)
	button(controls,"configure",16,231,416,"Configure fossil combination / donor item",function()
		local method=controls.method:GetSelValueByKey("val")
		local popup={}
		if method == "fossil" then
			local choices={{label="None"}}; for _,entry in ipairs(model.fossils) do choices[#choices+1]={label=entry.name,id=entry.id} end
			for i=1,4 do popup["fossil"..i]=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,26+i*34,608,24},choices) end
			local outcomes={};for id,fossil in pairs(require("Modules.CraftingAdvanced").data().fossils) do if id:find("RandomFossilOutcome",1,true) then
				local descriptions={};for _,text in pairsSortByKey(fossil.descriptions) do descriptions[#descriptions+1]=text end
				outcomes[#outcomes+1]={label=table.concat(descriptions," / "),id=id}
			end end;table.sort(outcomes,function(a,b) return a.label < b.label end)
			popup.tangled=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,210,608,24},outcomes)
			button(popup,"use",16,260,180,"Use combination",function()
				local ids={};for i=1,4 do local value=popup["fossil"..i]:GetSelValue(); if value.id then ids[#ids+1]=value.id end end
				assert(#ids > 0,"Choose at least one fossil"); configured.fossil={method="fossil",fossils=ids,tangledOutcome=popup.tangled:GetSelValueByKey("id")}; main:ClosePopup()
			end)
		elseif method == "awakener" or method == "recombine" or method == "recombine_predictable" then
			edit(popup,"donor",16,36,608,170,"","Paste the donor item",24000)
			if method == "recombine_predictable" then
				edit(popup,"chance",16,216,180,24,"","In-game success %",12)
				label(popup,"selectionHint",208,221,"Exact target IDs select mods from each input.")
			end
			button(popup,"use",16,260,180,"Use donor",function()
				local craft={method=method,donorItem=popup.donor.buf}
				if method == "recombine_predictable" then
					local donor=simulator.model(popup.donor.buf);local selected={left={},right={}}
					for _,group in ipairs(targets) do
						assert(#group.anyOf == 1 and not group.negate and (group.atLeast or 1) == 1 and (group.scope or "explicit") == "explicit","Use exact explicit targets without alternatives for predictable selections")
						local id=group.anyOf[1];local side
						for key,input in pairs({left=state,right=donor.initial}) do for _,entry in ipairs(input.affixes) do if entry.id == id and not entry.fractured then assert(not side,"Selected modifier appears on both inputs; use the MCP action to select its input explicitly");side=key end end end
						assert(side,"Each selected target must be present on one input");selected[side][#selected[side]+1]=id
					end
					assert(#selected.left > 0 and #selected.right > 0,"Select at least one exact target from each input")
					craft.selectedMods=selected;craft.reportedSuccessChance=assert(tonumber(popup.chance.buf),"Enter the game's displayed success percentage")
					assert(craft.reportedSuccessChance >= 0 and craft.reportedSuccessChance <= 100,"Success percentage must be between 0 and 100")
				end
				configured[method]=craft;main:ClosePopup()
			end)
		else error("Select a fossil, Awakener's Orb or recombination first") end
		button(popup,"close",508,260,116,"Cancel",function() main:ClosePopup() end)
		main:OpenPopup(640,310,"Craft options",popup,nil,nil,"close")
	end)
	label(controls,"targetLabel",16,262,"Target modifier (add several for AND conditions)")
	local mods={ }
	for _,entry in ipairs(model.mods) do mods[#mods+1]={label=entry.mod.type.." | "..table.concat(entry.mod," / ").." | iLvl "..entry.mod.level,val=entry.id} end
	for _,entry in ipairs(model.essences) do mods[#mods+1]={label=entry.name.." guaranteed mod",val=entry.modId} end
	for id in pairs(model.special) do local mod=model.byId[id]; if mod.type == "Prefix" or mod.type == "Suffix" or mod.type == "Corrupted" or mod.type == "Exarch" or mod.type == "Eater" then mods[#mods+1]={label=mod.type.." | "..table.concat(mod," / "),val=id} end end
	controls.target=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,282,416,24},mods)
	button(controls,"addTarget",16,310,132,"Add target",function()
		assert(#targets < 6,"Use up to six target groups")
		local id=controls.target:GetSelValueByKey("val");local kind=model.byId[id].type
		targets[#targets+1]={anyOf={id},scope=(kind == "Exarch" or kind == "Eater" or kind == "Corrupted") and "implicit" or "explicit"}; refresh()
	end)
	button(controls,"alternative",160,310,132,"Add alternative",function()
		local group=assert(targets[#targets],"Add a target group first")
		assert(#group.anyOf < 30,"Use up to thirty alternatives per group")
		group.anyOf[#group.anyOf+1]=controls.target:GetSelValueByKey("val"); refresh()
	end)
	button(controls,"clearTargets",304,310,128,"Clear targets",function() targets={}; refresh() end)
	label(controls,"trialsLabel",16,354,"Trials / action budget per trial")
	edit(controls,"trials",16,374,130,24,"200","Trials",5)
	edit(controls,"budget",162,374,130,24,"20","Action budget",5)
	label(controls,"priceLabel",16,418,"Price per selected action / currency (optional)")
	edit(controls,"price",16,438,130,24,"","Unit price",16)
	edit(controls,"currency",162,438,130,24,"chaos","Currency",24)
	local function showSimulation(recipe,fromInitial)
		local budget=assert(tonumber(controls.budget.buf),"Invalid action budget")
		local prices
		if controls.price.buf ~= "" then
			local a=action(); local key=simulator.priceKey(a)
			prices={[key]=assert(tonumber(controls.price.buf),"Invalid unit price")}
		end
		local options={trials=assert(tonumber(controls.trials.buf),"Invalid trial count"),maxActions=budget,seed=assert(tonumber(controls.seed.buf),"Invalid seed"),
			initialState=copyTable(fromInitial and initial or state),prices=prices,currency=controls.currency.buf}
		local capturedRecipe=copyTable(recipe)
		require("Modules.CraftingTasks").start(build,function(checkpoint)
			options.checkpoint=checkpoint;return simulator.simulate(draft.startingItem,capturedRecipe,options)
		end,function(result)
			lastSimulation=result
			local lines={string.format("Modeled successes: %d / %d (%.2f%%)",result.successes,result.trials,result.successChance),string.format("95%% sampling interval: %.2f%% to %.2f%%",result.confidenceLow,result.confidenceHigh),string.format("Mean attempted actions: %.2f",result.meanActions),"Result uses the captured starting state."}
			if result.meanCost then lines[#lines+1]=string.format("Mean spent: %.2f %s",result.meanCost,result.costCurrency) else lines[#lines+1]="Cost unavailable: some executed actions have no supplied price." end
			for key,count in pairsSortByKey(result.currencySpent) do lines[#lines+1]=key..": "..count.." total uses" end
			for message,count in pairsSortByKey(result.transitionErrors) do lines[#lines+1]="Failed transitions: "..count.." | "..message end
			refresh(lines)
		end,function(message) refresh({message}) end,function(progress) refresh({"Simulation running: trial "..progress.trial.." / "..progress.trials}) end)
		refresh({"Simulation queued. You can cancel it below."})
	end
	button(controls,"simulate",16,486,200,"Simulate selected action",function()
		local a=action(); a.maxAttempts=math.min(200,assert(tonumber(controls.budget.buf),"Invalid budget")); a.untilTargets=#targets > 0 and copyTable(targets) or nil;a.untilRequirements=(requirements and copyTable(requirements) or nil)
		showSimulation({steps={a},targets=copyTable(targets),requirements=(requirements and copyTable(requirements) or nil),requiredGroups=requiredGroups},false)
	end)
	button(controls,"runRecipe",232,486,200,"Simulate saved recipe",function() assert(draft.nativeRecipe,"This project has no saved native recipe"); showSimulation(draft.nativeRecipe,true) end)
	button(controls,"keepRecipe",16,530,200,"Keep actions as recipe",function()
		assert(#actions > 0,"Apply a crafting action first")
		draft.nativeRecipe=simulator.validateRecipe({steps=copyTable(actions),targets=copyTable(targets),requirements=(requirements and copyTable(requirements) or nil),requiredGroups=requiredGroups,initialState=copyTable(initial),rarity=state.rarity})
		draft.targetItem=simulator.toItem(model,state).raw
		build.savers.CraftingProjects:Upsert(draft)
		refresh({"Native recipe and target kept in this build. Use build Save to persist."})
	end)
	button(controls,"editRecipe",16,574,200,"Recipe routes",function()
		local recipe=draft.nativeRecipe or {steps=copyTable(actions),targets=copyTable(targets),requirements=(requirements and copyTable(requirements) or nil),requiredGroups=requiredGroups,initialState=copyTable(initial)}
		require("Classes.CraftingRecipeControl").Open(recipe,action(),function(result) draft.nativeRecipe=result;build.savers.CraftingProjects:Upsert(draft);refresh({"Recipe kept. Use build Save to persist."}) end)
	end)
	button(controls,"targetConditions",16,650,416,"Target counts, rolls and item properties",function()
		require("Classes.CraftingTargetControl").Open(targets,requirements,requiredGroups,function(groups,properties,count) targets=groups;requirements=properties;requiredGroups=count;refresh() end)
	end)
	button(controls,"optimize",16,618,416,"Compare subsets of the configured fossils",function()
		local selected=action();assert(selected.method == "fossil" and selected.fossils,"Configure a fossil combination first")
		local options={fossils=copyTable(selected.fossils),initialState=copyTable(state),maxSockets=#selected.fossils,trials=assert(tonumber(controls.trials.buf)),seed=assert(tonumber(controls.seed.buf))}
		local captured=copyTable(targets)
		require("Modules.CraftingTasks").start(build,function(checkpoint) options.checkpoint=checkpoint;return simulator.optimizeFossils(draft.startingItem,captured,options) end,function(result)
			local lines={"Fossil subset comparison; no prices supplied to this comparison."}
			for _,entry in ipairs(result.combinations) do
				local names={};for _,id in ipairs(entry.fossils) do names[#names+1]=require("Modules.CraftingAdvanced").data().fossils[id].name end
				lines[#lines+1]=table.concat(names," + ").." | "..(entry.error or string.format("%.2f%% [%.2f-%.2f]",entry.successChance,entry.confidenceLow,entry.confidenceHigh))
			end
			refresh(lines)
		end,function(message) refresh({message}) end,function(progress) refresh({"Fossil combination "..progress.combination.." / "..progress.combinations}) end)
	end)
	button(controls,"exact",232,574,200,"Exact next-mod odds",function()
		local result=simulator.calculate(draft.startingItem,action(),targets,state)
		local lines={string.format("Exact next-mod target chance: %.6f%%",result.successChance),result.exactFor}
		for _,entry in ipairs(result.outcomes) do if entry.matches then lines[#lines+1]=string.format("%.6f%% | %s",entry.chance,entry.text) end end
		refresh(lines)
	end)
	button(controls,"distribution",448,height-48,140,"Results / distribution",function()
		local result=assert(lastSimulation,"Run a simulation first")
		local lines={{height=24,"Attempted actions per trial (all trials, including failures)"}}
		for _,bucket in ipairs(result.actionDistribution) do
			lines[#lines+1]={height=20,string.format("%4d | %s %d trials, %d successes",bucket.actions,string.rep("|",math.max(1,math.floor(bucket.trials/result.trials*50))),bucket.trials,bucket.successes)}
		end
		lines[#lines+1]={height=26,"Trials stopped at the action budget: "..result.budgetExhausted}
		lines[#lines+1]={height=24,"Hypothetical items destroyed: "..result.destroyedTrials}
		local function show(title,values)
			if not values then return end
			lines[#lines+1]={height=26,title}
			for _,key in ipairs({"p10","p25","p50","p75","p90","p95","p99"}) do lines[#lines+1]={height=20,key..": "..string.format("%.2f",values[key])} end
		end
		show("Actions among successful trials only",result.successfulActionQuantiles)
		show("Spending across all trials ("..result.costCurrency..")",result.spendingQuantiles)
		show("Spending among successful trials only",result.successfulSpendingQuantiles)
		for i,route in pairsSortByKey(result.routeCounts) do lines[#lines+1]={height=24,string.format("Step %d: %d visits, %d actions, %d success routes, %d failure routes",i,route.visits,route.executed,route.success,route.failure)} end
		local popup={}
		local resultHeight=math.max(420,math.min(650,main.screenH-60))
		popup.results=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,828,resultHeight-90},nil,lines)
		button(popup,"close",728,resultHeight-42,116,"Close",function() main:ClosePopup() end)
		main:OpenPopup(860,resultHeight,"Crafting simulation results",popup,nil,nil,"close")
	end)
	button(controls,"reset",232,530,200,"Reset item",function() state=copyTable(initial); history={}; actions={}; updateOptions();refresh() end)
	button(controls,"preview",16,height-48,200,"Preview outcome in build",function()
		assert(not state.veil and not state.destroyed,"A pending unveil or destroyed item cannot be previewed")
		local entry=copyTable(draft); entry.targetItem=simulator.toItem(model,state).raw
		require("Classes.CraftingProjectControl").Preview(build,entry)
	end)
	button(controls,"cancelJob",232,height-48,200,"Cancel crafting job",function() require("Modules.CraftingTasks").cancel() end)
	button(controls,"coverage",600,height-48,132,"Coverage",function()
		local popup={};local coverageHeight=math.max(420,math.min(650,main.screenH-60))
		popup.details=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,828,coverageHeight-90},nil,rows(simulator.limits))
		button(popup,"close",728,coverageHeight-42,116,"Close",function() main:ClosePopup() end)
		main:OpenPopup(860,coverageHeight,"Crafting coverage and assumptions",popup,nil,nil,"close")
	end)
	button(controls,"close",748,height-48,116,"Close",function() main:ClosePopup() end)
	controls.page=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,52,416,24},{"Emulate item","Target conditions","Simulate recipe"})
	local pages={
		["Emulate item"]={methodLabel=96,method=116,optionLabel=160,option=180,seedLabel=220,seed=240,apply=240,undo=240,configure=282,keepRecipe=330,reset=330,exact=374,allflame=410},
		["Target conditions"]={targetLabel=96,target=116,addTarget=154,alternative=154,clearTargets=154,targetConditions=202},
		["Simulate recipe"]={trialsLabel=96,trials=116,budget=116,priceLabel=160,price=180,currency=180,simulate=224,runRecipe=224,editRecipe=266,optimize=310,distribution=354},
	}
	for page,layout in pairs(pages) do for key,y in pairs(layout) do
		local control=controls[key];control.y=y;control.shown=function() return controls.page:GetSelValue() == page end
	end end
	controls.distribution.x=16;controls.distribution.width=416
	updateOptions(); refresh()
	main:OpenPopup(880,height,"Native crafting emulator and simulator",controls,nil,nil,"close")
end
return Panel
