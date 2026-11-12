-- Bounded session diagnostics. Timings describe observed work, not estimated speedups.
local M={}
local builds=setmetatable({},{__mode="k"})
function M.record(build,name,seconds)
	local rows=builds[build] or {};builds[build]=rows
	local row=rows[name] or {name=name,count=0,total=0,worst=0};rows[name]=row
	row.count=row.count+1;row.last=math.max(0,seconds*1000);row.total=row.total+row.last;row.worst=math.max(row.worst,row.last)
end
function M.measure(build,name,run,...)
	local start=os.clock();local values={pcall(run,...)};M.record(build,name,os.clock()-start)
	assert(values[1],values[2]);return unpack(values,2)
end
function M.rows(build)
	local result={};for _,row in pairs(builds[build] or {}) do local copy=copyTable(row);copy.mean=copy.total/copy.count;result[#result+1]=copy end
	table.sort(result,function(a,b) if a.worst==b.worst then return a.name<b.name end;return a.worst>b.worst end);return result
end
function M.clear(build) builds[build]=nil end
return M
