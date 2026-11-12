-- Real zlib support for headless imports and bundled compressed game data.
-- cspell:ignore uncompress compressBound compress2 zlib1
local ffi=require("ffi")
ffi.cdef[[
unsigned long compressBound(unsigned long sourceLen);
int compress2(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen, int level);
int uncompress(unsigned char *dest, unsigned long *destLen, const unsigned char *source, unsigned long sourceLen);
]]
local library
local function zlib()
	if not library then
		for _,name in ipairs(ffi.os=="Windows" and {"zlib1"} or {"z","libz.so.1"}) do
			local ok,result=pcall(ffi.load,name)
			if ok then library=result;break end
		end
		assert(library,"Headless compression requires zlib (bundled zlib1.dll on Windows)")
	end
	return library
end
local M={}
function M.inflate(data)
	assert(type(data)=="string","Compressed input must be a string")
	local size=math.max(1024,#data*2)
	while size<=512*1024*1024 do
		local output=ffi.new("unsigned char[?]",size)
		local length=ffi.new("unsigned long[1]",size)
		local status=zlib().uncompress(output,length,data,#data)
		if status==0 then return ffi.string(output,tonumber(length[0])) end
		assert(status==-5,"Invalid compressed data (zlib error "..status..")")
		size=size*2
	end
	error("Decompressed data exceeds the headless 512 MiB limit")
end
function M.deflate(data)
	assert(type(data)=="string","Compression input must be a string")
	local length=ffi.new("unsigned long[1]",zlib().compressBound(#data))
	local output=ffi.new("unsigned char[?]",tonumber(length[0]))
	assert(zlib().compress2(output,length,data,#data,9)==0,"Could not compress data")
	return ffi.string(output,tonumber(length[0]))
end
return M
