-- Native item emulator and bounded recipe trials, isolated from equipped items.
local simulator=require("Modules.CraftingSimulator")
local workbench=require("Modules.CraftingWorkbench")
local ui=require("Modules.PlanningUI")
local inspect=require("Modules.CraftingInspection")
local browser=require("Classes.PlanningBrowserControl")
local Panel={ }
local pageHints={["Target conditions"]="Choose the modifiers and item properties you want.",["Simulate recipe"]="Compare modeled chances and costs before keeping a recipe.",["Craft settings"]="Advanced methods, item edits and recipe settings."}
local function button(controls,key,x,y,w,label,callback)
	controls[key]=new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,24},label,function()
		local ok,err=pcall(callback)
		if not ok then main:OpenMessagePopup("Native crafting",tostring(err):match("^[^\n]+")) else return err end
	end)
	ui.styleButton(controls[key])
end
local function edit(controls,key,x,y,w,h,value,prompt,limit)
	controls[key]=new("EditControl"):EditControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,w,h},value or "",prompt,h>24 and "^%C\t\n" or nil,limit,nil,h > 24 and 16 or nil)
end
local function rows(lines,width)
	width=width or 388
	local result={ }
	for _,line in ipairs(lines) do
		for part in tostring(line):gmatch("[^\r\n]+") do
			part=StripEscapes(part)
			while DrawStringWidth(18,"VAR",part) > width do
				local low,high=1,#part
				while low < high do local middle=math.ceil((low+high)/2);if DrawStringWidth(18,"VAR",part:sub(1,middle)) <= width then low=middle else high=middle-1 end end
				local space=part:sub(1,low):match("^.*()%s")
				local cut=space and space > 1 and space-1 or low
				result[#result+1]={height=18,colorCodes.NORMAL..part:sub(1,cut)};part=part:sub(cut+1):gsub("^%s+","")
			end
			result[#result+1]={height=18,colorCodes.NORMAL..part}
		end
	end
	return result
end
local function label(controls,key,x,y,text)
	controls[key]=new("LabelControl"):LabelControl({"TOPLEFT",nil,"TOPLEFT"},{x,y,0,14},colorCodes.NORMAL..text)
end

function Panel.Open(build,project,layout)
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
	local changedAffixes={}
	local favorites=layout and (layout.favorites or layout.workbench and layout.workbench.favorites) or {}
	if layout then layout.favorites=favorites end
	if layout then layout.selectedProject=draft.id end
	local restored=layout and layout.workbench or draft.run and require("Modules.CraftingCheckpoint").validate(draft.startingItem,draft.run)
	if layout then layout.workbench=nil end
	if restored then
		state=restored.state;initial=restored.initial;targets=restored.targets;requirements=restored.requirements;requiredGroups=restored.requiredGroups
		history=restored.history;actions=restored.actions;configured=restored.configured;sequence=restored.sequence;lastSimulation=restored.lastSimulation
	end
	local paletteOpen=restored and restored.paletteOpen or false
	local inspectedId=restored and restored.inspectedId
	local paletteView
	local populateAffix
	local width=layout and layout.width or math.min(1120,main.screenW-40)
	local height=layout and layout.height or math.max(520,math.min(740,main.screenH-60))
	local leftWidth=math.max(416,math.min(width-400,layout and layout.craftWidth or restored and restored.craftWidth or 416))
	local itemWidth=math.min(540,width-leftWidth-64)
	local itemX=leftWidth+32+math.floor((width-leftWidth-48-itemWidth)/2)
	label(controls,"intro",16,64,"Select a currency, then click your item to craft.")
	local refreshItem=workbench.item(controls,"item",itemX,112,itemWidth,height-184,model,function() return state end,function() controls.apply:Click() end,{header=196,artSize=96,compact=true,selectedAffix=function() return inspectedId end,changedAffixes=function() return changedAffixes end})
	controls.targetSummary=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,244,416,height-312},nil,{})
	local function refresh(extra)
		if inspectedId then local exists;for _,entry in ipairs(state.affixes) do if entry.id==inspectedId then exists=true end end;if not exists then inspectedId=nil end end
		refreshItem()
		local lines={inspect.slots(model,state),"Target groups: "..#targets.." ("..(requiredGroups or "all").." required)"}
		for index,group in ipairs(targets) do
			local names={}
			for _,id in ipairs(group.anyOf) do names[#names+1]=model.byId[id] and table.concat(model.byId[id]," / ") or "Unknown modifier" end
			lines[#lines+1]=index..". "..(group.negate and "Exclude " or "Require ")..(group.atLeast or 1)..": "..table.concat(names," OR ")
			if group.fractured ~= nil then lines[#lines+1]=group.fractured and "Fractured only" or "Not fractured" end
			if group.crafted ~= nil then lines[#lines+1]=group.crafted and "Crafted only" or "Not crafted" end
			if group.minRoll then lines[#lines+1]="Minimum roll: "..(group.minRoll*100).."%" end
		end
		for key,value in pairsSortByKey(requirements or {}) do lines[#lines+1]=key:gsub("(%l)(%u)","%1 %2")..": "..tostring(value) end
		controls.targetSummary.list=rows(lines)
		if extra and controls.resultSummary then controls.resultSummary.list=rows(extra) end
		local craftingPage=not controls.page or controls.page:GetSelValue()=="Emulate item"
		controls.intro.label="^7"..(craftingPage and inspectedId and "Modifier details. Your working item stays in view." or craftingPage and paletteOpen and "Find an action without leaving your working item." or extra and extra[1] or controls.page and pageHints[controls.page:GetSelValue()] or "Select a currency, then click your item to craft.")
		if controls.actionHint and controls.actionHint.list then controls.actionHint.list=ui.rows({workbench.hint(controls.method:GetSelValueByKey("val"),state,model)},leftWidth-30,14) end
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
	controls.option.selFunc=function()
		local method=controls.method:GetSelValueByKey("val");local previous=configured[method]
		configured[method]=nil
		if previous and previous.allflame and previous.allflame.auto then
			configured[method]=copyTable(controls.option:GetSelValue().action);configured[method].allflame=copyTable(previous.allflame)
		end
	end
	label(controls,"seedLabel",16,184,"Seed")
	edit(controls,"seed",16,204,130,24,"104729","Seed",12)
	local function action()
		local method=controls.method:GetSelValueByKey("val")
		local option=controls.option:GetSelValue()
		return copyTable(configured[method] or option and option.action or {method=method})
	end
	local function chooseMethod(method)
		paletteOpen=false;inspectedId=nil;controls.method:SelByValue(method,"val");updateOptions();refresh()
	end
	local function palette()
		paletteOpen=true;inspectedId=nil;paletteView.refresh();refresh()
		return controls.paletteSearch
	end
	local function pickTarget(id)
		assert(#targets<6,"Use up to six target groups")
		local kind=model.byId[id].type;targets[#targets+1]={anyOf={id},scope=(kind=="Exarch" or kind=="Eater" or kind=="Corrupted") and "implicit" or "explicit"};refresh()
	end
	populateAffix=function(id)
		local found;for _,entry in ipairs(state.affixes) do if entry.id==id then found=entry end end
		if not found then return end
		controls.affixFacts.list=ui.rows(inspect.modDetails(model,id,found),leftWidth-30)
		controls.affixFacts.controls.scrollBar.offset=0
		local entries={}
		for _,method in ipairs(found.crafted and {"remove_crafted","divine"} or found.fractured and {"divine","bench"} or {"divine","annul","bench"}) do
			entries[#entries+1]={val=method,label=simulator.labels[method]}
		end
		controls.affixAction:SetList(entries)
	end
	controls.itemMods.onClick=function(row)
		local id=row and row.line.affixId;if not id then return end
		inspectedId=id;paletteOpen=false;controls.page:SelByValue("Emulate item");populateAffix(id);refresh()
	end

	button(controls,"apply",162,204,130,"Apply currency",function()
		sequence=sequence+1
		local craft=action();local usedSeed=assert(tonumber(controls.seed.buf),"Invalid seed")+sequence-1
		local result=simulator.perform(draft.startingItem,craft,usedSeed,state)
		local function keep(nextState,index)
			changedAffixes={};local previous={};for _,entry in ipairs(state.affixes) do previous[entry.id]=require("dkjson").encode(entry) end
			for _,entry in ipairs(nextState.affixes) do if previous[entry.id]~=require("dkjson").encode(entry) then changedAffixes[entry.id]=true end end
			ui.draft(build,"workingCraft")
			history[#history+1]=copyTable(state);if #history > 40 then table.remove(history,1) end
			if index then craft.allflame=craft.allflame or copyTable(result.allflame.settings);craft.allflame.choiceIndex=index end
			state=nextState;actions[#actions+1]=craft;updateOptions();refresh({"Applied "..(simulator.labels[craft.method] or "craft")..". Select another currency or undo."})
		end
		if result.choices and #result.choices > 1 then
			local popup={};local choices={}
			for i=1,#result.choices do choices[i]={label="Ghost outcome "..i,val=i} end
			popup.choice=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,628,24},choices)
			local showChoice=workbench.item(popup,"preview",16,70,628,300,model,function()
				return result.choices[popup.choice:GetSelValueByKey("val")].state
			end)
			popup.choice.selFunc=showChoice;showChoice()
			button(popup,"keep",16,390,200,"Keep ghost outcome",function() local index=popup.choice:GetSelValueByKey("val");keep(result.choices[index].state,index);main:ClosePopup() end)
			button(popup,"close",528,390,116,"Cancel",function() main:ClosePopup() end)
			main:OpenPopup(660,440,"Allflame outcomes",popup,nil,nil,"close")
		else keep(result.state) end
	end)
	button(controls,"undo",308,204,124,"Undo currency",function() assert(#history > 0,"No currency action to undo"); state=table.remove(history);table.remove(actions);changedAffixes={};ui.draft(build,"workingCraft");updateOptions();refresh() end)
	button(controls,"history",232,390,200,"Item history",function()
		require("Classes.CraftingHistoryControl").Open(model,state,history,actions,function(saved,count)
			state=saved;for i=1,count do table.remove(history);table.remove(actions) end;updateOptions();refresh({"Restored an earlier working item."})
		end)
	end)
	button(controls,"compareItem",16,238,200,"Before / after",function()
		local entries={};for i,line in ipairs(inspect.diff(model,initial,state)) do entries[#entries+1]={id=i,label=line,details={line,"Compared with the recipe starting item."}} end
		browser.Open("Starting item versus working item",entries)
	end)
	button(controls,"inspectItem",16,338,416,"Inspect affixes and slots",function()
		local entries={};for _,entry in ipairs(state.affixes) do local id=entry.id;entries[#entries+1]={id=id,label=table.concat(model.byId[id]," / "),category=model.byId[id].type,details=function() return inspect.modDetails(model,id,entry) end} end
		browser.Open(inspect.slots(model,state),entries,{action="Use as target",choose=function(entry) pickTarget(entry.id);controls.page:SelByValue("Target conditions") end})
	end)
	button(controls,"allflame",16,410,416,"Allflame settings",function()
		local craft=action();local profile=craft.allflame or {};local popup={}
		popup.mode=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,28,296,24},{"Current game data","Observed override"})
		popup.mode:SelByValue(profile.outcomes and not profile.auto and "Observed override" or "Current game data")
		popup.upgrade=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{328,28,300,24},{{label="Ship: basic",val=0},{label="Ship: one upgrade",val=1},{label="Ship: fully upgraded",val=2}})
		popup.upgrade:SelByValue(profile.upgradeTier or 2,"val")
		popup.preview=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,70,628,100},nil,{})
		local function automatic() return popup.mode:GetSelValue() == "Current game data" end
		local function updateProfile()
			local copy=copyTable(craft);copy.allflame={auto=true,upgradeTier=popup.upgrade:GetSelValueByKey("val")}
			local ok,value=pcall(simulator.allflameProfile,model,state,copy)
			popup.preview.list=rows(ok and {value.outcomes.." ghost outcomes",string.format("Intangibility gain: %d-%d%% | Sulphur: %d",value.gainMin,value.gainMax,value.sulphur),"Choose the ship upgrades you have unlocked."} or {tostring(value):match("^[^\n]+")})
		end
		popup.upgrade.selFunc=updateProfile;popup.preview.shown=automatic;popup.upgrade.enabled=automatic
		edit(popup,"outcomes",16,80,140,24,tostring(profile.outcomes or ""),"Max outcomes 1-4",12)
		edit(popup,"gainMin",172,80,140,24,tostring(profile.gainMin or ""),"Min gain %",12)
		edit(popup,"gainMax",328,80,140,24,tostring(profile.gainMax or ""),"Max gain %",12)
		edit(popup,"sulphur",16,120,296,24,tostring(profile.sulphur or ""),"Dead Man's Sulphur cost",12)
		for _,key in ipairs({"outcomes","gainMin","gainMax","sulphur"}) do popup[key].shown=function() return not automatic() end end
		label(popup,"policy",16,184,"Recipes prefer the most matching target groups; ties keep the first.")
		button(popup,"use",16,228,200,"Use Allflame settings",function()
			local values
			if automatic() then
				values={auto=true,upgradeTier=popup.upgrade:GetSelValueByKey("val")}
				local copy=copyTable(craft);copy.allflame=values;simulator.allflameProfile(model,state,copy)
			else
				values={};for _,key in ipairs({"outcomes","gainMin","gainMax","sulphur"}) do values[key]=assert(tonumber(popup[key].buf),"Enter all four observed settings") end
				assert(values.outcomes == math.floor(values.outcomes) and values.outcomes >= 1 and values.outcomes <= 4,"Choose one to four outcomes")
				assert(values.gainMin >= 0 and values.gainMax >= values.gainMin and values.gainMax <= 100,"Invalid Intangibility gain range")
			end
			if #targets > 0 then values.preferredTargets=copyTable(targets) end
			craft.allflame=values;configured[craft.method]=craft;main:ClosePopup();refresh({"Allflame settings enabled for "..simulator.labels[craft.method]})
		end)
		button(popup,"disable",232,228,200,"Use ordinary currency",function() craft.allflame=nil;configured[craft.method]=craft;main:ClosePopup() end)
		button(popup,"close",448,228,116,"Cancel",function() main:ClosePopup() end)
		updateProfile();main:OpenPopup(660,280,"Allflame settings",popup,nil,nil,"close")
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
	button(controls,"targetPicker",16,188,416,"Find target modifiers",function()
		local entries={};local seen={}
		for _,entry in ipairs(mods) do if not seen[entry.val] then local id=entry.val;seen[id]=true;local mod=model.byId[id];entries[#entries+1]={id=id,label=table.concat(mod," / "),category=mod.type,search=table.concat(mod.tags or {}," "),details=function() return inspect.modDetails(model,id) end} end end
		browser.Open("Find target modifiers",entries,{action="Add target",choose=function(entry) pickTarget(entry.id) end})
	end)
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
	label(controls,"priceLabel",16,418,"Action price / currency / starting item cost (optional)")
	edit(controls,"price",16,438,130,24,"","Unit price",16)
	edit(controls,"currency",162,438,130,24,"chaos","Unit",24)
	edit(controls,"baseCost",308,438,124,24,"","Base cost",16)
	local function showSimulation(recipe,fromInitial)
		local budget=assert(tonumber(controls.budget.buf),"Invalid action budget")
		local prices
		if controls.price.buf ~= "" then
			local a=action(); local key=simulator.priceKey(a)
			prices={[key]=assert(tonumber(controls.price.buf),"Invalid unit price")}
		end
		local options={retainSuccesses=10,baseCost=controls.baseCost.buf ~= "" and assert(tonumber(controls.baseCost.buf),"Invalid starting item cost") or 0,trials=assert(tonumber(controls.trials.buf),"Invalid trial count"),maxActions=budget,seed=assert(tonumber(controls.seed.buf),"Invalid seed"),
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
		end,function(message) refresh({message}) end,function(progress) controls.resultSummary.list=rows({"Simulation running: trial "..progress.trial.." / "..progress.trials}) end)
		refresh({"Simulation queued. You can cancel it below."})
	end
	button(controls,"simulate",16,486,200,"Simulate action",function()
		local a=action();local attempts=assert(tonumber(controls.budget.buf),"Invalid budget");a.maxAttempts=math.min(200,attempts); a.untilTargets=#targets > 0 and copyTable(targets) or nil;a.untilRequirements=(requirements and copyTable(requirements) or nil)
		showSimulation({steps={a},targets=copyTable(targets),requirements=(requirements and copyTable(requirements) or nil),requiredGroups=requiredGroups},false)
	end)
	button(controls,"runRecipe",232,486,200,"Simulate saved recipe",function() assert(draft.nativeRecipe,"This project has no saved native recipe"); showSimulation(draft.nativeRecipe,true) end)
	button(controls,"compareRecipes",16,354,200,"Compare recipes",function()
		assert(#targets>0 or requirements and next(requirements),"Choose target modifiers or item conditions first")
		require("Classes.CraftingCompareControl").Open(build,draft.startingItem,copyTable(state),copyTable(targets),requirements and copyTable(requirements),requiredGroups,action(),draft.nativeRecipe,
			{trials=assert(tonumber(controls.trials.buf)),budget=assert(tonumber(controls.budget.buf)),seed=assert(tonumber(controls.seed.buf)),currency=controls.currency.buf})
	end)
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
	button(controls,"exact",232,574,200,"Calculate action odds",function()
		local craft=action();local captured=copyTable(state);local capturedTargets=copyTable(targets)
		local options={trials=assert(tonumber(controls.trials.buf)),seed=assert(tonumber(controls.seed.buf))}
		require("Modules.CraftingTasks").start(build,function(checkpoint)
			options.checkpoint=checkpoint;return simulator.calculate(draft.startingItem,craft,capturedTargets,captured,options)
		end,function(result)
			local lines={string.format("Target chance under model: %.6f%%",result.successChance),result.exactFor or result.estimateFor}
			if result.sampled then lines[#lines+1]=string.format("%d trials | 95%% interval %.2f%% to %.2f%%",result.trials,result.confidenceLow,result.confidenceHigh) end
			for _,entry in ipairs(result.outcomes) do if entry.matches then lines[#lines+1]=string.format("%.6f%% | %s",entry.chance,entry.text or "Finite item outcome") end end
			refresh(lines)
		end,function(message) refresh({message}) end,function(progress) refresh({"Calculating odds: trial "..progress.trial.." / "..progress.trials}) end)
	end)
	button(controls,"distribution",448,height-48,140,"Results / distribution",function()
		local result=assert(lastSimulation,"Run a simulation first")
		local lines={{height=24,"Attempted actions per trial (all trials, including failures)"}}
		for _,bucket in ipairs(result.actionDistribution) do
			lines[#lines+1]={height=20,string.format("%4d | %s %d trials, %d successes",bucket.actions,string.rep("|",math.max(1,math.floor(bucket.trials/result.trials*50))),bucket.trials,bucket.successes)}
		end
		lines[#lines+1]={height=26,"Trials stopped at the action budget: "..result.budgetExhausted}
		lines[#lines+1]={height=24,"Hypothetical items destroyed: "..result.destroyedTrials}
		lines[#lines+1]={height=24,"Spending percentiles include capped failures. They are not the cost of guaranteed success."}
		local function show(title,values)
			if not values then return end
			lines[#lines+1]={height=26,title}
			for _,key in ipairs({"p10","p25","p50","p75","p90","p95","p99"}) do lines[#lines+1]={height=20,key..": "..string.format("%.2f",values[key])} end
		end
		show("Actions among successful trials only",result.successfulActionQuantiles)
		show("Spending across all trials ("..result.costCurrency..")",result.spendingQuantiles)
		show("Spending among successful trials only",result.successfulSpendingQuantiles)
		if result.recovery then lines[#lines+1]={height=24,string.format("Recovery: %d restarted bases | %d stopped | %d set aside; no salvage proceeds assumed",result.recovery.restarts,result.recovery.stopped,result.recovery.salvaged)} end
		lines[#lines+1]={height=26,"Final modifier frequencies (all trials / successful trials)"}
		for id,bucket in pairsSortByKey(result.affixDistribution or {}) do
			lines[#lines+1]={height=22,string.format("%d / %d | %s",bucket.trials,bucket.successes,model.byId[id] and table.concat(model.byId[id]," / ") or id)}
		end
		for i,route in pairsSortByKey(result.routeCounts) do lines[#lines+1]={height=24,string.format("Step %d: %d visits, %d actions, %d success routes, %d failure routes",i,route.visits,route.executed,route.success,route.failure)} end
		local popup={}
		local resultHeight=math.max(420,math.min(650,main.screenH-60))
		local display={};for _,line in ipairs(lines) do for _,row in ipairs(require("Modules.PlanningUI").rows({line[1]},798)) do display[#display+1]=row end end;lines=display
		local cardWidth=195
		ui.card(popup,"successCard",16,28,cardWidth,"SUCCESS",string.format("%.1f%%",result.successChance),result.successes.." / "..result.trials.." trials")
		ui.card(popup,"attemptCard",227,28,cardWidth,"MEAN ACTIONS",string.format("%.1f",result.meanActions),"All trials, including failures")
		ui.card(popup,"costCard",438,28,cardWidth,"MEAN SPENDING",result.meanCost and string.format("%.2f",result.meanCost) or "Not priced",result.meanCost and result.costCurrency or "Unpriced actions")
		ui.card(popup,"intervalCard",649,28,195,"95% INTERVAL",string.format("%.1f-%.1f%%",result.confidenceLow,result.confidenceHigh),"Sampling uncertainty")
		ui.description(popup,"precision",16,132,828,32,{(result.trials<100 or result.confidenceHigh-result.confidenceLow>10) and "Imprecise estimate: run more trials before choosing a crafting route." or "Results describe the captured starting item, targets and supplied prices."},15)
		for index,entry in ipairs({{"medianSpend","MEDIAN SPEND","p50"},{"unluckySpend","90TH PERCENTILE","p90"},{"veryUnluckySpend","99TH PERCENTILE","p99"}}) do
			local values=result.spendingQuantiles;local value=values and string.format("%.2f",values[entry[3]]) or "Not priced"
			ui.card(popup,entry[1],16+(index-1)*282,174,264,entry[2],value,values and result.costCurrency or "Supply every action price")
		end
		popup.results=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,284,828,resultHeight-398},nil,lines)
		local kept={};for i,entry in ipairs(result.retainedSuccesses or {}) do kept[#kept+1]={label="Successful item "..i.." (trial "..entry.trial..")",val=i} end
		popup.item=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,resultHeight-84,540,24},kept)
		button(popup,"preview",572,resultHeight-84,272,"Preview retained item",function()
			local index=assert(popup.item:GetSelValueByKey("val"),"No successful items retained")
			local entry=copyTable(draft);entry.targetItem=result.retainedSuccesses[index].itemText
			require("Classes.CraftingProjectControl").Preview(build,entry)
		end)
		popup.item.enabled=#kept>0;popup.preview.enabled=#kept>0
		if #kept==0 then popup.item:SetList({{label="No successful items retained",val=0}}) end
		button(popup,"close",728,resultHeight-42,116,"Close",function() main:ClosePopup() end)
		button(popup,"sample",252,resultHeight-42,220,"Inspect sampled outcome",function()
			local c={};local w,h=math.min(660,main.screenW-40),math.min(560,main.screenH-48)
			ui.description(c,"hint",16,28,w-32,48,{result.sampleSuccess and "One successful sampled outcome. Other trials can differ." or "One unsuccessful sampled outcome. Inspect it before deciding whether to salvage or restart."},16)
			local render=require("Classes.JourneyItemControl").new(c,"sampleItem",16,92,w-32,h-166,"SAMPLED OUTCOME");render(require("Modules.CraftingProjects").item(result.sampleItem))
			button(c,"close",w-156,h-48,140,"Back to results",function() main:ClosePopup() end);ui.style(c);main:OpenPopup(w,h,"Sampled crafting outcome",c,nil,nil,"close")
		end)
		popup.sample.enabled=result.sampleItem~=nil
		button(popup,"moreTrials",16,resultHeight-42,220,"Run more trials",function()
			local budget=math.max(1,tonumber(controls.budget.buf) or 1);controls.trials:SetText(tostring(math.min(2000,math.floor(20000/budget),math.max(32,result.trials*4))));main:ClosePopup();controls.simulate:Click()
		end)
		popup.moreTrials.enabled=result.trials<math.min(2000,math.floor(20000/math.max(1,tonumber(controls.budget.buf) or 1)))
		ui.style(popup,{moreTrials=true})
		main:OpenPopup(860,resultHeight,"Crafting simulation results",popup,nil,nil,"close")
	end)
	button(controls,"manual",16,448,416,"Edit hypothetical item",function()
		require("Classes.CraftingItemEditorControl").Open(model,state,function(edited)
			state=edited;initial=copyTable(edited);history={};actions={};lastSimulation=nil;changedAffixes={};ui.draft(build,"workingCraft")
			updateOptions();refresh({"Manual edits set a new recipe starting state."})
		end)
	end)
	button(controls,"reset",232,530,200,"Reset item",function() state=copyTable(initial);history={};actions={};changedAffixes={};ui.draft(build,"workingCraft");updateOptions();refresh() end)
	button(controls,"preview",16,height-48,200,"Preview in build",function()
		assert(not state.veil and not state.destroyed,"A pending unveil or destroyed item cannot be previewed")
		local entry=copyTable(draft); entry.targetItem=simulator.toItem(model,state).raw
		require("Classes.CraftingProjectControl").Preview(build,entry)
	end)
	button(controls,"cancelJob",232,height-48,200,"Cancel crafting job",function() require("Modules.CraftingTasks").cancel() end)
	button(controls,"coverage",width-312,height-48,132,"Coverage",function()
		local entries={}
		for i,line in ipairs(simulator.limits) do entries[#entries+1]={id=i,label=line,category="Assumptions",details={line,"Data patch: "..tostring(simulator.dataPatch or "bundled")}} end
		for _,method in ipairs(simulator.methods) do entries[#entries+1]={id=method,label=simulator.labels[method],category=inspect.category(method),details={"Implemented in the bounded model",workbench.hint(method,state,model),"Item-specific options and prerequisites are validated when applying.","Coverage does not imply complete game parity."}} end
		browser.Open("Crafting coverage and assumptions",entries)
	end)
	button(controls,"close",width-164,height-48,148,layout and "Back to projects" or "Close",function() if layout then layout.openProjects() else main:ClosePopup() end end)
	controls.resultSummary=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{16,398,416,height-464},nil,rows({"Run an action or a recipe to inspect its results."}))
	controls.undo.enabled=function() return #history>0 end
	controls.simulate.enabled=function() return #targets>0 or requirements and next(requirements)~=nil end
	controls.simulate.tooltipText="Choose target modifiers or item conditions, then simulate the selected action."
	controls.runRecipe.enabled=function() return draft.nativeRecipe~=nil end
	controls.keepRecipe.enabled=function() return #actions>0 and not state.destroyed and not state.veil end
	controls.manual.enabled=function() return not state.destroyed and not state.veil end
	controls.optimize.enabled=function() local craft=configured.fossil;return controls.method:GetSelValueByKey("val")=="fossil" and craft and craft.fossils~=nil end
	controls.distribution.enabled=function() return lastSimulation~=nil end
	controls.cancelJob.enabled=function() return require("Modules.CraftingTasks").job~=nil end
	controls.apply.enabled=function() return not state.destroyed end
	controls.preview.enabled=function() return not state.destroyed and not state.veil end
	controls.configure.enabled=function() local method=controls.method:GetSelValueByKey("val");return method=="fossil" or method=="awakener" or method=="recombine" or method=="recombine_predictable" end
	controls.page=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,18,416,28},{"Emulate item","Target conditions","Simulate recipe","Craft settings"})
	controls.page.selFunc=function() refresh() end
	button(controls,"settings",16,380,200,"Find currencies",palette)
	local function crafting() return controls.page:GetSelValue()=="Emulate item" and not paletteOpen and not inspectedId end
	controls.item.enabled=function() return crafting() and controls.apply:IsEnabled() end
	controls.apply.x=16;controls.apply.width=200;controls.undo.x=232;controls.undo.width=200
	ui.label(controls,"selectedAction",16,230,"",20)
	controls.selectedAction.label=function()
		local name=simulator.labels[controls.method:GetSelValueByKey("val")];local suffix=""
		while #name>0 and DrawStringWidth(20,"VAR",name..suffix)>leftWidth do name=name:sub(1,-2);suffix="..." end
		return "^xE2C28C"..name..suffix
	end
	controls.actionHint=ui.description(controls,"actionHint",16,264,416,40,{})
	local pages={
		["Craft settings"]={methodLabel=96,method=116,configure=160,keepRecipe=198,reset=198,exact=238,compareItem=238,seedLabel=278,seed=298,inspectItem=338,allflame=378,manual=418},
		["Emulate item"]={selectedAction=230,actionHint=264,optionLabel=310,option=330,apply=370,undo=370,settings=414,history=414},
		["Target conditions"]={targetLabel=96,target=116,addTarget=154,alternative=154,clearTargets=154,targetPicker=188,targetConditions=226,targetSummary=270},
		["Simulate recipe"]={trialsLabel=96,trials=116,budget=116,priceLabel=160,price=180,currency=180,baseCost=180,simulate=224,runRecipe=224,editRecipe=266,optimize=310,distribution=354,compareRecipes=354,resultSummary=398},
	}
	for page,layout in pairs(pages) do for key,y in pairs(layout) do
		local control=controls[key];control.y=y;control.shown=page=="Emulate item" and crafting or function() return controls.page:GetSelValue()==page end
	end end
	controls.distribution.x=232;controls.distribution.width=200
	controls.option.shown=function() return crafting() and #controls.option.list>0 end
	controls.optionLabel.shown=controls.option.shown
	controls.apply.enabled=function() return workbench.available(controls.method:GetSelValueByKey("val"),state,model) end
	controls.apply.height=32;controls.undo.height=32
	controls.apply.y=function() return #controls.option.list>0 and 370 or 320 end;controls.undo.y=controls.apply.y
	controls.settings.y=function() return controls.apply:GetProperty("y")+44 end;controls.history.y=controls.settings.y
	controls.targetSummary.height=height-338
	controls.history.enabled=function() return #history>0 end
	controls.settings.label="Find currencies"
	controls.cancelJob.shown=function() return require("Modules.CraftingTasks").job~=nil end
	ui.style(controls,{apply=true,preview=true},{item=true})
	ui.tabs(controls,controls.page,{{"tab_craft","Emulate item","Craft"},{"tab_targets","Target conditions","Targets"},{"tab_simulate","Simulate recipe","Simulate"},{"tab_settings","Craft settings","Settings"}},16,18,416)
	workbench.currencies(controls,function(method)
		chooseMethod(method)
	end,function() return controls.method:GetSelValueByKey("val") end,crafting,function(method)
		local count=0;for _,entry in ipairs(actions) do if entry.method == method then count=count+1 end end;return count
	end,function() return state end,model,leftWidth)
	controls.methodLabel.label="More currencies and crafting methods"
	controls.optionLabel.label="Options for selected currency"
	controls.apply.label="Apply to item"
	ui.label(controls,"projectName",leftWidth+32,24,"",18)
	controls.projectName.label=function()
		local title=draft.title
		while #title>0 and DrawStringWidth(18,"VAR",title)>width-leftWidth-64 do title=title:sub(1,-2) end
		return "^7"..title
	end
	controls.stage=new("Control"):Control(ui.anchor,{leftWidth+32,84,width-leftWidth-48,height-148})
	function controls.stage:Draw()
		local x,y=self:GetPos();local w,h=self:GetSize()
		SetDrawLayer(nil,1);SetDrawColor("^x0A1018");DrawImage(nil,x,y,w,h);SetDrawColor("^x8D9DB0")
		DrawString(x+w/2,y+8,"CENTER_X",12,"VAR","WORKING ITEM");DrawString(x+w/2,y+h-2,"CENTER_X",12,"VAR","Click a modifier to inspect it | F: fractured | C: crafted");SetDrawLayer(nil,0)
	end
	for _,key in ipairs({"item","itemMods"}) do
		local control=controls[key];local draw=control.Draw
		function control:Draw(...) SetDrawLayer(nil,2);draw(self,...);SetDrawLayer(nil,0) end
	end
	if restored then
		controls.page:SelByValue(restored.page);controls.seed:SetText(restored.seed)
		for key,value in pairs(restored.settings or {}) do controls[key]:SetText(value) end
	end
	if layout then
		layout.snapshot=function() return copyTable({kind="workbench",project=draft,state=state,initial=initial,targets=targets,requirements=requirements,requiredGroups=requiredGroups,craftWidth=leftWidth,favorites=favorites,paletteOpen=paletteOpen,palette=paletteView and paletteView.snapshot(),inspectedId=inspectedId,
			history=history,actions=actions,configured=configured,sequence=sequence,lastSimulation=lastSimulation,page=controls.page:GetSelValue(),method=controls.method:GetSelValueByKey("val"),seed=controls.seed.buf,resultRows=controls.resultSummary.list,settings={trials=controls.trials.buf,budget=controls.budget.buf,price=controls.price.buf,currency=controls.currency.buf,baseCost=controls.baseCost.buf}}) end
	end
	button(controls,"keepWorking",232,height-48,200,"Keep working craft",function()
		local run={schemaVersion=1,state=state,initial=initial,history=history,actions=actions,configured=configured,sequence=sequence,targets=targets,requirements=requirements,requiredGroups=requiredGroups,
			page=controls.page:GetSelValue(),method=controls.method:GetSelValueByKey("val"),seed=controls.seed.buf,
			settings={trials=controls.trials.buf,budget=controls.budget.buf,price=controls.price.buf,currency=controls.currency.buf,baseCost=controls.baseCost.buf}}
		local saved=copyTable(draft);saved.run=run
		local kept=build.savers.CraftingProjects:Upsert(saved);draft=copyTable(kept)
		ui.kept(build,"workingCraft")
		refresh({"Working item, history and settings kept. Use build Save to resume after restarting. No budget was spent."})
	end)
	controls.keepWorking.shown=function() return require("Modules.CraftingTasks").job==nil end
	ui.styleButton(controls.keepWorking,"primary")
	paletteView=require("Modules.CraftingPalette").new(controls,leftWidth,height,{current=function() return controls.method:GetSelValueByKey("val") end,favorites=favorites,restore=restored and restored.palette,
		shown=function() return controls.page:GetSelValue()=="Emulate item" and paletteOpen end,available=function(method) return workbench.available(method,state,model) end,hint=function(method) return workbench.hint(method,state,model) end,
		choose=chooseMethod,close=function() paletteOpen=false;refresh() end})
	ui.label(controls,"affixHeading",16,96,"Modifier details",20)
	controls.affixFacts=new("TextListControl"):TextListControl(ui.anchor,{16,128,leftWidth,height-290},nil,{})
	controls.affixAction=new("DropDownControl"):DropDownControl(ui.anchor,{16,height-146,leftWidth-136,26},{})
	button(controls,"affixUseAction",leftWidth-108,height-146,124,"Select action",function() chooseMethod(controls.affixAction:GetSelValueByKey("val")) end)
	button(controls,"affixBack",16,height-98,math.floor((leftWidth-12)/2),"< Currency tray",function() inspectedId=nil;refresh() end)
	button(controls,"affixTarget",28+math.floor((leftWidth-12)/2),height-98,math.floor((leftWidth-12)/2),"Use as target",function() pickTarget(inspectedId);inspectedId=nil;controls.page:SelByValue("Target conditions");refresh() end)
	local affixControls={}
	for _,key in ipairs({"affixHeading","affixFacts","affixAction","affixUseAction","affixBack","affixTarget"}) do controls[key].shown=function() return controls.page:GetSelValue()=="Emulate item" and inspectedId~=nil end;affixControls[key]=controls[key] end
	controls.affixUseAction.enabled=function() local method=controls.affixAction:GetSelValueByKey("val");return method and workbench.available(method,state,model) end
	controls.affixBack.height=28;controls.affixTarget.height=28
	ui.style(affixControls,{affixTarget=true})
	for key,control in pairs(controls) do
		if key~="item" and key~="itemMods" and key~="stage" and key~="projectName" and not key:match("^currency_") and not key:match("^palette") and not key:match("^affix") and type(control.x)=="number" and control.x<448 and type(control.width)=="number" then
			control.x=16+math.floor((control.x-16)*leftWidth/416);if control.width>0 then control.width=math.floor(control.width*leftWidth/416) end
		end
	end
	if layout then ui.splitter(controls,"splitter",leftWidth+19,84,height-148,function(delta)
		layout.workbench=layout.snapshot();layout.craftWidth=math.max(416,math.min(width-400,leftWidth+delta));Panel.Open(build,draft,layout)
	end) end
	updateOptions();refresh()
	if restored then controls.method:SelByValue(restored.method or "alchemy","val");updateOptions();controls.resultSummary.list=restored.resultRows or controls.resultSummary.list
	elseif draft.preferredMethod then controls.method:SelByValue(draft.preferredMethod,"val");updateOptions() end
	if inspectedId then populateAffix(inspectedId) end
	for key,control in pairs(controls) do if key~="stage" then control.layoutAudit="crafting-workbench" end end
	if layout then layout.mount(width,height,"Crafting workbench",controls) else main:OpenPopup(width,height,"Crafting workbench",controls,nil,nil,"close") end
	return controls
end
return Panel
