describe("Visual filter catalogue",function()
	local filters=require("Modules.LootFilters")
	local parser=require("Modules.LootFilterParser")
	local library=require("Modules.LootFilterLibrary")
	before_each(function() newBuild();main.popups={} end)
	after_each(function() main.popups={} end)
	it("browses real base blocks without mutating the profile or their conditions",function()
		local profile=filters.profile("test","Test");local before=copyTable(profile)
		local entries=library.catalog(profile);assert.is_true(#entries>500)
		assert.same(before,profile)
		local currency=library.entries(profile,entries,"Currency","Chaos Orb");assert.is_true(#currency>0)
		for _,entry in ipairs(currency) do assert.equal("Currency",entry.category);assert.is_true(entry.base);assert.equal(1,#parser.parse(entry.rule.text).rules) end
	end)
	it("edits appearance while preserving multi-value conditions, Continue and custom sound volume",function()
		local rule={id="base-1",title="Target",text='Show\n HasExplicitMod >=2 "of Haast" "of Ephij"\n BaseType == "Iron Hat"\n CustomAlertSound "my sound.wav" 125\n Continue',enabled=false}
		local changed=library.appearance(rule,{SetTextColor={"255","200","100"},SetFontSize={"40"}})
		local old,new=parser.parse(rule.text).rules[1],parser.parse(changed.text).rules[1]
		assert.same(old.conditions,new.conditions);assert.same({"my sound.wav","125"},new.styles.CustomAlertSound);assert.is_true(new.continue);assert.is_false(changed.enabled)
		assert.is_nil(rule.text:find("SetTextColor",1,true))
	end)
	it("creates a personal override without replacing imported source text",function()
		local profile=filters.profile("test","Test");profile.template='Show\n BaseType == "Iron Hat"\n SetTextColor 255 255 255'
		local source=profile.template;local entry=library.catalog(profile)[1]
		local override=library.appearance(entry.rule,{SetTextColor={"255","0","0"}});profile.rules={override}
		assert.equal(source,profile.template)
		local result=filters.simulate(profile,{BaseType="Iron Hat"});assert.same({"255","0","0"},result.styles.SetTextColor)
	end)
	it("keeps base override identities stable when unrelated source rules move",function()
		local profile=filters.profile("test","Test");local hat='Show\n BaseType == "Iron Hat"\n SetFontSize 40';local ring='Show\n BaseType == "Iron Ring"\n SetFontSize 30'
		profile.template=hat.."\n"..ring;local original=library.catalog(profile)
		profile.template=ring.."\n"..hat;local reordered=library.catalog(profile)
		assert.equal(original[1].rule.id,reordered[2].rule.id);assert.is_not.equal(original[1].rule.id,reordered[1].rule.id)
	end)
	it("generates deterministic example scenes and labels unknown item data honestly",function()
		local profile=filters.profile("test","Test");local first=library.scene(profile,build,"Mixed drops",7,72)
		assert.same(first,library.scene(profile,build,"Mixed drops",7,72));assert.equal(72,first[1].AreaLevel)
		for _,item in ipairs(library.scene(profile,build,"Currency",1,83)) do assert.equal("Stackable Currency",item.Class) end
		profile.template='Hide\n FutureCondition True\nShow'
		local unresolved=copyTable(first[1]);unresolved.BaseType="Iron Hat";unresolved.Class="Helmets"
		assert.equal("unknown",filters.simulate(profile,unresolved).status)
	end)
	it("builds example properties only when requested and reuses the parsed block",function()
		local p=filters.profile("test","Test");p.template='Show\n BaseType == "Iron Hat"\n ItemLevel >= 83'
		local entry=library.catalog(p)[1];assert.is_nil(rawget(entry,"sample"));local sample=entry.sample;assert.equal("Iron Hat",sample.BaseType);assert.equal(83,sample.ItemLevel)
		assert.equal(sample,entry.sample);assert.same(library.sample(entry.rule),sample)
	end)
	it("derives known equipment classes and leaves unfamiliar bases unknown",function()
		assert.equal("One Hand Swords",library.sample({text='Show\n BaseType == "Rusted Sword"'}).Class)
		local item=library.sample({text='Show\n BaseType == "Unknown Future Base"'});assert.is_nil(item.Class)
		assert.equal("unknown",parser.simulate(parser.parse('Hide\n Class == "Stackable Currency"\nShow'),item).status)
		local p=filters.profile("test","Test");p.template='Hide\nShow\n Continue'
		local entries=library.catalog(p);assert.equal("Hide remaining items",entries[1].rule.title);assert.equal("Style remaining items",entries[2].rule.title)
	end)
end)
