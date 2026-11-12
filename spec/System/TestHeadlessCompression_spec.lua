describe("Headless compressed game data",function()
	it("round trips binary data and highly compressible large imports",function()
		for _,value in ipairs({"",string.char(0,1,127,255).."build XML",string.rep("Atlas and item modifiers\n",10000)}) do
			assert.are.equal(value,Inflate(Deflate(value)))
		end
	end)
	it("rejects broken compressed data instead of silently dropping it",function()
		assert.has_error(function() Inflate("broken archive") end)
	end)
	it("loads the real Legion archive without creating a binary cache",function()
		local load=LoadModule("Modules/DataJewelFileLoader")
		local original=io.open
		local wrote=false
		io.open=function(path,mode)
			if path:match("LethalPride%.bin$") and mode:match("w") then wrote=true;error("Unexpected headless cache write") end
			return original(path,mode)
		end
		local ok,result=pcall(load,"LethalPride")
		io.open=original
		assert.is_true(ok)
		assert.are.equal(3632454,#result)
		assert.is_false(wrote)
	end)
end)
