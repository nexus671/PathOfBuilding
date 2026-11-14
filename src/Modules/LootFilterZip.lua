-- Create a portable, uncompressed ZIP without depending on a system archiver.
local bit=require("bit")
local band,bxor,rshift=bit.band,bit.bxor,bit.rshift
local crcTable={}
for n=0,255 do
	local crc=n
	for _=1,8 do crc=band(crc,1)==1 and bxor(rshift(crc,1),0xEDB88320) or rshift(crc,1) end
	crcTable[n]=crc
end
local function crc32(data)
	local crc=0xFFFFFFFF
	for i=1,#data do crc=bxor(rshift(crc,8),crcTable[band(bxor(crc,data:byte(i)),255)]) end
	return bxor(crc,0xFFFFFFFF)
end
local function u16(n) return string.char(band(n,255),band(rshift(n,8),255)) end
local function u32(n) return u16(n)..u16(rshift(n,16)) end
local M={}
function M.variants(profile,filename)
	assert(filename:match("^[%w_-]+%.filter$"),"Use a filename with letters, numbers, hyphens or underscores")
	local files=require("Modules.LootFilters").variants(profile);local output,central={},{};local offset=0
	for _,file in ipairs(files) do
		local name=filename:gsub("%.filter$","-"..file.strictness..".filter");local body=file.text
		local size=#body;local crc=crc32(body)
		local metadata=u16(20)..u16(0)..u16(0)..u16(0)..u16(0)..u32(crc)..u32(size)..u32(size)..u16(#name)..u16(0)
		local localHeader="PK\003\004"..metadata..name
		output[#output+1]=localHeader;output[#output+1]=body
		central[#central+1]="PK\001\002"..u16(20)..metadata..u16(0)..u16(0)..u16(0)..u32(0)..u32(offset)..name
		offset=offset+#localHeader+size
	end
	local directory=table.concat(central)
	output[#output+1]=directory
	output[#output+1]="PK\005\006"..u16(0)..u16(0)..u16(#files)..u16(#files)..u32(#directory)..u32(offset)..u16(0)
	return table.concat(output)
end
return M
