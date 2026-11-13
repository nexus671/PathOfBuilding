-- Paired bounded recipe experiments; each route starts from the same captured item.
local sim=require("Modules.CraftingSimulator")
local ui=require("Modules.PlanningUI")
local tasks=require("Modules.CraftingTasks")
local M={}
function M.Open(build,raw,state,targets,requirements,requiredGroups,current,saved,settings)
	local controls={};local width=math.min(960,main.screenW-40);local height=math.min(660,main.screenH-60)
	local model=sim.model(raw);local entries={};local recipes={};local chartResults
	local function add(label,recipe,priceKey) recipes[#recipes+1]={label=label,recipe=recipe,priceKey=priceKey};entries[#entries+1]={label=label,val=#recipes} end
	local selected=copyTable(current);selected.maxAttempts=math.min(200,settings.budget);selected.untilTargets=#targets>0 and copyTable(targets) or nil;selected.untilRequirements=requirements and copyTable(requirements)
	add("Selected action",{steps={selected},targets=copyTable(targets),requirements=requirements and copyTable(requirements),requiredGroups=requiredGroups},sim.priceKey(selected))
	if saved then local recipe=copyTable(saved);recipe.targets=copyTable(targets);recipe.requirements=requirements and copyTable(requirements);recipe.requiredGroups=requiredGroups;add("Saved recipe",recipe) end
	for _,method in ipairs({"alchemy","chaos","alteration","essence","fossil","harvest_reforge"}) do
		local available=require("Modules.CraftingWorkbench").available(method,state,model)
		local ok,options=pcall(sim.actionOptions,model,state,method)
		if available and ok and (#options==0 or method~="fossil") then
			local action=copyTable(options[1] and options[1].action or {method=method});action.maxAttempts=math.min(200,settings.budget);action.untilTargets=#targets>0 and copyTable(targets) or nil;action.untilRequirements=requirements and copyTable(requirements)
			add(sim.labels[method],{steps={action},targets=copyTable(targets),requirements=requirements and copyTable(requirements),requiredGroups=requiredGroups},sim.priceKey(action))
		end
	end
	ui.label(controls,"intro",16,26,"Compare recipes with the same item, targets, seed, trials and action budget.",14)
	ui.label(controls,"hint",16,50,"Prices in "..settings.currency..". Saved quotes apply to every route; action overrides apply to single actions.",14)
	for i=1,3 do
		controls["route"..i]=new("DropDownControl"):DropDownControl(ui.anchor,{16,82+(i-1)*38,width-218,26},entries)
		controls["route"..i]:SelByValue(math.min(i,#entries),"val")
		controls["price"..i]=new("EditControl"):EditControl(ui.anchor,{width-186,82+(i-1)*38,170,26},"","Action override",nil,16)
		local drop,input=controls["route"..i],controls["price"..i];local overrides={};local previous=drop:GetSelValueByKey("val")
		drop.selFunc=function() overrides[previous]=input.buf;previous=drop:GetSelValueByKey("val");input:SetText(overrides[previous] or "") end
		input.enabled=function() return recipes[drop:GetSelValueByKey("val")].priceKey~=nil end
		input.tooltipText="Override the complete price of one selected action. Saved recipes use their ingredient prices."
	end
	controls.results=new("TextListControl"):TextListControl(ui.anchor,{16,206,width-32,height-280},nil,ui.rows({"Choose up to three routes and run the comparison.","Missing prices remain unknown. Sampling intervals do not measure model uncertainty."},width-62))
	controls.run=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-48,180,28},"Compare recipes",function()
		local ok,captured=pcall(function()
			local routes={}
			for i=1,3 do
				local route=copyTable(recipes[controls["route"..i]:GetSelValueByKey("val")]);local price=controls["price"..i].buf
				if route.priceKey and price~="" then
					route.price=assert(tonumber(price),"Enter a valid action price")
					require("Modules.CraftingPrices").actionOverride(route.priceKey,route.price)
				end
				routes[#routes+1]=route
			end
			return routes
		end)
		if not ok then main:OpenMessagePopup("Compare recipes",ui.errorText(captured));return end
		local job=tasks.start(build,function(checkpoint)
			local results={}
			for i,route in ipairs(captured) do
				local prices=settings.prices and copyTable(settings.prices)
				local actionPrices=require("Modules.CraftingPrices").actionOverride(route.priceKey,route.price)
				local options={initialState=copyTable(state),trials=settings.trials,maxActions=settings.budget,seed=settings.seed,currency=settings.currency,priceBook=settings.priceBook,prices=prices,actionPrices=actionPrices,checkpoint=function(progress) checkpoint({route=i,trial=progress.trial,trials=progress.trials}) end}
				local ok,result=pcall(sim.simulate,raw,route.recipe,options);results[#results+1]={label=route.label,result=ok and result or nil,error=not ok and ui.errorText(result) or nil}
			end
			return results
		end,function(results)
			chartResults=results
			local lines={"Same starting item and encounter-independent crafting model."}
			for _,route in ipairs(results) do
				lines[#lines+1]="";lines[#lines+1]=route.label
				if route.error then lines[#lines+1]=route.error else local r=route.result
					lines[#lines+1]=string.format("%.2f%% success | 95%% interval %.2f-%.2f%% | %.2f mean actions",r.successChance,r.confidenceLow,r.confidenceHigh,r.meanActions)
					lines[#lines+1]=r.meanCost and string.format("Mean spent: %.2f %s per trial",r.meanCost,r.costCurrency) or "Cost unknown: supply every executed action's price."
					for message,count in pairs(r.transitionErrors) do lines[#lines+1]=count.." failed transitions: "..message end
				end
			end
			controls.results.list=ui.rows(lines,width-62)
		end,function(message) controls.results.list=ui.rows({ui.errorText(message)},width-62) end,function(p) controls.results.list=ui.rows({"Route "..p.route..": trial "..p.trial.." / "..p.trials},width-62) end)
		job.owner=controls
	end)
	controls.run.enabled=function() return not tasks.job end
	controls.charts=new("ButtonControl"):ButtonControl(ui.anchor,{400,height-48,180,28},"Compare charts",function() require("Classes.CraftingChartsControl").Open(chartResults) end)
	controls.charts.enabled=function() return chartResults~=nil end
	controls.cancel=new("ButtonControl"):ButtonControl(ui.anchor,{208,height-48,180,28},"Cancel comparison",function() if tasks.job and tasks.job.owner==controls then tasks.cancel() end end);controls.cancel.enabled=function() return tasks.job and tasks.job.owner==controls end
	controls.close=new("ButtonControl"):ButtonControl(ui.anchor,{width-132,height-48,116,28},"Close",function() if tasks.job and tasks.job.owner==controls then tasks.cancel() end;main:ClosePopup() end)
	ui.style(controls,{run=true});for _,control in pairs(controls) do control.layoutAudit="crafting-comparison" end;main:OpenPopup(width,height,"Compare crafting recipes",controls,nil,nil,"close")
	return controls
end
return M
