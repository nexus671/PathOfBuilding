-- Apply category styles in place; never lift matching blocks into a new priority.
-- cspell:ignore jsontype
local appearance=require("Modules.LootFilterAppearanceSettings")
local parser=require("Modules.LootFilterParser")
local M={}
function M.validate(values)
	local json=require("dkjson");assert(type(values)=="table" and values~=json.null,"Invalid category styles");local meta=getmetatable(values);assert(not meta or meta.__jsontype~="object","Category styles must be an array")
	for key in pairs(values) do assert(type(key)=="number" and key==math.floor(key) and key>=1 and key<=#values,"Category styles must be a dense array") end
	local allowed={};for _,name in ipairs(require("Modules.LootFilterLibrary").categories) do if name~="All items" then allowed[name]=true end end
	local result,seen={},{}
	for _,entry in ipairs(values) do
		assert(type(entry)=="table" and allowed[entry.category] and not seen[entry.category],"Invalid or duplicate style category");seen[entry.category]=true
		assert(entry.enabled==nil or type(entry.enabled)=="boolean","Invalid category enable setting")
		result[#result+1]={category=entry.category,enabled=entry.enabled~=false,appearance=appearance.validate(entry.appearance)}
	end;return result
end
function M.install(profile,category,settings)
	local next=copyTable(profile);next.categoryStyles=next.categoryStyles or {};local found
	for i,entry in ipairs(next.categoryStyles) do if entry.category==category then found=i;break end end
	if settings then local entry={category=category,appearance=settings};if found then next.categoryStyles[found]=entry else next.categoryStyles[#next.categoryStyles+1]=entry end
	elseif found then table.remove(next.categoryStyles,found) end
	return require("Modules.LootFilters").validate({schemaVersion=1,activeId=next.id,profiles={next}}).profiles[1]
end
function M.apply(raw,values,category)
	if not values or #values==0 then return raw end
	local settings={};for _,entry in ipairs(values) do if entry.enabled~=false then settings[entry.category]=entry.appearance end end
	if category then return require("Modules.LootFilterDecorators").apply(raw,settings[category]) end
	local parsed=parser.parse(raw);if #parsed.rules==0 then return raw end
	local lines={};for line in (raw:gsub("\r\n","\n").."\n"):gmatch("([^\n]*)\n") do lines[#lines+1]=line end
	local result={};for i=1,parsed.rules[1].line-1 do result[#result+1]=lines[i] end
	for i,block in ipairs(parsed.rules) do
		local text=table.concat(lines,"\n",block.line,parsed.rules[i+1] and parsed.rules[i+1].line-1 or #lines)
		local kind=require("Modules.LootFilterLibrary").category({text=table.concat(block.rawLines,"\n")})
		result[#result+1]=require("Modules.LootFilterDecorators").apply(text,settings[kind])
	end;return table.concat(result,"\n")
end
return M
