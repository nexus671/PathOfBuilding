describe("Omen of Trichromatism",function()
	local sim=require("Modules.CraftingSimulator")
	local check=require("Modules.CraftingAvailability").check
	local raw="Rarity: NORMAL\nPlate Vest\nItem Level: 86\nQuality: 20\nSockets: W-W-W-W-W-W"
	local omen="Metadata/Items/Currency/AncestralOmenOnChromaticAddWhiteSockets"
	local chromatic="Metadata/Items/Currency/CurrencyRerollSocketColours"
	local action={method="omen_trichromatism"}
	local function counts(state)
		local out={R=0,G=0,B=0,W=0};for _,socket in ipairs(state.sockets) do out[socket.color]=out[socket.color]+1 end;return out
	end
	before_each(function() newBuild() end)
	after_each(function() require("Modules.CraftingTasks").cancel();main.popups={} end)
	it("guarantees exactly one of each colour on three sockets without changing links or item properties",function()
		local text=raw:gsub("W%-W%-W%-W%-W%-W","W-W-W");local model=sim.model(text);local before=copyTable(model.initial)
		for seed=1,20 do
			local r=sim.perform(text,action,seed);assert.are.same({R=1,G=1,B=1,W=0},counts(r.state))
			local restored=copyTable(r.state);for i,socket in ipairs(restored.sockets) do socket.color=before.sockets[i].color end
			assert.are.same(before,restored);assert.are.same(r.state.sockets,new("Item"):Item(r.itemText).sockets)
		end
		assert.are.same(before,model.initial)
	end)
	it("keeps the guarantee on larger items while preserving socket partitions and seeded replay",function()
		local text=raw:gsub("W%-W%-W%-W%-W%-W","W-W W-W W-W");local before=sim.model(text).initial;local variants={}
		for seed=1,30 do
			local r=sim.perform(text,action,seed);local n=counts(r.state);assert.is_true(n.R>=1 and n.G>=1 and n.B>=1);assert.are.equal(6,#r.state.sockets)
			for i,socket in ipairs(r.state.sockets) do assert.are.equal(before.sockets[i].group,socket.group) end
			assert.are.same(r.state,sim.perform(text,action,seed).state);variants[require("dkjson").encode(r.state.sockets)]=true
		end
		local n=0;for _ in pairs(variants) do n=n+1 end;assert.is_true(n>1)
	end)
	it("rejects insufficient, Abyssal, corrupted and mirrored inputs before drawing randomness",function()
		local model=sim.model(raw);local variants={}
		for n=0,2 do local s=copyTable(model.initial);s.sockets={};for i=1,n do s.sockets[i]={color="W",group=i-1} end;variants[#variants+1]=s end
		local abyss=copyTable(model.initial);abyss.sockets[1].color="A";variants[#variants+1]=abyss
		local corrupt=copyTable(model.initial);corrupt.corrupted=true;variants[#variants+1]=corrupt
		local mirror=copyTable(model.initial);mirror.mirrored=true;variants[#variants+1]=mirror
		for _,state in ipairs(variants) do
			assert.is_false(check(action.method,state,model));local draws=0
			assert.is_false(pcall(sim.action,model,state,action,function() draws=draws+1;return 0.5 end));assert.are.equal(0,draws)
		end
	end)
	it("charges both ingredients once, preserving resource quantities under an action override",function()
		assert.are.same({[omen]=1,[chromatic]=1},sim.components(action))
		local recipe={steps={action},targets={},requirements={socketColours="RGB",linkedColours=true}}
		local options={trials=10,maxActions=1,prices={[omen]=2,[chromatic]=0.25},currency="chaos"}
		local r=sim.simulate(raw,recipe,options);assert.are.equal(10,r.successes);assert.are.equal(2.25,r.meanCost)
		assert.are.equal(10,r.currencySpent[omen]);assert.are.equal(10,r.currencySpent[chromatic])
		options.actionPrices={[action.method]=7};local quoted=sim.simulate(raw,recipe,options)
		assert.are.equal(7,quoted.meanCost);assert.are.same(r.resourceUsage,quoted.resourceUsage)
		options.actionPrices=nil;options.prices[chromatic]=nil;local missing=sim.simulate(raw,recipe,options)
		assert.is_nil(missing.meanCost);assert.is_true(missing.unpriced[chromatic])
	end)
	it("exposes discovery, eligibility and sampled placement assumptions",function()
		local c=sim.catalog(raw,"rgb",5);assert.are.equal(1,#c.socketCrafts);local entry=c.socketCrafts[1]
		assert.are.same(action,entry.action);assert.is_true(entry.available);assert.is_false(entry.deterministic);assert.are.equal("RGB",entry.guaranteedColours)
		assert.are.same(sim.components(action),entry.components);assert.are.equal("Sockets",require("Modules.CraftingInspection").category(action.method))
		assert.is_truthy(require("Modules.CraftingWorkbench").icon(action.method))
		local r=sim.calculate(raw,action,{},nil,{requirements={socketColours="RGB",linkedColours=true},trials=10})
		assert.is_true(r.sampled);assert.are.equal(100,r.successChance);assert.is_truthy(table.concat(r.limitations," "):find("Forced positions are sampled uniformly",1,true))
	end)
	it("supports native apply, undo and working-craft save/reopen",function()
		local p={id="rgb",title="RGB item",slot="Body Armour",startingItem=raw,goals={},steps={},preferredMethod=action.method}
		local c=require("Classes.CraftingSimulatorControl").Open(build,p);c.apply:Click();c.keepWorking:Click()
		local run=build.savers.CraftingProjects.projects[1].run;assert.are.equal(action.method,run.actions[1].method);local n=counts(run.state);assert.is_true(n.R>0 and n.G>0 and n.B>0)
		local xml=build:SaveDB("RGB guide");main.popups={};loadBuildFromXML(xml,"RGB guide");c=require("Classes.CraftingSimulatorControl").Open(build,build.savers.CraftingProjects.projects[1]);c.undo:Click();c.keepWorking:Click()
		assert.are.same(sim.model(raw).initial.sockets,build.savers.CraftingProjects.projects[1].run.state.sockets)
	end)
	it("enumerates all six three-socket placements and partially linked goals without sampling noise",function()
		local text=raw:gsub("W%-W%-W%-W%-W%-W","W-W W");local state=sim.model(text).initial;local before=copyTable(state)
		local r=sim.calculate(text,action,{},state,{requirements={socketColours="RG",linkedColours=true}})
		assert.is_false(r.sampled);assert.is_nil(r.confidenceLow);assert.are.equal(6,#r.outcomes);assert.are.equal(2,r.matchingWeight);assert.are.near(100/3,r.successChance,1e-10)
		local variants={};for _,entry in ipairs(r.outcomes) do assert.are.same({R=1,G=1,B=1,W=0},counts(entry.state));variants[require("dkjson").encode(entry.state.sockets)]=true end
		local n=0;for _ in pairs(variants) do n=n+1 end;assert.are.equal(6,n);assert.are.same(before,state)
		r=sim.calculate(text,action,{},state,{requirements={socketColours="RGB"}});assert.are.equal(100,r.successChance)
		r=sim.calculate(text,action,{},state,{requirements={socketColours="RGB",linkedColours=true}});assert.are.equal(0,r.successChance)
	end)
	it("does not offer unsupported Allflame combinations through a misleading editable profile",function()
		local model=sim.model(raw);local mixed={method=action.method,allflame={outcomes=2,gainMin=1,gainMax=1,sulphur=1}}
		assert.is_false(sim.supportsAllflame(action.method));assert.is_true(sim.supportsAllflame("alchemy"))
		assert.is_false(pcall(sim.allflameProfile,model,model.initial,mixed));assert.is_false(pcall(sim.perform,raw,mixed,1))
		local c=require("Classes.CraftingSimulatorControl").Open(build,{id="rgb-profile",title="RGB",slot="Body Armour",startingItem=raw,goals={},steps={},preferredMethod=action.method})
		c.page:SelByValue("Craft settings");c.page.selFunc();assert.is_false(c.allflame:IsEnabled());c.allflame:Click()
		assert.is_false(c.exact:IsEnabled());assert.is_truthy(c.exact:GetProperty("tooltipText"):find("Choose a target",1,true))
		assert.are.equal("Crafting workbench",main.popups[1].title)
	end)
	it("rejects every crafting action on a destroyed item rather than changing its remaining socket state",function()
		local model=sim.model(raw);local state=copyTable(model.initial);state.destroyed=true;state.corrupted=true;local before=copyTable(state)
		for _,method in ipairs(sim.methods) do
			local draws=0;assert.is_false(pcall(sim.action,model,state,{method=method},function() draws=draws+1;return 0.5 end),method)
			assert.are.equal(0,draws);assert.are.same(before,state)
		end
		assert.is_false(pcall(sim.perform,raw,{method="tainted_chromatic"},1,state))
	end)
end)
