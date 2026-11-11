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
	local controls,history,actions={},{},{}
	local sequence=0
	local height=math.min(740,main.screenH-60)
	label(controls,"intro",16,24,"Native crafting: emulated items stay separate from your build until reviewed.")
	controls.output=new("TextListControl"):TextListControl({"TOPLEFT",nil,"TOPLEFT"},{448,58,416,height-126},nil,{})
	local function refresh(extra)
		local lines={ }
		if extra then for _,line in ipairs(extra) do lines[#lines+1]=line end end
		local item=simulator.toItem(model,state)
		lines[#lines+1]=""
		lines[#lines+1]=item.baseName.." | "..state.rarity.." | item level "..item.itemLevel
		for _,entry in ipairs(state.affixes) do
			local mod=model.byId[entry.id]
			local values={ }
			for _,line in ipairs(mod) do values[#values+1]=itemLib.applyRange(line,entry.range or 0.5) end
			lines[#lines+1]=mod.type..(entry.fractured and " (fractured)" or entry.crafted and " (crafted)" or "")..": "..table.concat(values," / ")
		end
		lines[#lines+1]=""; lines[#lines+1]="Target groups (all required)"
		for index,group in ipairs(targets) do
			local names={ }
			for _,id in ipairs(group.anyOf) do names[#names+1]=model.byId[id] and table.concat(model.byId[id]," / ") or id end
			lines[#lines+1]=index..". "..table.concat(names," OR ")
		end
		lines[#lines+1]=""
		for _,line in ipairs(simulator.limits) do lines[#lines+1]=line end
		controls.output.list=rows(lines)
	end
	label(controls,"methodLabel",16,64,"Crafting action")
	local methods={ }
	for _,method in ipairs(simulator.methods) do methods[#methods+1]={label=simulator.labels[method],val=method} end
	controls.method=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,84,416,24},methods)
	local choices={ }
	for _,entry in ipairs(model.bench) do choices[#choices+1]={label=table.concat(entry.mod," / "),val=entry.id} end
	for _,entry in ipairs(model.essences) do choices[#choices+1]={label=entry.name,val=entry.id} end
	label(controls,"optionLabel",16,124,"Bench modifier or essence (only for those actions)")
	controls.option=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,144,416,24},choices)
	controls.method.selFunc=function()
		local list={ }
		if controls.method:GetSelValueByKey("val") == "bench" then for _,entry in ipairs(model.bench) do list[#list+1]={label=table.concat(entry.mod," / "),val=entry.id} end
		elseif controls.method:GetSelValueByKey("val") == "essence" then for _,entry in ipairs(model.essences) do list[#list+1]={label=entry.name,val=entry.id} end end
		controls.option:SetList(list)
	end
	controls.option.enabled=function() return controls.method:GetSelValueByKey("val") == "bench" or controls.method:GetSelValueByKey("val") == "essence" end
	label(controls,"seedLabel",16,184,"Seed")
	edit(controls,"seed",16,204,130,24,"104729","Seed",12)
	local function action()
		local method=controls.method:GetSelValueByKey("val")
		local option=(method == "bench" or method == "essence") and controls.option:GetSelValueByKey("val") or nil
		return {method=method,modId=method == "bench" and option or nil,essenceId=method == "essence" and option or nil}
	end
	button(controls,"apply",162,204,130,"Apply currency",function()
		sequence=sequence+1
		local result=simulator.perform(draft.startingItem,action(),assert(tonumber(controls.seed.buf),"Invalid seed")+sequence-1,state)
		history[#history+1]=copyTable(state)
		if #history > 40 then table.remove(history,1) end
		state=result.state; actions[#actions+1]=action()
		refresh({"Last action seed: "..(tonumber(controls.seed.buf)+sequence-1)})
	end)
	button(controls,"undo",308,204,124,"Undo currency",function() assert(#history > 0,"No currency action to undo"); state=table.remove(history); table.remove(actions); refresh() end)
	label(controls,"targetLabel",16,250,"Target modifier (add several for AND conditions)")
	local mods={ }
	for _,entry in ipairs(model.mods) do mods[#mods+1]={label=entry.mod.type.." | "..table.concat(entry.mod," / ").." | iLvl "..entry.mod.level,val=entry.id} end
	for _,entry in ipairs(model.essences) do mods[#mods+1]={label=entry.name.." guaranteed mod",val=entry.modId} end
	controls.target=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,270,416,24},mods)
	button(controls,"addTarget",16,310,132,"Add target",function()
		assert(#targets < 6,"Use up to six target groups")
		targets[#targets+1]={anyOf={controls.target:GetSelValueByKey("val")}}; refresh()
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
			local a=action(); local key=a.method == "bench" and a.modId or a.method == "essence" and a.essenceId or a.method
			prices={[key]=assert(tonumber(controls.price.buf),"Invalid unit price")}
		end
		local result=simulator.simulate(draft.startingItem,recipe,{trials=assert(tonumber(controls.trials.buf),"Invalid trial count"),maxActions=budget,seed=assert(tonumber(controls.seed.buf),"Invalid seed"),
			initialState=fromInitial and initial or state,prices=prices,currency=controls.currency.buf})
		local lines={string.format("Modeled successes: %d / %d (%.2f%%)",result.successes,result.trials,result.successChance),string.format("95%% sampling interval: %.2f%% to %.2f%%",result.confidenceLow,result.confidenceHigh),string.format("Mean attempted actions: %.2f",result.meanActions)}
		if result.meanCost then lines[#lines+1]=string.format("Mean spent: %.2f %s",result.meanCost,result.costCurrency) else lines[#lines+1]="Cost unavailable: some executed actions have no supplied price." end
		for key,count in pairsSortByKey(result.currencySpent) do lines[#lines+1]=key..": "..count.." total uses" end
		for message,count in pairsSortByKey(result.transitionErrors) do lines[#lines+1]="Failed transitions: "..count.." | "..message end
		refresh(lines)
	end
	button(controls,"simulate",16,486,200,"Simulate selected action",function()
		local a=action(); a.maxAttempts=math.min(200,assert(tonumber(controls.budget.buf),"Invalid budget")); a.untilTargets=copyTable(targets)
		showSimulation({steps={a},targets=copyTable(targets)},false)
	end)
	button(controls,"runRecipe",232,486,200,"Simulate saved recipe",function() assert(draft.nativeRecipe,"This project has no saved native recipe"); showSimulation(draft.nativeRecipe,true) end)
	button(controls,"keepRecipe",16,530,200,"Keep actions as recipe",function()
		assert(#actions > 0,"Apply a crafting action first")
		draft.nativeRecipe=simulator.validateRecipe({steps=copyTable(actions),targets=copyTable(targets),initialState=copyTable(initial),rarity=state.rarity})
		draft.targetItem=simulator.toItem(model,state).raw
		build.savers.CraftingProjects:Upsert(draft)
		refresh({"Native recipe and target kept in this build. Use build Save to persist."})
	end)
	button(controls,"reset",232,530,200,"Reset item",function() state=copyTable(initial); history={}; actions={}; refresh() end)
	button(controls,"preview",16,height-48,200,"Preview outcome in build",function()
		local entry=copyTable(draft); entry.targetItem=simulator.toItem(model,state).raw
		require("Classes.CraftingProjectControl").Preview(build,entry)
	end)
	button(controls,"close",748,height-48,116,"Close",function() main:ClosePopup() end)
	refresh()
	main:OpenPopup(880,height,"Native crafting emulator and simulator",controls,nil,nil,"close")
end
return Panel
