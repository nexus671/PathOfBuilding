-- Independent implementation of the community's measured unpredictable model.
-- Conditional counts: https://github.com/Maliffic/Resimbulator/blob/master/docs/guide.txt
local R={}
local countWeights={{100},{41,59},{0,67,33},{0,39,52,10},{0,11,59,31},{0,0,43,57},{0,0,28,72}}
function R.extend(M,A,api)
	M.methods[#M.methods+1]="recombine";M.labels.recombine="Unpredictable recombination (experimental)";table.sort(M.methods)
	local action,toItem,validate,pool,capacities,matches,options=M.action,M.toItem,M.validateState,M.pool,M.capacities,M.matches,M.actionOptions
	function M.sameRecombinationClass(left,right)
		local class=require("Modules.CraftingBenchCosts").class
		local function recombinationClass(item)
			if item.type=="One Handed Sword" and item.base.subType=="Thrusting" then return "Thrusting Sword" end
			return class(item)
		end
		return recombinationClass(left)==recombinationClass(right)
	end
	local function context(model,state)
		if not state.baseItem or state.baseItem == model.baseIdentity then return model end
		assert(type(state.baseItem) == "string" and #state.baseItem <= 24000,"Invalid recombined base")
		model.recombinedModels=model.recombinedModels or {}
		local derived=model.recombinedModels[state.baseItem]
		if not derived then
			derived=M.model(state.baseItem)
			assert(M.sameRecombinationClass(derived.item,model.item),"Recombined base must have the same item class")
			derived.initial.origin=model.initial.origin
			derived.baseIdentity=state.baseItem
			-- A request can introduce at most twenty recipe donors; bound the cache too.
			local size=0;for _ in pairs(model.recombinedModels) do size=size+1 end
			if size >= 40 then model.recombinedModels={} end
			model.recombinedModels[state.baseItem]=derived
		end
		return derived
	end
	M.context=context
	function M.toItem(model,state) return toItem(context(model,state),state) end
	function M.capacities(model,state) return capacities(context(model,state),state) end
	function M.pool(model,state) return pool(context(model,state),state) end
	function M.actionOptions(model,state,method) return options(context(model,state),state,method) end
	function M.matches(state,targets,rarity,model,requirements,requiredGroups) return matches(state,targets,rarity,model and context(model,state),requirements,requiredGroups) end
	function M.validateState(model,state) return validate(context(model,state),state) end
	local function groups(model,id)
		local metadata=A.data().mods[id];local result=metadata and metadata.groups or {model.byId[id].group}
		if model.item.clusterJewel and M.isClusterSpeedMod(model,id) then result=copyTable(result);result[#result+1]=M.clusterSpeedGroup end
		return result
	end
	local function signature(mod) return table.concat(mod," / "):gsub("%b()","#"):gsub("%d+%.?%d*","#"):lower() end
	local function naturalCraft(model,entry)
		if not entry.crafted then return nil end
		if not model.naturalCraftMatches then
			model.naturalCraftMatches={};for _,candidate in ipairs(model.mods) do model.naturalCraftMatches[candidate.mod.type..signature(candidate.mod)]=candidate.id end
		end
		return model.naturalCraftMatches[model.byId[entry.id].type..signature(model.byId[entry.id])]
	end
	local function exclusive(model,entry)
		local mod=model.byId[entry.id];local meta=A.data().mods[entry.id]
		if entry.fractured then return false end
		return entry.crafted and not naturalCraft(model,entry) or meta and meta.is_essence_only or data.veiledMods[entry.id] or data.beastCraft[entry.id] or data.itemMods.Delve[entry.id] or mod.affix:find("Elevated",1,true) or mod.affix:find("Incursion",1,true) or mod.affix:find("Chosen",1,true)
	end
	local function drawCount(count,random)
		local row=assert(countWeights[count+1],"Recombination pool exceeds six affixes per side")
		local total=0;for _,weight in ipairs(row) do total=total+weight end
		local pick=random()*total;for i,weight in ipairs(row) do pick=pick-weight;if pick < 0 then return i-1 end end
		return #row-1
	end
	function M.action(model,input,craft,random)
		assert(not input.destroyed,"The hypothetical item was destroyed")
		local current=context(model,input)
		if craft.method ~= "recombine" then return action(current,input,craft,random) end
		assert(not input.corrupted and not input.mirrored and not input.veil,"Recombination requires an uncorrupted, non-mirrored item with no pending unveil")
		assert(not current.item.synthesised and current.item.type ~= "Jewel" and current.item.type ~= "Flask" and current.item.type ~= "Tincture","This recombination model supports non-synthesised equipment")
		local donor=M.model(assert(craft.donorItem,"Paste a donor item"));local other=donor.initial
		assert(not other.corrupted and not other.mirrored and not donor.item.synthesised,"Donor must be uncorrupted, non-mirrored and non-synthesised")
		assert(M.sameRecombinationClass(current.item,donor.item),"Recombination requires the same item class")
		local host=random() < 0.5 and 1 or 2
		local chosen=host == 1 and current or donor
		local state=copyTable(host == 1 and input or other)
		state.imprint=nil;state.origin=model.initial.origin;state.affixes={};state.rarity="RARE"
		state.baseItem=toItem(chosen,host == 1 and input or other).raw
		local base=context(model,state)
		local pools={Prefix={},Suffix={}}
		for source,from in ipairs({{model=current,state=input},{model=donor,state=other}}) do
			for _,entry in ipairs(from.state.affixes) do
				if not entry.fractured or source == host then
					local mod=from.model.byId[entry.id];local natural=naturalCraft(from.model,entry)
					local sourceMod=natural and from.model.byId[natural] or mod
					local special=exclusive(from.model,entry)
					-- Non-rollable modifiers remain transferable and share the exclusive limit.
					if not special and not entry.fractured and (not sourceMod.weightKey or from.model.item:GetModSpawnWeight(sourceMod,from.model.extraTags)<=0) then special=true end
					local target=base.byId[entry.id];local targetNatural=natural and base.byId[natural] or not natural and target
					local eligible=special or entry.fractured or target and targetNatural and targetNatural.weightKey and base.item:GetModSpawnWeight(targetNatural,base.extraTags)>0
					if eligible then pools[mod.type][#pools[mod.type]+1]={entry=entry,source=source,exclusive=special,natural=natural} end
				end
			end
		end
		local sizes,regular,exclusives={},{},{}
		for _,kind in ipairs({"Prefix","Suffix"}) do
			regular[kind],exclusives[kind]=0,0
			for _,candidate in ipairs(pools[kind]) do local counts=candidate.exclusive and exclusives or regular;counts[kind]=counts[kind]+1 end
			sizes[kind]=regular[kind]+math.min(1,exclusives[kind])
		end
		assert(not (regular.Prefix == 0 and exclusives.Prefix > 0 and regular.Suffix > 0 or regular.Suffix == 0 and exclusives.Suffix > 0 and regular.Prefix > 0),"Exclusive-only side ordering changed in 3.26; this combination needs a verified probability model")
		local counts={Prefix=drawCount(sizes.Prefix,random),Suffix=drawCount(sizes.Suffix,random)}
		if #pools.Prefix == 1 and #pools.Suffix == 1 then
			local outcome=math.floor(random()*3);counts.Prefix=outcome == 1 and 0 or 1;counts.Suffix=outcome == 0 and 0 or 1
		end
		local used,hasExclusive={},false
		local order=random() < 0.5 and {"Prefix","Suffix"} or {"Suffix","Prefix"}
		for _,kind in ipairs(order) do
			for _=1,math.min(counts[kind],capacities(base,state)[kind]) do
				local eligible={}
				for _,candidate in ipairs(pools[kind]) do
					local entry=candidate.entry;local mod=base.byId[entry.id]
					local legal=mod and (not candidate.exclusive or not hasExclusive)
					if legal then for _,group in ipairs(groups(base,entry.id)) do if used[group] then legal=false end end end
					-- Native spawn tags enforce defence, attribute-base and influence restrictions.
					local natural=candidate.natural and base.byId[candidate.natural] or not candidate.natural and mod
					if legal and not candidate.exclusive and not entry.fractured and (not natural or not natural.weightKey or base.item:GetModSpawnWeight(natural,base.extraTags) <= 0) then legal=false end
					if legal then eligible[#eligible+1]=candidate end
				end
				if #eligible == 0 then break end
				local selected=eligible[math.floor(random()*#eligible)+1]
				local entry=copyTable(selected.entry);state.affixes[#state.affixes+1]=entry
				for _,group in ipairs(groups(base,entry.id)) do used[group]=true end
				hasExclusive=hasExclusive or selected.exclusive
			end
		end
		local c=api.counts(base,state)
		state.rarity=c.total == 0 and "NORMAL" or c.Prefix <= 1 and c.Suffix <= 1 and "MAGIC" or "RARE"
		state.percentiles={}
		for _,kind in ipairs({"Armour","Evasion","EnergyShield","Ward"}) do if base.item.base.armour and base.item.base.armour[kind.."BaseMin"] then state.percentiles[kind]=random() end end
		return state
	end
	M.limits[#M.limits+1]="Unpredictable recombination uses the 3.30 chosen-base item level and excludes incompatible rollable modifiers before counts. Its older empirical count table is not updated for the 3.30 changes to one-to-three modifier pools; estimates for those pools are not current odds. Exclusive-only side ordering and hidden weights remain uncertain."
end
return R
