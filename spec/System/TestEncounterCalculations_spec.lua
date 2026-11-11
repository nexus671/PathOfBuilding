describe("Encounter reporting and comparisons",function()
	local encounter=require("Modules.CalcEncounter")
	local time=require("Modules.CalcTime")
	before_each(function() newBuild() end)

	it("separates indexed incoming rolls while preserving reproducible trial identity",function()
		local count,trialCounts=0,{ }
		for trial=1,64 do
			trialCounts[trial]=0
			local seed=encounter.seed(104729,trial)
			assert.are.equal(seed,encounter.seed(104729,trial))
			for attempt=1,256 do
				local random=time.random(encounter.seed(seed,attempt,100))
				local rolls={}; for i=1,6 do rolls[i]=random() end
				if rolls[4] >= 0.75 then trialCounts[trial]=trialCounts[trial]+1 end
				if rolls[4] >= 0.75 and rolls[6] >= 0.47 then count=count+1 end
			end
		end
		assert.are.near(0.25*0.53,count/(64*256),0.01)
		local mean,variance=0,0
		for _,n in ipairs(trialCounts) do mean=mean+n/64 end
		for _,n in ipairs(trialCounts) do variance=variance+(n-mean)^2/63 end
		assert.is_true(variance > 20 and variance < 100,"Trial counts should vary around their binomial expectation, rather than repeating a correlated pattern")
	end)

	it("integrates poison application, gaps and expiry without multiplying steady DPS by uptime",function()
		local p=encounter.poison(1000)
		p:hit(0,{{slope=100,duration=2}},1,20)
		local rate,damage=p:advance(4)
		assert.are.equal(0,rate); assert.are.near(200,damage,1e-8)
		p:hit(5,{{slope=100,duration=2}},1,20)
		local _,total,direct=p:advance(10)
		assert.are.near(400,total,1e-8); assert.are.equal(40,direct)
	end)

	it("snapshots poison damage and independently expires old applications",function()
		local p=encounter.poison(1000)
		p:hit(0,{{slope=10,duration=4}},1)
		p:hit(2,{{slope=20,duration=4}},1)
		assert.are.near(30,p:advance(3),1e-8)
		assert.are.near(20,p:advance(4),1e-8)
		local rate,damage=p:advance(6)
		assert.are.equal(0,rate); assert.are.near(120,damage,1e-8)
	end)

	it("applies poison stream limits and the shared DoT cap before integration",function()
		local p=encounter.poison(25)
		p:hit(0,{{slope=100,duration=2,limit=10},{slope=100,duration=4}},1)
		local _,damage=p:advance(4)
		assert.are.near(100,damage,1e-8)
	end)

	it("rounds flask cost after combining local and global modifiers (#7578)",function()
		assert.are.equal(11,encounter.chargesUsed(20,-19,-32))
		assert.are.equal(10,encounter.chargesUsed(20,-19,-33))
	end)

	it("shares charge state across passive gain, use and event gain",function()
		local bank=encounter.charges({charges=20,used=10,generation=1,gain=2},function() return 1 end)
		assert.is_true(bank:use(0)); assert.are.equal(10,bank.charges)
		bank:gain(1,3); assert.are.equal(17,bank.charges)
		assert.is_true(bank:use(2)); assert.are.equal(8,bank.charges)
		bank:advance(4); assert.are.equal(10,bank.charges)
	end)

	it("honors non-consumption without allowing repeated uses at the same timestamp",function()
		local bank=encounter.charges({charges=10,used=10,freeChance=100},function() return 0 end)
		assert.are.equal(true,bank:use(0)); assert.are.equal(false,bank:use(0))
		assert.are.equal(true,bank:use(1)); assert.are.equal(10,bank.charges)
		assert.are.equal(2,bank.uses)
	end)

	it("limits critical charge gain to one recipient and a shared 100ms interval",function()
		local a=encounter.charges({charges=10,used=10},function() return 1 end)
		local b=encounter.charges({charges=10,used=10},function() return 1 end)
		a:use(0); b:use(0)
		local events=encounter.chargeEvents({a,b},{{critChance=100},{critChance=100}},function() return 0 end)
		events:critical(0,0); events:critical(0.05,0); events:critical(0.1,0)
		assert.are.equal(2,a.charges); assert.are.equal(0,b.charges)
	end)

	it("gives hit charges to each eligible flask with independent 100ms intervals",function()
		local a=encounter.charges({charges=10,used=10},function() return 1 end)
		local b=encounter.charges({charges=10,used=10},function() return 1 end)
		a:use(0); b:use(0)
		local events=encounter.chargeEvents({a,b},{{chargesWhenHit=3},{chargesWhenHit=2}},function() return 0 end)
		events:hit(0); events:hit(0.099); events:hit(0.1)
		assert.are.equal(6,a.charges); assert.are.equal(4,b.charges)
	end)

	it("recovers missing life at natural flask expiry but cancels that recovery at full",function()
		for _,cancel in ipairs({false,true}) do
			local use=time.recoveryFlask({charges=10,used=10,resources={Life=true},threshold=1,reaction=0})
			local p,full={Life=20},{Life=100}
			local function profile() return {Life={rate=10,finishLife=true}},5 end
			use(0,p,full,full,profile)
			if cancel then p.Life=100; use(1,p,full,full,profile); p.Life=20 end
			use(5,p,full,full,profile)
			assert.are.equal(cancel and 20 or 100,p.Life)
		end
	end)

	it("keeps hybrid recovery until both source pools are full",function()
		local use=time.recoveryFlask({charges=10,used=10,resources={Life=true,Mana=true},threshold=1,reaction=0})
		local p,full={Life=20,Mana=20},{Life=100,Mana=100}
		local function profile() return {Life={rate=10},Mana={rate=10}},5 end
		use(0,p,full,full,profile); p.Life=100
		local active=use(1,p,full,full,profile); assert.are.equal(true,active)
		p.Life=50; local _,rates=use(2,p,full,full,profile); assert.are.equal(10,rates.Life)
		p.Life,p.Mana=100,100; active=use(3,p,full,full,profile); assert.are.equal(false,active)
	end)

	it("ends ES copied from a Life flask when its source Life reaches full",function()
		local use=time.recoveryFlask({charges=10,used=10,resources={Life=true},threshold=1,reaction=0})
		local p,full={Life=20,EnergyShield=0},{Life=100,EnergyShield=100}
		local function profile() return {Life={rate=10},EnergyShield={rate=10}},5 end
		use(0,p,full,full,profile); p.Life=100
		assert.are.equal(false,use(1,p,full,full,profile))
	end)

	it("uses a Wilson interval that expresses uncertainty after zero deaths",function()
		local low,high=encounter.wilson(128,128)
		assert.is_true(low > 97 and low < 98); assert.are.near(100,high,1e-7)
		low,high=encounter.wilson(0,128)
		assert.are.near(0,low,1e-7); assert.is_true(high > 2 and high < 3)
	end)

	it("computes uncertainty from paired differences rather than independent arm variance",function()
		local delta,low,high=encounter.paired({{x=1},{x=100}},{{x=3},{x=102}},function(r) return r.x end)
		assert.are.equal(2,delta); assert.are.equal(2,low); assert.are.equal(2,high)
	end)

	it("bounds timeline events while retaining samples and the terminal state",function()
		local trace=encounter.trace(60)
		local p={Life=100,Mana=10,EnergyShield=20}
		for i=1,1100 do trace:add(i/100,p,"Hit") end
		trace:add(60,p,"Window reached")
		assert.are.equal(1001,#trace.rows); assert.are.equal(100,trace.dropped)
		assert.are.equal("Window reached",trace.rows[#trace.rows].event)
	end)

	it("does not alter results when observing a timeline",function()
		local function run(observe)
			return time.survival({pools={Life=100,Mana=0,EnergyShield=50},caps={Life=100,Mana=0,EnergyShield=50},
				window=10,interval=0.7,step=math.huge,rates={Life=5},observe=observe,
				hit=function(p) p.Life=p.Life-13; return p end})
		end
		local a,b=run(nil),run(function() end)
		assert.are.equal(a.time,b.time); assert.are.equal(a.pools.Life,b.pools.Life)
	end)

	it("reports configuration contradictions without modifying inputs",function()
		local input={multiplierManaBurnStacks=15,conditionFullLife=true,conditionLowLife=true}
		local rows,count=encounter.audit(input,{uncheckedRecovery=true})
		assert.are.equal(3,count); assert.is_true(#rows > count)
		assert.are.equal(15,input.multiplierManaBurnStacks)
	end)

	local function calculate()
		local input=build.configTab.input
		input.simulateRecovery=true; input.recoverySimulationAttacking=true
		input.recoverySimulationTrials=4; input.recoverySimulationWindow=10
		input.enemyDamageType="Untyped"; input.enemyIsBoss="None"; input.enemySpeed=1000; input.enemyCritChance=0
		for _,kind in ipairs({"Physical","Fire","Cold","Lightning","Chaos"}) do input["enemy"..kind.."Damage"]=kind=="Cold" and "20" or "0" end
		input.customMods="+3000 to maximum Life\n+60% to Cold Resistance"
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		return build.calcsTab.calcsOutput
	end

	it("creates named scenarios using existing saved config sets",function()
		calculate()
		local original=build.configTab.activeConfigSetId
		local config=build.configTab:CreateEncounterConfigSet(1)
		assert.are.equal("Single heavy hit",config.title)
		assert.are.equal(true,config.input.recoverySimulationSingleHit)
		assert.are.equal("40",config.input.enemyColdDamage)
		assert.are.equal("20",build.configTab.configSets[original].input.enemyColdDamage)
		local xml={}; build.configTab:Save(xml)
		build.configTab:Load(xml)
		assert.are.equal("Single heavy hit",build.configTab.configSets[config.id].title)
		assert.are.equal(true,build.configTab.configSets[config.id].input.recoverySimulationSingleHit)
	end)

	it("compares identical saved configs with zero deltas and no live mutation",function()
		calculate()
		local tab=build.configTab
		local original=tab.activeConfigSetId
		local target=tab:NewConfigSet(nil,"Same scenario")
		target.input=copyTable(tab.input); target.placeholder=copyTable(tab.placeholder)
		target.customModsList=copyTable(tab.configSets[original].customModsList)
		target.input.recoverySimulationTrials=99; target.input.recoverySimulationWindow=300; target.input.recoverySimulationSeed=9
		table.insert(tab.configSetOrderList,target.id)
		tab.input.recoverySimulationCompareSet=target.id
		tab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		local o=build.calcsTab.calcsOutput
		assert.are.near(0,o.RecoveryComparisonSurvivalDelta,1e-8)
		assert.are.near(0,o.RecoveryComparisonTimeDelta,1e-8)
		assert.are.near(0,o.RecoveryComparisonDamageDelta,1e-6)
		assert.are.equal(original,tab.activeConfigSetId)
		assert.are.equal(target.id,tab.input.recoverySimulationCompareSet)
		assert.are.equal(99,target.input.recoverySimulationTrials)
		assert.are.equal(300,target.input.recoverySimulationWindow)
		assert.are.equal(9,target.input.recoverySimulationSeed)
	end)

	it("reduces native poison-window damage when mana prevents further attacks",function()
		local claw=new("Item"):Item("Rarity: Normal\nImperial Claw")
		build.itemsTab:AddItem(claw); build.itemsTab.slots["Weapon 1"].selItemId=claw.id
		build.skillsTab:PasteSocketGroup("Cobra Lash 20/0  1")
		build.skillsTab:ProcessSocketGroup(build.skillsTab.socketGroupList[1])
		calculate()
		build.configTab.input.customMods="+3000 to maximum Life\n+100 to maximum Mana\n+60% to Cold Resistance\n100% chance to Poison on Hit\nCannot Regenerate Mana\n+50 to Total Mana Cost of Skills"
		build.configTab.input.poisonDamageWindow=10
		build.configTab:BuildModList(); runCallback("OnFrame")
		assert(not __mainObject__.promptMsg,__mainObject__.promptMsg)
		local actor=build.calcsTab.calcsEnv.player
		local o=actor.output
		assert.is_true(#actor.mainSkill.recoveryPoisonProfiles > 0)
		assert.is_true(o.RecoverySimulationPoisonDPS > 0)
		assert.is_true(o.RecoverySimulationAttackUptime < 100)
		assert.is_true(o.RecoverySimulationPoisonDPS < o.PoisonWindowAverageDPS)
	end)

	it("renders the timeline graph and configuration report through native Calcs",function()
		calculate()
		local actor=build.calcsTab.calcsEnv.player
		assert.is_true(#actor.recoverySimulationTrace.points > 1)
		assert.is_true(#actor.breakdown.RecoverySimulationTimeline.rowList > 1)
		local control=build.calcsTab.controls.breakdown
		control:DrawEncounterTimeline(0,0,{width=730,timeline=actor.recoverySimulationTrace})
		for _,view in ipairs({"CONFIG","CALCS"}) do build.viewMode=view; runCallback("OnFrame"); assert(not __mainObject__.promptMsg,__mainObject__.promptMsg) end
	end)

	it("parses local hit-charge and end-recovery flask properties",function()
		local flask=new("Item"):Item("Rarity: Magic\nFlagellant's Granite Flask\nGranite Flask\nGain 3 Charges when you are Hit by an Enemy")
		assert.are.equal(3,flask.flaskData.chargesWhenHit)
		local karui=new("Item"):Item("Rarity: Unique\nBlood of the Karui\nSanctified Life Flask\nRecover Full Life at the end of the Effect")
		assert.are.equal(true,karui.flaskData.finishLife)
	end)
end)
