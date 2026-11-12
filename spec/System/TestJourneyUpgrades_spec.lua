describe("Measured Journey upgrades",function()
	local upgrades=require("Modules.JourneyUpgrades")
	local bridge=require("Modules.DesktopBuildBridge")
	local function item(life) return "Rarity: RARE\nPlanned Hat\nIron Hat\nItem Level: 86\n+"..life.." to maximum Life" end
	local function setup()
		local data=require("Modules.BuildJourney").empty()
		data.resources={{id="chaos",title="Chaos Orbs"},{id="divine",title="Divine Orbs"}}
		data.wishlist={{id="small",title="Small upgrade",slot="Helmet",route="buy",targetItem=item(100),resourceId="chaos",estimate=10},{id="large",title="Large upgrade",slot="Helmet",route="buy",targetItem=item(150),resourceId="chaos",estimate=30}}
		build.savers.BuildJourney:Replace(data);return data
	end
	local function finish() for i=1,2000 do if not upgrades.job then return end;upgrades.tick(build) end;error("Upgrade job did not finish") end
	before_each(function() upgrades.cancel();upgrades.result=nil;newBuild();bridge.plan={goal="balanced"};bridge.history={} end)
	after_each(function() upgrades.cancel();upgrades.result=nil end)
	it("measures isolated native candidates and ranks absolute gain separately from gain per resource",function()
		setup();local revision=bridge.revision(build);local life=build.calcsTab.calcsOutput.LifeUnreserved
		local result;upgrades.start(build,function(value) result=value end);finish()
		assert.equal(2,result.completed);assert.equal("calculated",result.entries.small.status)
		assert.equal(life,build.calcsTab.calcsOutput.LifeUnreserved);assert.equal(revision,bridge.revision(build))
		assert.equal("large",upgrades.sorted(build,"LifeUnreserved",false)[1].id)
		assert.equal("small",upgrades.sorted(build,"LifeUnreserved",true)[1].id)
		assert.equal(result.entries.small.delta.LifeUnreserved/10,result.entries.small.perCost.LifeUnreserved)
		assert.equal(0,#bridge.history)
	end)
	it("groups different resources and avoids ratios for missing or zero costs",function()
		local data=setup();data.wishlist[2].resourceId="divine";data.wishlist[2].estimate=0
		data.wishlist[3]={id="unpriced",title="Zero cost",slot="Helmet",route="buy",targetItem=item(1000),resourceId="chaos",estimate=0}
		data.wishlist[4]={id="unquoted",title="No recorded quote",slot="Helmet",route="buy",targetItem=item(2000)}
		build.savers.BuildJourney:Replace(data)
		upgrades.start(build);finish();assert.is_nil(upgrades.result.entries.large.perCost.LifeUnreserved)
		local ordered=upgrades.sorted(build,"LifeUnreserved",true);assert.equal("small",ordered[1].id);assert.equal("unpriced",ordered[2].id);assert.equal("divine",ordered[3].resourceId);assert.equal("unquoted",ordered[4].id)
	end)
	it("reports missing targets and uses exact linked crafting targets",function()
		local data=setup();data.wishlist[1].targetItem=nil;data.wishlist[2].targetItem=nil;data.wishlist[2].projectId="hat"
		build.savers.CraftingProjects:Upsert({id="hat",title="Hat",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",targetItem=item(150),goals={},steps={}})
		build.savers.BuildJourney:Replace(data);upgrades.start(build);finish()
		assert.equal("missing-target",upgrades.result.entries.small.status);assert.equal("calculated",upgrades.result.entries.large.status)
	end)
	it("cancels when the base changes instead of finishing a mixed-revision ranking",function()
		setup();upgrades.start(build);upgrades.tick(build);build.notesTab.controls.edit:SetText("Changed base")
		upgrades.tick(build);assert.is_nil(upgrades.job);assert.is_true(upgrades.result.stale);assert.equal(0,upgrades.result.completed)
		local _,fresh=upgrades.sorted(build,"LifeUnreserved",false);assert.is_false(fresh)
	end)
	it("supports explicit cancellation and an empty wishlist",function()
		setup();local result;upgrades.start(build,function(value) result=value end);upgrades.cancel();assert.is_true(result.cancelled);assert.equal(0,result.completed)
		build.savers.BuildJourney:Replace(require("Modules.BuildJourney").empty());upgrades.start(build);finish();assert.equal(0,upgrades.result.total)
	end)
	it("invalidates constraint eligibility when goals change without changing build XML",function()
		setup();upgrades.start(build);finish();assert.is_true(upgrades.fresh(build))
		bridge.plan={goal="balanced",minimums={LifeUnreserved=100000}};assert.is_false(upgrades.fresh(build))
	end)
	it("shows newly added target fields in native proposal review",function()
		local data=setup();data.wishlist[1].targetItem=nil;build.savers.BuildJourney:Replace(data)
		data.wishlist[1].targetItem=item(100)
		local prepared=bridge.prepare(build,{mode="edit",title="Add exact target",baseRevision=bridge.revision(build),operations={{type="set_build_journey",journey=data}}})
		assert.truthy(table.concat(prepared.changes," "):find("targetItem",1,true))
	end)
	it("handles prerequisites and completion in long reverse-ordered roadmaps",function()
		local data=require("Modules.BuildJourney").empty()
		for i=1200,1,-1 do data.milestones[#data.milestones+1]={id="m"..i,title="Milestone "..i,done=true,dependencies=i>1 and {"m"..(i-1)} or {}} end
		build.savers.BuildJourney:Replace(data)
		local blocked=require("Modules.BuildJourney").dependents(data,"m1");assert.is_true(blocked.m1200)
		build.savers.BuildJourney:Complete("m1");assert.is_false(build.savers.BuildJourney.data.milestones[1].done)
	end)
	it("reports encounter deltas only when the same native simulation is enabled on the base",function()
		setup();local input=build.configTab.input
		input.simulateRecovery=true;input.recoverySimulationTrials=2;input.recoverySimulationWindow=3
		input.enemyDamageType="Untyped";input.enemyColdDamage="20";input.enemySpeed=1000
		build.configTab:BuildModList();runCallback("OnFrame")
		upgrades.start(build);finish();local row=upgrades.result.entries.small
		assert.equal("calculated",row.status);assert.is_number(row.delta.RecoverySimulationSurvivalChance)
		assert.equal(row.after.RecoverySimulationSurvivalChance-row.before.RecoverySimulationSurvivalChance,row.delta.RecoverySimulationSurvivalChance)
		assert.is_true(build.configTab.input.simulateRecovery)
	end)
end)
