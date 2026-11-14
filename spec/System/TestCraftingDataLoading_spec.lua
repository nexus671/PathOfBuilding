describe("Crafting data loading",function()
	it("matches the synchronous catalogue after a staged load",function()
		local staged=dofile("Modules/CraftingAdvanced.lua");local yields=0
		local job=coroutine.create(function() staged.prepare(function() yields=yields+1;coroutine.yield() end) end)
		repeat local ok,err=coroutine.resume(job);assert.is_true(ok,err) until coroutine.status(job)=="dead"
		assert.is_true(yields>0)
		assert.same(require("Modules.CraftingAdvanced").data(),staged.data())
	end)
end)
