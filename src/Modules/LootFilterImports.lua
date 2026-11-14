-- Expand only explicitly supplied filter texts; never read arbitrary paths.
local parser=require("Modules.LootFilterParser")
local M={}
function M.expand(raw,files,limit)
	local sources={};for _,file in ipairs(files or {}) do sources[file.name]=file.text end
	local size=0;local stack={};local output={};limit=limit or 2*1024*1024
	local function emit(line)
		size=size+#line+1;assert(size<=limit,"Expanded filter exceeds 2 MiB");output[#output+1]=line
	end
	local function expand(text,depth)
		assert(depth<=32,"Filter imports exceed nesting limit")
		for line in (text.."\n"):gmatch("([^\n]*)\n") do
			local ok,tokens=pcall(parser.tokens,line)
			local name=ok and tokens[1]=="Import" and tokens[2]
			if name and (#tokens==2 or #tokens==3 and tokens[3]=="Optional") and sources[name] and not stack[name] then
				emit("# Included filter: "..name);stack[name]=true;expand(sources[name],depth+1);stack[name]=nil;emit("# End included filter: "..name)
			else emit(line) end
		end
	end
	expand(raw,0);return table.concat(output,"\n")
end
return M
