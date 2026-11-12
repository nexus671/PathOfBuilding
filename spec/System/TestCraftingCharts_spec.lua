describe("Crafting budget and spending charts",function()
	local charts=require("Modules.CraftingChartData")
	local result={trials=10,successChance=40,costCurrency="chaos",actionDistribution={{actions=1,trials=2,successes=1},{actions=3,trials=5,successes=3},{actions=5,trials=3,successes=0}},costDistribution={{cost=2,trials=2,successes=1},{cost=6,trials=5,successes=3},{cost=10,trials=3,successes=0}}}
	it("keeps capped failures in the denominator of success curves",function()
		local data=charts.series({{label="Route",result=result}},charts.modes[1]);local points=data.series[1].points
		assert.equal(0,charts.at(points,0).y);assert.equal(10,charts.at(points,2).y);assert.equal(40,charts.at(points,3).y);assert.equal(40,charts.at(points,100).y)
		assert.equal(10,points[3].trials);assert.same(result.actionDistribution,{{actions=1,trials=2,successes=1},{actions=3,trials=5,successes=3},{actions=5,trials=3,successes=0}})
		local usage=charts.series({{label="Route",result=result}},charts.modes[2]);assert.equal(100,usage.series[1].points[3].y)
	end)
	it("charts supplied costs without mixing units or inventing missing prices",function()
		local missing=copyTable(result);missing.costDistribution=nil;local different=copyTable(result);different.costCurrency="divine"
		local data=charts.series({{label='Route "A"',result=result},{label="Unknown",result=missing},{label="Other unit",result=different}},charts.modes[3])
		assert.equal(1,#data.series);assert.equal(2,#data.omitted);assert.equal("chaos",data.unit);assert.equal(40,charts.at(data.series[1].points,10).y)
		assert.is_truthy(charts.csv(data):find('"Route ""A""",2,10,1,10',1,true))
	end)
	it("returns complete trial distributions only when every executed currency is priced",function()
		newBuild();local sim=require("Modules.CraftingSimulator");local raw="Rarity: NORMAL\nIron Hat\nItem Level: 86"
		local recipe={steps={{method="alchemy"}},targets={},requirements={minAffixes=4}}
		local priced=sim.simulate(raw,recipe,{trials=10,maxActions=1,prices={alchemy=3},baseCost=2,currency="chaos"})
		assert.same({{cost=5,trials=10,successes=10}},priced.costDistribution)
		local missing=sim.simulate(raw,recipe,{trials=10,maxActions=1,retainSuccesses=2});assert.is_nil(missing.costDistribution);assert.is_nil(missing.retainedSuccesses[1].cost)
	end)
end)
