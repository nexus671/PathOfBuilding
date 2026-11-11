local C={}
function C.extend(M,A,api)
	local labels={vaal="Vaal Orb",tainted_exalt="Tainted Exalted Orb",tainted_chaos="Tainted Chaos Orb"}
	for method,label in pairs(labels) do M.methods[#M.methods+1]=method;M.labels[method]=label end;table.sort(M.methods)
	local originalModel,originalAction,originalDecorate,originalValidate=M.model,M.action,M.decorateItem,M.validateState
	local function weight(model,id)
		local metadata=A.data().mods[id]
		if not metadata then return 0 end
		for _,entry in ipairs(metadata.spawn_weights) do if entry.tag == "default" or model.item.base.tags[entry.tag] then return entry.weight end end
		return 0
	end
	function M.model(raw)
		local model=originalModel(raw)
		model.corruptions={}
		for id,mod in pairs(data.itemMods.Corrupted) do if mod.level <= model.item.itemLevel and weight(model,id) > 0 then
			model.corruptions[#model.corruptions+1]={id=id,weight=weight(model,id)};model.special[id]=true
		end end
		table.sort(model.corruptions,function(a,b) return a.id < b.id end)
		return model
	end
	function M.rollCorrupted(model,state,random)
		local total=0;for _,entry in ipairs(model.corruptions) do total=total+entry.weight end
		assert(total > 0,"No current corruption implicit is available for this base")
		local pick=random()*total;local id
		for _,entry in ipairs(model.corruptions) do pick=pick-entry.weight;if pick < 0 then id=entry.id;break end end
		state.corruptedImplicits={{id=assert(id),range=M.rollRange(model.byId[id],random)}}
		state.implicits=nil;state.baseImplicitRanges=nil;state.vendorImplicit=nil;state.corrupted=true
	end
	function M.decorateItem(model,state,item)
		originalDecorate(model,state,item)
		if state.corruptedImplicits then
			item.implicitModLines={}
			for _,entry in ipairs(state.corruptedImplicits) do for _,line in ipairs(model.byId[entry.id]) do item.implicitModLines[#item.implicitModLines+1]={line=line,range=entry.range} end end
		end
	end
	function M.validateState(model,state)
		if state.corruptedImplicits then
			assert(state.corrupted and #state.corruptedImplicits == 1 and not state.implicits,"Invalid corruption implicit state")
			for _,entry in ipairs(state.corruptedImplicits) do
				assert(data.itemMods.Corrupted[entry.id] and weight(model,entry.id) > 0,"Invalid corruption implicit for this base")
				local ranges=type(entry.range) == "table" and entry.range or {entry.range};assert(#ranges >= 1 and #ranges <= 20,"Invalid corruption range count")
				for _,range in ipairs(ranges) do assert(type(range) == "number" and range >= 0 and range <= 1,"Invalid corruption roll") end
			end
		end
		return originalValidate(model,state)
	end
	function M.action(model,input,craft,random)
		local method=craft.method
		if not labels[method] then return originalAction(model,input,craft,random) end
		assert(not input.mirrored and not input.veil,"Cannot craft a mirrored item or an unfinished unveil")
		local state=copyTable(input)
		if method == "vaal" then
			assert(not input.corrupted,"The item is already corrupted")
			assert(model.item.type ~= "Jewel" and model.item.type ~= "Flask" and model.item.type ~= "Tincture","This Vaal model currently supports ordinary equipment")
			local outcome=math.floor(random()*4)
			if outcome == 0 then M.rollCorrupted(model,state,random)
			elseif outcome == 1 then
				local white={};for i,socket in ipairs(state.sockets or {}) do if socket.color == "W" then white[#white+1]=i end end
				if #white > 0 then
					local forced=white[math.floor(random()*#white)+1]
					for _,i in ipairs(white) do if i == forced or random() < 0.1 then state.sockets[i].color=({"R","G","B"})[math.floor(random()*3)+1] end end
				end
			elseif outcome == 2 then
				-- Keep fractures and metamod-protected affixes on the rare reroll.
				state.corrupted=false;local flags=api.flags(model,state);api.clear(model,state);state.rollBlock={attack=flags.attack,caster=flags.caster}
				state.rarity="RARE"
				while #state.affixes < M.capacities(model,state).total do
					local ok,nextState=pcall(originalAction,model,state,{method="exalt"},random);if not ok then break end;state=nextState
				end
				state.rollBlock=nil
			end
			state.corrupted=true;state.imprint=nil
		else
			assert(input.corrupted and state.rarity == "RARE","Tainted affix currency requires a corrupted rare item")
			state.corrupted=false
			if method == "tainted_exalt" then state=originalAction(model,state,{method=random() < 0.5 and "exalt" or "annul"},random)
			elseif random() < 0.5 then state=originalAction(model,state,{method="chaos"},random)
			else state=originalAction(model,state,{method="scour"},random) end
			state.corrupted=true
		end
		return state
	end
	M.limits[#M.limits+1]="The equipment Vaal model includes the four outcome branches and current non-white socket conversion. Rare-brick socket/link rerolls are not modeled; tainted affix outcomes use a 50/50 assumption."
end
return C
