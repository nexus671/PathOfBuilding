-- Property currencies use the same hypothetical state as affix crafting.
local P={}
local catalysts={"Abrasive","Accelerating","Dextral","Fertile","Imbued","Intrinsic","Noxious","Prismatic","Sinistral","Tempering","Turbulent","Unstable"}
function P.extend(M,A,api)
	local actions={quality="Armour / weapon quality",catalyst="Catalyst",tainted_quality="Tainted armour / weapon quality",tainted_catalyst="Tainted Catalyst",conflict="Orb of Conflict"}
	for method,label in pairs(actions) do M.methods[#M.methods+1]=method;M.labels[method]=label end
	table.sort(M.methods)
	local originalModel,originalAction,originalDecorate,originalValidate,originalOptions=M.model,M.action,M.decorateItem,M.validateState,M.actionOptions
	local function qualityGain(model,random)
		local gain=math.max(1,math.min(20,30*math.exp(-model.item.itemLevel/30)-0.3))
		return math.floor(gain)+(random() < gain-math.floor(gain) and 1 or 0)
	end
	function M.model(raw)
		local model=originalModel(raw)
		model.initial.catalyst=model.item.catalyst;model.initial.catalystQuality=model.item.catalystQuality
		return model
	end
	function M.decorateItem(model,state,item)
		originalDecorate(model,state,item)
		if state.catalyst then item.catalyst=state.catalyst;item.catalystQuality=state.catalystQuality or 0 end
	end
	function M.validateState(model,state)
		if state.catalyst then api.integer(state.catalyst,1,#catalysts,"catalyst");assert(model.item.type == "Ring" or model.item.type == "Amulet" or model.item.type == "Belt","Catalysts require jewellery") end
		if state.catalystQuality then api.integer(state.catalystQuality,0,20,"catalyst quality");assert(state.catalyst,"Catalyst quality needs a catalyst type") end
		return originalValidate(model,state)
	end
	function M.action(model,input,action,random)
		local method=action.method
		if not actions[method] then return originalAction(model,input,action,random) end
		assert(not input.mirrored and not input.veil,"Finish the unveil before crafting; mirrored items cannot be crafted")
		local tainted=method == "tainted_quality" or method == "tainted_catalyst"
		assert((input.corrupted or false) == tainted,tainted and "Tainted currency requires a corrupted item" or "This currency cannot modify a corrupted item")
		local state=copyTable(input)
		if method == "quality" or method == "tainted_quality" then
			assert(model.item.base.armour or data.weaponTypeInfo[model.item.type] or not tainted and (model.item.type == "Flask" or model.item.type == "Tincture"),"Quality currency requires armour, a weapon, flask or tincture")
			if tainted then state.quality=math.floor(random()*30)
			else assert((state.quality or 0) < 20,"Ordinary quality currency cannot exceed 20% quality");state.quality=math.min(20,(state.quality or 0)+qualityGain(model,random)) end
		elseif method == "catalyst" or method == "tainted_catalyst" then
			assert(model.item.type == "Ring" or model.item.type == "Amulet" or model.item.type == "Belt","Catalysts require a ring, amulet or belt")
			local selected=tainted and math.floor(random()*#catalysts)+1 or api.integer(action.catalyst,1,#catalysts,"catalyst")
			local previous=state.catalyst == selected and (state.catalystQuality or 0) or 0
			assert(tainted or previous < 20,"This catalyst quality is already at 20%")
			state.catalyst=selected;state.catalystQuality=tainted and math.floor(random()*21) or math.min(20,previous+qualityGain(model,random))
		else
			assert(not model.unresolvedEldritch or state.implicits,"Imported Eldritch tiers need their structured implicit state")
			assert(state.implicits and #state.implicits == 2,"Conflict requires both Eldritch implicits")
			local exarch,eater
			for _,entry in ipairs(state.implicits) do if entry.side == "Exarch" then exarch=entry else eater=entry end end
			assert(exarch and eater,"Conflict requires Exarch and Eater implicits")
			-- Empirical tier-difference model, not a published server probability.
			local chance=math.max(0,math.min(1,0.5-0.11*(exarch.tier-eater.tier)))
			local winner,loser=exarch,eater;if random() >= chance then winner,loser=eater,exarch end
			local function change(entry,tier)
				local id=entry.id:gsub("%d+$",tostring(tier))
				local mod=assert(data.itemMods.Eldritch[id],"This implicit has no verified adjacent tier")
				assert(mod.type == entry.side,"Implicit side changed unexpectedly")
				entry.id=id;entry.tier=tier;entry.range=M.rollRange(mod,random)
			end
			-- Perfect implicits stay Perfect when selected for an upgrade.
			if winner.tier < 6 then change(winner,winner.tier+1) end
			if loser.tier == 1 then state.implicits={winner} else change(loser,loser.tier-1) end
		end
		return state
	end
	function M.actionOptions(model,state,method)
		if method ~= "catalyst" then return originalOptions(model,state,method) end
		local result={};for id,name in ipairs(catalysts) do result[#result+1]={label=name.." Catalyst",action={method=method,catalyst=id}} end;return result
	end
	local originalPrice=M.priceKey
	function M.priceKey(action) if action.method == "catalyst" then return "catalyst:"..tostring(action.catalyst) end;return originalPrice(action) end
	M.limits[#M.limits+1]="Orb of Conflict uses the empirical 50% minus 11 percentage points per tier difference model. Its estimates are not published server odds."
end
return P
