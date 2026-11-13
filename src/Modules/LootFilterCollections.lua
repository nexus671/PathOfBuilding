-- Named, build-owned examples and appearance snapshots. No account or price feed.
-- cspell:ignore jsontype
local json=require("dkjson")
local appearance=require("Modules.LootFilterAppearanceSettings")
local M={}
local function array(value)
	assert(type(value)=="table" and value~=json.null,"Expected an array")
	local meta=getmetatable(value);assert(not meta or meta.__jsontype~="object","Expected an array")
	for key in pairs(value) do assert(type(key)=="number" and key==math.floor(key) and key>=1 and key<=#value,"Expected a dense array") end;return value
end
local function text(value,limit)
	assert(type(value)=="string" and #value<=limit and not value:find("%z"),"Invalid collection text");return value
end
function M.sample(value)
	assert(type(value)=="table" and value~=json.null,"Invalid example item");local result,count=setmetatable({},{__jsontype="object"}),0
	for key,v in pairs(value) do
		text(key,64);assert(not key:find("[%c]"),"Invalid example property");count=count+1;assert(count<=80,"Too many example properties")
		if type(v)=="string" then result[key]=text(v,1000)
		elseif type(v)=="number" then assert(v==v and math.abs(v)<=1e9,"Invalid example number");result[key]=v
		elseif type(v)=="boolean" then result[key]=v
		else local values={};for _,entry in ipairs(array(v)) do values[#values+1]=text(entry,240);assert(#values<=40,"Too many example values") end;result[key]=values end
	end;return result
end
local function validate(values,kind)
	local result,seen={},{}
	for _,entry in ipairs(array(values)) do
		assert(type(entry)=="table","Invalid collection entry");local id,title=text(entry.id,64),text(entry.title,120)
		assert(id:match("^[%w_-]+$") and not seen[id] and title:match("%S") and not title:find("[%c]"),"Invalid or duplicate collection ID/title");seen[id]=true
		local next={id=id,title=title}
		if kind=="samples" then
			next.samples={};for _,sample in ipairs(array(entry.samples)) do next.samples[#next.samples+1]=M.sample(sample) end;assert(#next.samples>0,"Save at least one example item")
		else
			next.appearance=appearance.validate(entry.appearance);next.theme=entry.theme or "default";assert(next.theme=="default" or next.theme=="contrast","Invalid palette theme")
			if entry.categoryStyles~=nil then next.categoryStyles=require("Modules.LootFilterCategoryStyles").validate(entry.categoryStyles) end
		end;result[#result+1]=next
	end;return result
end
function M.sampleSets(values) return validate(values,"samples") end
function M.palettes(values) return validate(values,"palettes") end
local function checked(profile)
	return require("Modules.LootFilters").validate({schemaVersion=1,activeId=profile.id,profiles={profile}}).profiles[1]
end
function M.install(profile,key,entry)
	assert(key=="sampleSets" or key=="palettes","Unknown collection");local next=copyTable(profile);next[key]=next[key] or {};local found=false
	for i,value in ipairs(next[key]) do if value.id==entry.id then next[key][i]=copyTable(entry);found=true;break end end
	if not found then next[key][#next[key]+1]=copyTable(entry) end;return checked(next)
end
function M.palette(profile,id)
	for _,entry in ipairs(profile.palettes or {}) do if entry.id==id then local next=copyTable(profile);next.appearance=copyTable(entry.appearance);next.theme=entry.theme;if entry.categoryStyles~=nil then next.categoryStyles=copyTable(entry.categoryStyles) end;return checked(next) end end
	error("Choose a saved palette")
end
return M
