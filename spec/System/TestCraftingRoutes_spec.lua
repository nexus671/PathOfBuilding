describe("Visual crafting routes",function()
	local routes=require("Modules.CraftingRoutes")
	it("draws default routes and recovery destinations using simulator semantics",function()
		local recipe={steps={{method="alchemy"},{method="chaos",onFailureAction="restart"},{method="divine",onFailureAction="salvage"}}}
		local edges=routes.edges(recipe);assert.equal(6,#edges);assert.equal(2,edges[1].target);assert.equal(1,edges[4].target);assert.equal(4,edges[6].target);assert.equal("Salvage",edges[6].label)
	end)
	it("stages explicit connections without changing the source or the other branch",function()
		local recipe={steps={{method="alchemy",onSuccess=2,onFailureAction="stop"},{method="chaos"}}}
		local changed=routes.set(recipe,1,"failure",1);assert.equal("route",changed.steps[1].onFailureAction);assert.equal(1,changed.steps[1].onFailure);assert.equal(2,changed.steps[1].onSuccess);assert.equal("stop",recipe.steps[1].onFailureAction)
		assert.is_false(pcall(routes.set,recipe,1,"failure",4));assert.is_false(pcall(routes.set,recipe,0,"success",1))
	end)
end)
