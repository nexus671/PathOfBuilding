local F={}
function F.sort(entries,metric)
	metric=metric or "costPerSuccess"
	assert(metric=="costPerSuccess" or metric=="meanCost" or metric=="successChance","Unknown fossil comparison order")
	local result=copyTable(entries,true)
	table.sort(result,function(a,b)
		if (a.error~=nil)~=(b.error~=nil) then return a.error==nil end
		if not a.error then
			if metric~="successChance" then
				local knownA,knownB=a[metric]~=nil,b[metric]~=nil
				if knownA~=knownB then return knownA end
				if knownA and a[metric]~=b[metric] then return a[metric]<b[metric] end
			end
			if a.successChance~=b.successChance then return a.successChance>b.successChance end
		end
		return table.concat(a.fossils,"+")<table.concat(b.fossils,"+")
	end)
	return result
end
function F.names(entry)
	local data=require("Modules.CraftingAdvanced").data();local result={}
	for _,id in ipairs(entry.fossils) do result[#result+1]=data.fossils[id] and data.fossils[id].name or id end
	return result
end
function F.csv(result)
	local function row(values)
		for i,value in ipairs(values) do values[i]='"'..tostring(value):gsub('"','""')..'"' end
		return table.concat(values,",")
	end
	local lines={row({"Fossils","Success chance (%)","95% low (%)","95% high (%)","Mean cost per trial","Cost per observed success","Unit","Status","Quote source","Quote time (UTC)","Resource overrides supplied","Action override uses"})}
	for _,entry in ipairs(result.combinations) do
		local status=entry.error and "Unavailable" or entry.meanCost==nil and "Cost unknown" or entry.successes==0 and "No observed successes" or "Modeled"
		lines[#lines+1]=row({table.concat(F.names(entry)," + "),entry.successChance or "",entry.confidenceLow or "",entry.confidenceHigh or "",entry.meanCost or "",entry.costPerSuccess or "",entry.costCurrency or result.costCurrency or "",status,result.priceSource or "",result.priceQuotedAt and os.date("!%Y-%m-%dT%H:%M:%SZ",result.priceQuotedAt) or "",result.resourcePriceOverridesSupplied==nil and "" or result.resourcePriceOverridesSupplied and "yes" or "no",entry.actionPriceOverridesApplied or ""})
	end
	return table.concat(lines,"\r\n")
end
return F
