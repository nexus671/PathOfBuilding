-- Empirical cumulative curves; failed/capped trials remain in the denominator.
local M={modes={"Success by action count","Actions used per trial","Success by spending","Spending per trial"}}
function M.series(routes,mode)
	local spending=mode==M.modes[3] or mode==M.modes[4];local success=mode==M.modes[1] or mode==M.modes[3]
	local series={};local currency;local omitted={};local maximum=0;local warnings={}
	for _,route in ipairs(routes) do local result=route.result
		if result then
			for _,warning in ipairs(result.warnings or {}) do warnings[#warnings+1]=route.label..": "..warning.message end
			local buckets=spending and result.costDistribution or result.actionDistribution
			if spending and not result.costDistribution then omitted[#omitted+1]=route.label..": missing prices"
			elseif spending and currency and currency~=result.costCurrency then omitted[#omitted+1]=route.label..": different price unit"
			else
				if spending then currency=result.costCurrency end
				local points={};local count=0;local key=spending and "cost" or "actions"
				for _,bucket in ipairs(buckets or {}) do count=count+(success and bucket.successes or bucket.trials);points[#points+1]={x=bucket[key],y=count/result.trials*100,count=count,trials=result.trials};maximum=math.max(maximum,bucket[key]) end
				series[#series+1]={label=route.label,points=points,result=result}
			end
		end
	end
	return {series=series,maximum=maximum,unit=spending and (currency or "supplied price units") or "actions",omitted=omitted,warnings=warnings,success=success,
		note=success and "Successes within the captured trial budget / all trials. No extrapolation or guaranteed success." or "Completed trials at or below each value, including failures and capped trials. Not a cost of guaranteed success."}
end
function M.at(points,x)
	local found={x=0,y=0,count=0,trials=points[1] and points[1].trials or 0}
	for _,point in ipairs(points) do if point.x>x then break end;found=point end
	return found
end
function M.csv(data)
	local lines={"route,value,percent,count,trials"}
	for _,series in ipairs(data.series) do for _,point in ipairs(series.points) do lines[#lines+1]=string.format('"%s",%.12g,%.12g,%d,%d',series.label:gsub('"','""'),point.x,point.y,point.count,point.trials) end end
	return table.concat(lines,"\n")
end
return M
