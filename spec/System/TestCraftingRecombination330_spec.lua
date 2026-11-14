describe("3.30 recombination base rules",function()
	local sim=require("Modules.CraftingSimulator")
	local evasionRaw="Rarity: NORMAL\nZodiac Leather\nItem Level: 70"
	local armourRaw="Rarity: NORMAL\nPlate Vest\nItem Level: 86"
	local function input(model,id)
		return sim.validateState(model,{rarity="MAGIC",affixes={{id=id,range=0.5}}})
	end
	it("retains the chosen base level and removes incompatible rollable entries before drawing counts",function()
		local evasion,armour=sim.model(evasionRaw),sim.model(armourRaw)
		local state=input(evasion,"IncreasedLife0");local donor=input(armour,"LocalIncreasedPhysicalDamageReductionRating1")
		local craft={method="recombine",donorItem=sim.toItem(armour,donor).raw}
		assert.is_true(sim.sameRecombinationClass(evasion.item,armour.item))
		local left=sim.action(evasion,state,craft,function() return 0.1 end)
		assert.are.equal("Zodiac Leather",sim.toItem(evasion,left).baseName);assert.are.equal(70,sim.toItem(evasion,left).itemLevel)
		-- With the older count table, a single eligible prefix and this draw yield zero.
		-- Counting the incompatible armour prefix would yield at least one instead.
		assert.are.equal(0,#left.affixes);assert.is_truthy(sim.validateState(evasion,left))
		local right=sim.action(evasion,state,craft,function() return 0.9 end)
		assert.are.equal("Plate Vest",sim.toItem(evasion,right).baseName);assert.are.equal(86,sim.toItem(evasion,right).itemLevel)
		assert.are.equal(2,#right.affixes);assert.is_truthy(sim.validateState(evasion,right))
		local changes=table.concat(require("Modules.CraftingInspection").diff(evasion,state,right),"\n")
		assert.is_truthy(changes:find("Plate Vest",1,true))
		assert.is_truthy(changes:find("Item level: 70 -> 86",1,true))
		assert.is_truthy(require("Modules.CraftingInspection").slots(evasion,right):find("Prefixes",1,true))
		assert.is_false(sim.sameRecombinationClass({type="Staff",base={subType="Warstaff"}},{type="Staff",base={subType="Staff"}}))
		local sword=sim.model("Rarity: NORMAL\nRusted Sword\nItem Level: 86");local spike="Rarity: NORMAL\nRusted Spike\nItem Level: 86"
		assert.is_false(sim.sameRecombinationClass(sword.item,sim.model(spike).item))
		assert.is_false(pcall(sim.action,sword,sword.initial,{method="recombine",donorItem=spike},function() return 0.5 end))
		assert.is_false(sim.sameRecombinationClass(evasion.item,sim.model("Rarity: NORMAL\nGold Ring\nItem Level: 86").item))
	end)
	it("retains a non-rollable crafted modifier across defence bases and permits later crafting",function()
		local evasion,armour=sim.model(evasionRaw),sim.model(armourRaw)
		local donor=sim.validateState(armour,{rarity="RARE",affixes={{id="bench:731",range=0.5,crafted=true}}})
		local values={0.1,0.9,0.9,0.9,0.9};local i=0
		local result=sim.action(evasion,evasion.initial,{method="recombine",donorItem=sim.toItem(armour,donor).raw},function() i=i+1;return values[i] or 0.9 end)
		assert.are.equal("Zodiac Leather",sim.toItem(evasion,result).baseName);assert.are.equal("bench:731",result.affixes[1].id)
		assert.is_truthy(sim.validateState(evasion,result))
		local next=sim.perform(evasionRaw,{method="augmentation"},1,result)
		assert.are.equal("Zodiac Leather",new("Item"):Item(next.itemText).baseName);assert.are.equal(70,new("Item"):Item(next.itemText).itemLevel)
	end)
	it("accepts same-class defence bases for predictable recombination",function()
		local evasion,armour=sim.model(evasionRaw),sim.model(armourRaw)
		local state=input(evasion,"IncreasedLife0");local donor=input(armour,"LocalIncreasedPhysicalDamageReductionRating1")
		local action={method="recombine_predictable",donorItem=sim.toItem(armour,donor).raw,selectedMods={left={"IncreasedLife0"},right={"LocalIncreasedPhysicalDamageReductionRating1"}},reportedSuccessChance=0}
		local result=sim.action(evasion,state,action,function() return 0.9 end)
		assert.is_true(result.destroyed)
	end)
	it("uses the recombined base for native target and affix views",function()
		newBuild()
		local evasion,armour=sim.model(evasionRaw),sim.model(armourRaw)
		local state=input(evasion,"IncreasedLife0");local donor=input(armour,"LocalIncreasedPhysicalDamageReductionRating1")
		local result=sim.action(evasion,state,{method="recombine",donorItem=sim.toItem(armour,donor).raw},function() return 0.9 end)
		local project={id="recombine-view",title="Recombined armour",slot="Body Armour",startingItem=evasionRaw,goals={},steps={},nativeRecipe={steps={{method="alchemy"}},targets={},requirements={minAffixes=1},initialState=result}}
		local controls=require("Classes.CraftingSimulatorControl").Open(build,project)
		local found=false;for _,entry in ipairs(controls.target.list) do if entry.val=="LocalIncreasedPhysicalDamageReductionRating1" then found=true end end
		assert.is_true(found)
		controls.itemMods.onClick({line={affixId="LocalIncreasedPhysicalDamageReductionRating1"}})
		local affix;for _,entry in ipairs(result.affixes) do if entry.id=="LocalIncreasedPhysicalDamageReductionRating1" then affix=entry end end
		local expected=require("Modules.PlanningUI").rows(require("Modules.CraftingInspection").modDetails(sim.context(evasion,result),"LocalIncreasedPhysicalDamageReductionRating1",affix),386)
		assert.same(expected,controls.affixFacts.list)
		controls.inspectItem:Click();assert.is_truthy(main.popups[1]);main:ClosePopup()
		controls.close:Click();main.popups={}
	end)
end)
