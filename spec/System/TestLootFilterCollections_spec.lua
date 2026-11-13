describe("Build-owned filter collections",function()
	local filters=require("Modules.LootFilters")
	local collections=require("Modules.LootFilterCollections")
	local function profile() local p=filters.profile("test","Test");p.template='Show\n BaseType == "Iron Hat"';return p end
	before_each(function() newBuild() end)
	it("keeps exact sample properties without filling missing fields or sharing mutable values",function()
		local item={BaseType="Iron Hat",AreaLevel=12,HasInfluence={"Shaper"},Corrupted=false}
		local p=collections.install(profile(),"sampleSets",{id="early",title="Early drops",samples={item}});item.HasInfluence[1]="Elder"
		assert.equal("Shaper",p.sampleSets[1].samples[1].HasInfluence[1]);assert.is_nil(p.sampleSets[1].samples[1].ItemLevel)
		p=collections.install(p,"sampleSets",{id="early",title="Replacement",samples={{BaseType="Chaos Orb"}}});assert.equal(1,#p.sampleSets);assert.equal("Replacement",p.sampleSets[1].title)
	end)
	it("validates arrays, numeric values, labels and property depth",function()
		for _,value in ipairs({{ItemLevel=math.huge},{ItemLevel=0/0},{BaseType="bad\0value"},{HasInfluence={{name="Shaper"}}},{HasInfluence=require("dkjson").null}}) do assert.has_error(function() collections.sample(value) end) end
		assert.has_error(function() collections.sampleSets({{id="empty",title="Empty",samples={}}}) end)
		assert.has_error(function() collections.sampleSets({{id="a",title="\n",samples={{}}}}) end)
		assert.has_error(function() collections.sampleSets({[2]={id="a",title="A",samples={{}}}}) end)
	end)
	it("restores a saved appearance without changing pickup conditions or its snapshot",function()
		local p=profile();p=collections.install(p,"palettes",{id="gold",title="My gold",theme="contrast",appearance={textColor={255,220,100,255},alertVolume=0}})
		local next=collections.palette(p,"gold");assert.same(p.rules,next.rules);assert.equal(p.template,next.template);assert.equal("contrast",next.theme);assert.equal(0,next.appearance.alertVolume)
		next.appearance.textColor[1]=0;assert.equal(255,next.palettes[1].appearance.textColor[1]);assert.is_nil(p.appearance)
	end)
	it("persists more than eight collections through native save and reopen",function()
		local p=profile();for i=1,12 do p=collections.install(p,"sampleSets",{id="set-"..i,title="Set "..i,samples={{BaseType="Iron Hat",ItemLevel=i}}}) end
		p=collections.install(p,"palettes",{id="muted",title="Muted",appearance={alertVolume=0}});build.savers.LootFilters:Upsert(p)
		local xml={};build.savers.LootFilters:Save(xml);local restored=filters.new(build);restored:Load(xml);assert.same(p,restored.data.profiles[1])
	end)
end)
