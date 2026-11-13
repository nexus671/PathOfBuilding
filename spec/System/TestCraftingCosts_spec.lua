describe("Native crafting ingredient costs",function()
	local sim=require("Modules.CraftingSimulator")
	local bench=require("Modules.CraftingBenchCosts")
	local fossil=require("Modules.CraftingFossilResults")
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local alteration="Metadata/Items/Currency/CurrencyRerollMagic"
	local life="Metadata/Items/Currency/CurrencyDelveCraftingLife"
	local cold="Metadata/Items/Currency/CurrencyDelveCraftingCold"
	local function book(values) return {currency="chaos",source="Saved quotes",quotedAt=1700000000,values=values} end
	local function project(values) return {id="ingredient-costs",title="Ingredient costs",slot="Body Armour",startingItem=raw,goals={},steps={},priceBook=book(values)} end
	before_each(function() newBuild() end)
	after_each(function() require("Modules.CraftingTasks").cancel();main.popups={} end)
	it("charges verified bench ingredients through every extension and preserves action overrides",function()
		local model=sim.model(raw);local action={method="bench",modId="bench:1"}
		local cost,sources=bench.cost(model,action.modId)
		assert.are.same({[alteration]=1},cost);assert.are.same({"HelenaMasterIncreasedLife1"},sources)
		assert.are.same(cost,sim.components(action,model.initial,model))
		local result=sim.simulate(raw,{steps={action},targets={},requirements={minAffixes=1}},{trials=3,maxActions=1,priceBook=book({[alteration]=0.5})})
		assert.are.equal(3,result.successes);assert.are.equal(0.5,result.meanCost);assert.are.equal(3,result.currencySpent[alteration])
		result=sim.simulate(raw,{steps={action},targets={},requirements={minAffixes=1}},{trials=1,maxActions=1,priceBook=book({[alteration]=0.5}),prices={[action.modId]=7}})
		assert.are.equal(7,result.meanCost);assert.are.equal(1,result.currencySpent[action.modId])
		local catalog=sim.catalog(raw,"maximum Life",100);local found
		for _,entry in ipairs(catalog.bench) do if entry.id==action.modId then found=entry end end
		assert.is_true(found.ingredientCostsKnown);assert.are.same(cost,found.components);assert.are.same(sources,found.costSources)
		assert.are.equal("ae6d85a5c36857e08819852ab8732239294aba59",catalog.benchCostSource.commit)
		local entries=require("Modules.CraftingPrices").entries(model,model.initial,{action})
		local required={};for _,entry in ipairs(entries) do if entry.required then required[entry.key]=true end end
		assert.is_true(required[alteration]);assert.is_nil(required[action.modId])
	end)
	it("requires exact effect, tier and class and refuses conflicting source costs",function()
		local data={benchMods={a={text="(50-41)% reduced Effect of Chill on you",required_level=30,generation_type="suffix"}},bench={}}
		local function service(id,amount) return {actions={add_explicit_mod=id},item_classes={"Ring"},cost={[alteration]=amount}} end
		data.bench={service("a",4)}
		local mod={"(41-50)% reduced Effect of Chill on you",level=30,type="Suffix"}
		local model={item={type="Ring",base={}},byId={["bench:999"]=mod}}
		assert.are.same({[alteration]=4},bench.cost(model,"bench:999",bench.index(data)))
		mod.level=31;assert.is_nil(bench.cost(model,"bench:999",bench.index(data)));mod.level=30
		model.item.type="Amulet";assert.is_nil(bench.cost(model,"bench:999",bench.index(data)));model.item.type="Ring"
		data.benchMods.b=copyTable(data.benchMods.a);data.bench[2]=service("b",5)
		assert.is_nil(bench.cost(model,"bench:999",bench.index(data)))
		data.bench[2]=service("b",4);local _,sources=bench.cost(model,"bench:999",bench.index(data));assert.are.same({"a","b"},sources)
		assert.are.equal("Warstaff",bench.class({type="Staff",base={subType="Warstaff"}}))
		assert.are.equal("Rune Dagger",bench.class({type="Dagger",base={subType="Rune Dagger"}}))
		assert.are.equal("One Hand Sword",bench.class({type="One Handed Sword",base={}}))
	end)
	it("uses the 3.30 Alteration replacement for Chance Orb bench costs",function()
		local chance="Metadata/Items/Currency/CurrencyUpgradeRandomly"
		local model=sim.model(raw);local action,cost,sources
		for id in pairs(model.byId) do
			local candidate,origins=bench.cost(model,id)
			if origins and isValueInTable(origins,"EinharMasterAllAttributes1") then action={method="bench",modId=id};cost=candidate;sources=origins;break end
		end
		assert.is_not_nil(action);assert.are.same({[alteration]=3},cost)
		assert.is_truthy(isValueInTable(sources,"GGG 3.30 patch notes"))
		assert.are.same(cost,sim.components(action,model.initial,model))
		local result=sim.simulate(raw,{steps={action},targets={},requirements={minAffixes=1}},{trials=2,maxActions=1,priceBook=book({[alteration]=0.5,[chance]=10})})
		assert.are.equal(1.5,result.meanCost);assert.are.equal(6,result.currencySpent[alteration]);assert.is_nil(result.currencySpent[chance])
		local catalog=sim.catalog(raw,"Attributes",100);local found
		for _,entry in ipairs(catalog.bench) do if entry.id==action.modId then found=entry end end
		assert.is_not_nil(found);assert.are.same(cost,found.components);assert.is_truthy(isValueInTable(found.costSources,"GGG 3.30 patch notes"))
	end)
	it("rejects conflicting quote aliases before admitting a project",function()
		local id=require("Modules.CraftingPrices").aliases(sim.model(raw)).exalt
		local p=project({exalt=2,[id]=3});local before=copyTable(p)
		assert.is_false(pcall(function() build.savers.CraftingProjects:Upsert(p) end))
		assert.are.equal(0,#build.savers.CraftingProjects.projects);assert.are.same(before,p)
		p.priceBook.values[id]=2;build.savers.CraftingProjects:Upsert(p)
		assert.are.same(p.priceBook,build.savers.CraftingProjects.projects[1].priceBook)
	end)
	it("keeps the empty quote-book unit consistent with working-craft edits",function()
		local p=project({});build.savers.CraftingProjects:Upsert(p)
		local c=require("Classes.CraftingSimulatorControl").Open(build,p);c.page:SelByValue("Simulate recipe");c.page.selFunc()
		c.currency:SetText("divine",true);c.resourcePrices:Click();local editor=main.popups[1].controls
		assert.are.equal("divine",editor.currency.buf);editor.close:Click()
		assert.are.equal("chaos",build.savers.CraftingProjects.projects[1].priceBook.currency)
		c.keepWorking:Click();assert.are.equal("divine",build.savers.CraftingProjects.projects[1].priceBook.currency)
		assert.are.equal("divine",build.savers.CraftingProjects.projects[1].run.settings.currency)
	end)
	it("lets an incomplete saved fossil configuration be repaired without an assumed outcome",function()
		local p=project({});local state=sim.model(raw).initial
		p.run={schemaVersion=1,state=state,initial=state,history={},actions={},sequence=0,configured={fossil={method="fossil"}},targets={},requirements={minAffixes=1},settings={},method="fossil",page="Craft settings"}
		local c=require("Classes.CraftingSimulatorControl").Open(build,p);c.configure:Click();local edit=main.popups[1].controls
		assert.are.equal("Fossil combination",main.popups[1].title);assert.is_nil(edit.fossil1:GetSelValueByKey("id"));assert.is_nil(edit.tangled:GetSelValueByKey("id"))
		edit.fossil1:SelByValue(life,"id");edit.use:Click();c.configure:Click()
		assert.are.equal(life,main.popups[1].controls.fossil1:GetSelValueByKey("id"))
	end)
	it("orders mixed priced, unknown and zero-cost subsets consistently without mutating results",function()
		local entries={{fossils={"a"},successChance=10,costPerSuccess=5,meanCost=0.5},{fossils={"b"},successChance=90,costPerSuccess=10,meanCost=9},{fossils={"c"},successChance=50},{fossils={"d"},successChance=100,costPerSuccess=0,meanCost=0},{fossils={"e"},error="Unavailable"}}
		local before=copyTable(entries);local sorted=fossil.sort(entries)
		assert.are.same({"d","a","b","c","e"},{sorted[1].fossils[1],sorted[2].fossils[1],sorted[3].fossils[1],sorted[4].fossils[1],sorted[5].fossils[1]})
		assert.are.equal("b",fossil.sort(entries,"successChance")[2].fossils[1]);assert.are.same(before,entries)
	end)
	it("shows fossil quote provenance, unknown costs and native currency artwork in comparison",function()
		local resonator=require("Modules.CraftingPrices").aliases(sim.model(raw))["resonator:1"]
		local result=sim.optimizeFossils(raw,{}, {fossils={life,cold},maxSockets=1,trials=4,requirements={minAffixes=1},priceBook=book({[life]=1,[resonator]=2})})
		assert.are.equal("chaos",result.costCurrency);assert.are.equal("Saved quotes",result.priceSource)
		assert.are.equal(3,result.combinations[1].meanCost);assert.is_nil(result.combinations[2].meanCost)
		local chosen;local c=require("Classes.CraftingFossilCompareControl").Open(result,function(ids) chosen=ids end)
		local lines={};for _,row in ipairs(c.stats.list) do lines[#lines+1]=row[1] end
		assert.is_truthy(table.concat(lines," "):find("Per observed success: 3 chaos",1,true))
		assert.are.same({life},c.results.list[1].fossils)
		c.results.planningMove(1);lines={};for _,row in ipairs(c.stats.list) do lines[#lines+1]=row[1] end
		assert.is_truthy(table.concat(lines," "):find("Cost unknown",1,true));c.choose:Click();assert.are.same({cold},chosen)
		local csv=fossil.csv(result);assert.is_truthy(csv:find('"Cost unknown"',1,true));assert.is_truthy(csv:find('"Saved quotes"',1,true));assert.is_truthy(csv:find('"chaos"',1,true))
	end)
end)
