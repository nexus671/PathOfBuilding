-- cspell:ignore Siveran
-- Current colour model follows Siveran's CC0 calculator (3.29).
local S={}
local colours={"R","G","B"}
function S.extend(M,A,api)
	local methods={beast_max_links="Bestiary: maximum links",omen_trichromatism="Omen of Trichromatism (RGB)",omen_connections="Orb of Fusing + Omen of Connections",chromatic="Chromatic Orb",socket_colour_bench="Bench: non-white sockets",socket_white_bench="Bench: white sockets (3.30)",tainted_chromatic="Tainted Chromatic Orb",tainted_jeweller="Tainted Jeweller's Orb",tainted_fusing="Tainted Orb of Fusing"}
	for method,label in pairs(methods) do M.methods[#M.methods+1]=method;M.labels[method]=label end;table.sort(M.methods)
	local originalAction,originalOptions,originalPrice,originalComponents=M.action,M.actionOptions,M.priceKey,M.components
	M.methodChecks.omen_connections=function(model,state)
		local sockets=state.sockets or {}
		if #sockets<2 then return "Add at least two sockets before linking." end
		local linked=true
		for _,socket in ipairs(sockets) do
			if socket.color=="A" then return "Abyssal sockets need a separate socket model." end
			linked=linked and socket.group==sockets[1].group
		end
		if linked then return "The item is already fully linked." end
	end
	M.methodChecks.beast_max_links=M.methodChecks.omen_connections
	M.methodChecks.tainted_fusing=function(model,state)
		local sockets=state.sockets or {}
		if #sockets<2 then return "Link crafting needs at least two sockets." end
		local linked=true
		for _,socket in ipairs(sockets) do linked=linked and socket.group==sockets[1].group end
		if linked then return "The item is already fully linked." end
	end
	M.methodChecks.omen_trichromatism=function(model,state)
		if #(state.sockets or {})<3 then return "Add at least three sockets for the RGB guarantee." end
		for _,socket in ipairs(state.sockets) do if socket.color=="A" then return "Abyssal sockets need a separate socket model." end end
	end
	local function colourWeights(model,tainted)
		if tainted then return {1/3,1/3,1/3} end
		local values={model.item.requirements.str or 0,model.item.requirements.dex or 0,model.item.requirements.int or 0}
		local total,n=0,0;for _,value in ipairs(values) do total=total+value;if value > 0 then n=n+1 end end
		if n == 0 then return {1/3,1/3,1/3} end
		local result={}
		for i,value in ipairs(values) do
			if n == 1 then result[i]=value > 0 and 0.9*(value+10)/(total+20) or 0.05+4.5/(total+20)
			elseif n == 2 then result[i]=value > 0 and 0.9*value/total or 0.1
			else result[i]=value/total end
		end
		return result
	end
	local function colour(weights,random)
		local pick=random();for i,value in ipairs(weights) do pick=pick-value;if pick < 0 then return colours[i] end end;return "B"
	end
	function M.action(model,input,craft,random)
		local method=craft.method
		if not methods[method] then return originalAction(model,input,craft,random) end
		assert(not input.mirrored and not input.veil,"Cannot modify a mirrored item or unfinished unveil")
		local tainted=method:find("tainted_",1,true) ~= nil
		assert(method == "socket_colour_bench" or method == "socket_white_bench" or (input.corrupted or false) == tainted,tainted and "Tainted socket currency requires corruption" or "Use tainted currency or the bench on corrupted items")
		local state=copyTable(input);local sockets=state.sockets or {};state.sockets=sockets
		assert(#sockets > 0,"This item has no sockets")
		for _,socket in ipairs(sockets) do assert(socket.color ~= "A","Abyssal sockets need a separate socket model") end
		if method == "socket_white_bench" then
			for _,socket in ipairs(sockets) do socket.color="W" end
		elseif method == "omen_connections" or method == "beast_max_links" then
			for _,socket in ipairs(sockets) do socket.group=0 end
		elseif method == "tainted_jeweller" then
			local limit=math.min(model.item.base.socketLimit or 0,model.item.itemLevel >= 50 and 6 or model.item.itemLevel >= 35 and 5 or model.item.itemLevel >= 25 and 4 or model.item.itemLevel >= 2 and 3 or 2)
			if random() < 0.5 then if #sockets < limit then
				local free=0;for _,socket in ipairs(sockets) do free=math.max(free,socket.group+1) end
				sockets[#sockets+1]={color="W",group=free}
			end
			elseif #sockets > 1 then table.remove(sockets) end
		elseif method == "tainted_fusing" then
			assert(#sockets >= 2,"Link crafting needs at least two sockets")
			local groups={};local biggest={}
			for i,socket in ipairs(sockets) do groups[socket.group]=groups[socket.group] or {};local group=groups[socket.group];group[#group+1]=i;if #group > #biggest then biggest=group end end
			assert(#biggest < #sockets,"The item is already fully linked")
			if random() < 0.5 then
				local neighbour=biggest[#biggest]+1;if neighbour > #sockets then neighbour=biggest[1]-1 end
				sockets[neighbour].group=sockets[biggest[1]].group
			elseif #biggest > 1 then
				local free=0;for _,socket in ipairs(sockets) do free=math.max(free,socket.group+1) end
				sockets[biggest[#biggest]].group=free
			end
		else
			local rgb=method == "omen_trichromatism"
			local forced=rgb and 3 or method == "socket_colour_bench" and api.integer(craft.count,2,4,"minimum non-white sockets") or 1
			assert(forced <= #sockets,"Not enough sockets for this colour craft")
			local indices={};for i=1,#sockets do indices[i]=i end
			for i=#indices,2,-1 do local j=math.floor(random()*i)+1;indices[i],indices[j]=indices[j],indices[i] end
			local weights=colourWeights(model,tainted)
			local chance=math.min(1,0.00375*math.max(model.item.itemLevel-14,1)*(1+math.min(state.quality or 0,30)/100))
			for i,index in ipairs(indices) do
				if rgb and i<=3 then sockets[index].color=colours[i]
				else sockets[index].color=(i <= forced or random() < chance) and colour(weights,random) or "W" end
			end
		end
		local previous,group=nil,-1
		for _,socket in ipairs(sockets) do local old=socket.group;if old ~= previous then group=group+1;previous=old end;socket.group=group end
		return state
	end
	function M.actionOptions(model,state,method)
		if method ~= "socket_colour_bench" then return originalOptions(model,state,method) end
		local result={};for count=2,math.min(4,#(state.sockets or {})) do result[#result+1]={label="At least "..count.." non-white sockets",action={method=method,count=count}} end;return result
	end
	function M.priceKey(action) if action.method == "socket_colour_bench" then return action.method..":"..tostring(action.count) end;return originalPrice(action) end
	function M.components(action,state,model)
		if action.method == "beast_max_links" then return {beast_black_morrigan=1,beast_craicic_sand_spitter=1} end
		if action.method == "socket_white_bench" then
			local result={["Metadata/Items/Currency/CurrencyConvertToNormal"]=1};if state and state.corrupted then result["Metadata/Items/Currency/CurrencyCorrupt"]=1 end;return result
		end
		if action.method == "omen_connections" then return {["Metadata/Items/Currency/AncestralOmenOnFusingMakeFullLinks"]=1,["Metadata/Items/Currency/CurrencyRerollSocketLinks"]=1} end
		if action.method == "omen_trichromatism" then return {["Metadata/Items/Currency/AncestralOmenOnChromaticAddWhiteSockets"]=1,["Metadata/Items/Currency/CurrencyRerollSocketColours"]=1} end
		if action.method == "socket_colour_bench" then
			local amount=({[2]=5,[3]=20,[4]=75})[action.count]
			local result={chromatic=amount};if state and state.corrupted then result["Metadata/Items/Currency/CurrencyCorrupt"]=amount end;return result
		end
		return originalComponents(action,state,model)
	end
	local catalog=M.catalog
	function M.catalog(raw,query,limit,initialState)
		local result=catalog(raw,query,limit,initialState);local model=M.model(raw)
		local state=initialState and M.validateState(model,initialState) or model.initial
		model=M.context(model,state);query=(query or ""):lower();result.socketCrafts={}
		local available=require("Modules.CraftingAvailability").check
		for _,method in ipairs({"socket_bench","socket_white_bench","socket_colour_bench","chromatic","beast_max_links","omen_connections","omen_trichromatism","tainted_chromatic","tainted_jeweller","tainted_fusing"}) do
			local choices=(method=="socket_bench" or method=="socket_colour_bench") and M.actionOptions(model,state,method) or {{label=M.labels[method],action={method=method}}}
			local allowed,reason=available(method,state,model)
			for _,choice in ipairs(choices) do
				if #result.socketCrafts<(limit or 50) and (method.." "..choice.label):lower():find(query,1,true) then
					result.socketCrafts[#result.socketCrafts+1]={method=method,label=choice.label,action=copyTable(choice.action),priceKey=M.priceKey(choice.action),
						available=allowed,unavailableReason=not allowed and reason or nil,deterministic=method=="socket_bench" or method=="socket_white_bench" or method=="beast_max_links" or method=="omen_connections",guaranteedColours=method=="omen_trichromatism" and "RGB" or nil,components=M.components(choice.action,state)}
				end
			end
		end
		return result
	end
	M.limits[#M.limits+1]="Omen of Trichromatism guarantees one red, green and blue socket using one Omen and one Chromatic Orb. Forced positions are sampled uniformly; remaining sockets use the existing colour model. Placement and extra-colour probabilities are model assumptions."
	M.limits[#M.limits+1]="The white socket bench action uses the announced 3.30 rule. Other crafting data remains pinned to 3.29.3.6; this action does not update other rules or modifier pools."

	M.limits[#M.limits+1]="Socket colours use Siveran's empirical 3.29 model, with attribute bias for ordinary Chromatics and uniform RGB for tainted Chromatics. Tainted socket/link currencies assume 50/50 addition/removal; added sockets are white. Tainted Fusing selects the first largest group and extends it to the right when possible; tie and direction rules are model assumptions."
end
return S
