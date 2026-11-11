-- Empirical 3.29 model: linked research and measured Remembrance observations
-- are retained in Data/Crafting/MemoryStrands.json.
local Memory={}
local costs={transmute=8,augmentation=8,alteration=8,regal=16,alchemy=50,exalt=16,chaos=50,binding=50,influence_exalt=16,awakener=100,tainted_chaos=60,tainted_exalt=16,eldritch_chaos=60,eldritch_exalt=16,veiled_orb=80,essence=80,ducat_cyaxan=80}
local foulborn={foulborn_augmentation="augmentation",foulborn_regal="regal",foulborn_exalt="exalt"}
local function family(id) return id:gsub("_+$",""):gsub("Maven.*$",""):gsub("%d+$","") end
function Memory.extend(M,A,api)
	M.methods[#M.methods+1]="remembrance";M.labels.remembrance="Orb of Remembrance (measured distribution)"
	M.methods[#M.methods+1]="unravelling";M.labels.unravelling="Orb of Unravelling (experimental)";table.sort(M.methods)
	for method,base in pairs(foulborn) do M.methods[#M.methods+1]=method;M.labels[method]="Foulborn "..M.labels[base] end;table.sort(M.methods)
	local originalModel,originalAction,originalValidate=M.model,M.action,M.validateState
	function M.consumesStrands(action) return costs[action.method] or foulborn[action.method] and 1 end
	function M.baseCurrency(action) return foulborn[action.method] or action.method end
	function M.isFoulbornCurrency(action) return foulborn[action.method] ~= nil end
	function M.model(raw)
		assert(type(raw) == "string" and #raw <= 24000,"Invalid starting item")
		local strands=tonumber(raw:match("\nMemory Strands: (%d+)"))
		local clean=raw:gsub("\r?\nMemory Strands: %d+","")
		local model=originalModel(clean)
		model.initial.memoryStrands=strands or 0
		if strands then api.integer(strands,0,100,"memory strands");model.initial.origin=require("sha1")(raw) end
		return model
	end
	function M.validateState(model,state)
		if state.memoryStrands then api.integer(state.memoryStrands,0,100,"memory strands") end
		assert(not state.memoryActive and not state.memoryFoulborn,"A temporary memory roll context cannot be imported")
		return originalValidate(model,state)
	end
	function M.adjustPool(model,state,result,options,source,item,extraTags)
		local strands=state.memoryActive or 0
		if strands <= 0 and not state.memoryFoulborn then return result end
		local families={}
		for _,entry in ipairs(source) do
			local mod=entry.mod or model.byId[entry.id]
			local metadata=A.data().mods[entry.id]
			if not (metadata and metadata.is_essence_only) and item:GetModSpawnWeight(mod,extraTags) > 0 then
				local key=family(entry.id);families[key]=families[key] or {};families[key][#families[key]+1]=entry
			end
		end
		local allowed={}
		for _,tiers in pairs(families) do
			table.sort(tiers,function(a,b) local left,right=model.byId[a.id],model.byId[b.id];if left.level ~= right.level then return left.level > right.level end;return a.id > b.id end)
			local denominator=100+(strands > 0 and 2.5*strands+47.5 or 0)+(state.memoryFoulborn and 75 or 0)
			local count=math.floor(100/denominator*(#tiers-1))+1
			for i=1,count do allowed[tiers[i].id]=#tiers/count end
		end
		local filtered={};for _,entry in ipairs(result) do
			if allowed[entry.id] then filtered[#filtered+1]={id=entry.id,weight=entry.weight*allowed[entry.id]}
			elseif not families[family(entry.id)] then filtered[#filtered+1]=entry end
		end
		return filtered
	end
	local observations
	local function remembrance(random)
		if not observations then
			local root=GetScriptPath();local file=assert(io.open((root ~= "" and root.."/" or "").."Data/Crafting/MemoryStrands.json","rb"))
			local text=file:read("*a");file:close();observations=assert(require("dkjson").decode(text))
		end
		local pick=random()*observations.trials
		for _,entry in ipairs(observations.distribution) do pick=pick-entry.observations;if pick < 0 then return entry.strands end end
		error("Invalid measured Remembrance distribution")
	end
	function M.action(model,input,craft,random)
		local method=craft.method
		if method == "remembrance" or method == "unravelling" then
			assert(not input.corrupted and not input.mirrored and not input.destroyed and not input.veil,"Memory currency needs an uncorrupted, usable item")
			assert(model.item.type ~= "Jewel" and model.item.type ~= "Flask" and model.item.type ~= "Tincture","Memory currency requires ordinary equipment")
			local state=copyTable(input)
			if method == "remembrance" then
				assert(state.rarity == "NORMAL","Remembrance requires a normal item");state.memoryStrands=remembrance(random)
			else
				local strands=state.memoryStrands or 0;assert(strands > 0,"No memory strands to consume")
				local empty=copyTable(state);empty.rarity="RARE";empty.affixes={};empty.memoryActive=nil
				local full=M.pool(model,empty);local sides={Prefix=0,Suffix=0};local families={}
				for _,entry in ipairs(full) do
					local mod=model.byId[entry.id];sides[mod.type]=sides[mod.type]+entry.weight
					local key=family(entry.id);families[key]=families[key] or {};families[key][#families[key]+1]=entry
				end
				for _,entry in ipairs(state.affixes) do if not entry.crafted and not entry.fractured then
					local candidates={};local mod=model.byId[entry.id];local total=0
					for _,tier in ipairs(families[family(entry.id)] or {}) do if model.byId[tier.id].level > mod.level then candidates[#candidates+1]=tier;total=total+tier.weight end end
					if total > 0 and random() < math.min(1,strands*total/(2*sides[mod.type])) then
						table.sort(candidates,function(a,b) return model.byId[a.id].level > model.byId[b.id].level end)
						local cumulative,selection=0,0;for _,tier in ipairs(candidates) do cumulative=cumulative+tier.weight;selection=selection+cumulative;tier.upgradeWeight=cumulative end
						local pick=random()*selection
						for _,tier in ipairs(candidates) do pick=pick-tier.upgradeWeight;if pick < 0 then entry.id=tier.id;entry.range=M.rollRange(model.byId[tier.id],random);break end end
					end
				end end
				state.memoryStrands=0
			end
			return state
		end
		local strands=input.memoryStrands or 0;local cost=costs[method]
		if method == "exalt" then cost=({[0]=16,22,26,32,34,38})[#input.affixes] or cost end
		local underlying=foulborn[method]
		if underlying then cost=underlying == "augmentation" and 32 or underlying == "regal" and 48 or ({[0]=46,52,56,60,62,66})[#input.affixes] end
		local start=input
		if strands > 0 and cost or underlying then start=copyTable(input);start.memoryActive=strands;start.memoryFoulborn=underlying ~= nil end
		local action=craft;if underlying then action=copyTable(craft);action.method=underlying end
		local result=originalAction(model,start,action,random)
		result.memoryActive=nil;result.memoryFoulborn=nil
		if strands > 0 and cost then result.memoryStrands=math.max(0,strands-math.floor(random()*(cost+1))) end
		return result
	end
	M.limits[#M.limits+1]="Memory strands use empirical tier filtering with retained-tier weights scaled by total/retained tier count, the Unravelling model, uniform consumption and 2255 Remembrance observations. Ordinary Exalted ceilings by prior affix count use 16/22/26/32/34/38, an inferred table supported at four/five affixes. These are measured models, not server guarantees. Strand counts live in structured state because native item text lacks that field."
	M.limits[#M.limits+1]="Foulborn currencies add 75 to the tier-filter denominator. Applying that bonus without strands and the Foulborn Exalted consumption row are extrapolations, not settled measurements."
end
return Memory
