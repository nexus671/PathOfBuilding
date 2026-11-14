-- Stable JSON identities for local history, recovery and dependency comparisons.
-- cspell:ignore jsontype
local json=require("dkjson")
local M={}
function M.encode(value,seen,exactNumbers)
	if exactNumbers and type(value)=="number" and value==value and value~=math.huge and value~=-math.huge then
		-- Seventeen significant digits round-trip an IEEE double. Keep the
		-- decimal separator JSON-compatible under a non-English locale.
		return (string.format("%.17g",value):gsub(",","."))
	end
	if type(value)~="table" or value==json.null then return assert(json.encode(value)) end
	seen=seen or {};assert(not seen[value],"Cyclic planning data");seen[value]=true
	local array=true;local keys={};for key in pairs(value) do keys[#keys+1]=key;if type(key)~="number" or key<1 or key>#value or key~=math.floor(key) then array=false end end
	local meta=getmetatable(value);if meta and meta.__jsontype=="object" then array=false end
	local parts={}
	if array then for i=1,#value do parts[#parts+1]=M.encode(value[i],seen,exactNumbers) end
	else table.sort(keys,function(a,b) return tostring(a)<tostring(b) end);for _,key in ipairs(keys) do assert(type(key)=="string","Planning object keys must be strings");parts[#parts+1]=json.encode(key)..":"..M.encode(value[key],seen,exactNumbers) end end
	seen[value]=nil;return (array and "[" or "{")..table.concat(parts,",")..(array and "]" or "}")
end
function M.encodeExact(value) return M.encode(value,nil,true) end
function M.hash(value) return require("sha1")(M.encode(value)) end
return M
