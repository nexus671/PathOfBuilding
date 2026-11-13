describe("Filter source review",function()
	local diff=require("Modules.LootFilterDiff")
	local function reconstructed(value,side)
		local rows={};local index=0
		for _,row in ipairs(value.rows) do if row.kind==" " or row.kind==(side=="before" and "-" or "+") then
			index=index+1;assert.equal(index,side=="before" and row.oldLine or row.newLine);rows[#rows+1]=row.text
		end end
		return table.concat(rows,"\n")..(value[side.."FinalNewline"] and "\n" or "")
	end
	it("keeps both sources exactly reconstructable for additions, removals and replacements",function()
		for _,pair in ipairs({{"","Show\n"},{"Hide\n",""},{"Show\n BaseType Iron\nHide\n","Show\n BaseType Gold\n SetFontSize 40\nHide\n"},{"a\na\nb\nb\n","a\nb\na\nb\n"}}) do
			local value=diff.compare(pair[1],pair[2]);assert.equal(pair[1],reconstructed(value,"before"));assert.equal(pair[2],reconstructed(value,"after"))
		end
	end)
	it("distinguishes content, final newline and normalized line endings",function()
		local same=diff.compare("Show\n","Show\n");assert.is_true(same.equal);assert.equal(0,#diff.visible(same))
		local newline=diff.compare("Show","Show\n");assert.equal(0,newline.added+newline.removed);assert.is_false(newline.equal);assert.is_false(newline.beforeFinalNewline);assert.is_true(newline.afterFinalNewline)
		assert.is_truthy(diff.report(diff.compare("Show\r\n","Show\n")):find("Only line-ending",1,true))
	end)
	it("reconstructs deterministic repeated and moved line sequences",function()
		local seed=104729;local function random(n) seed=seed*16807%2147483647;return seed%n+1 end
		for _=1,300 do
			local a,b={},{};for i=1,random(40)-1 do a[i]=string.char(64+random(8)) end;for i=1,random(40)-1 do b[i]=string.char(64+random(8)) end
			local before,after=table.concat(a,"\n"),table.concat(b,"\n");local value=diff.compare(before,after)
			assert.equal(before,reconstructed(value,"before"));assert.equal(after,reconstructed(value,"after"))
		end
	end)
	it("keeps full lines in copied reviews and searches literal text",function()
		local before="same\nold [tag]\nsame\n";local after="same\nnew [tag]\nsame\n";local value=diff.compare(before,after)
		local visible=diff.visible(value,0,"[tag]");assert.equal(3,#visible);assert.equal("-",visible[2].kind);assert.equal("+",visible[3].kind)
		assert.is_truthy(diff.report(value):find("-old [tag]",1,true));assert.is_truthy(diff.report(value):find("+new [tag]",1,true))
	end)
	it("bounds oversized detailed reviews without accepting partial source text",function()
		assert.has_error(function() diff.compare(string.rep("x",2*1024*1024+1),"") end)
		assert.has_error(function() diff.compare(string.rep("\n",diff.maxLines+1),"") end)
	end)
end)
