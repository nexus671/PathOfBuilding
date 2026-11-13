describe("Planning UX state",function()
	local ui=require("Modules.PlanningUI")
	before_each(function() newBuild();main.popups={};main.planningTextLarge=false end)
	after_each(function() main.popups={};main.planningTextLarge=false end)
	it("keeps planning file actions clear and restores the character header on return",function()
		local keys={"pointDisplay","levelScalingButton","characterLevel","classDrop","ascendDrop","secondaryAscendDrop","buildLoadouts","buildName"}
		local original={};for _,key in ipairs(keys) do original[key]=build.controls[key]:IsShown() end
		local oldWidth=main.screenW
		local ok,message=pcall(function()
			require("Modules.PlanningWorkspace").new(build);build.viewMode="PLANNER"
			for _,key in ipairs(keys) do assert.is_false(build.controls[key]:IsShown()) end
			for _,width in ipairs({960,1024,1280}) do
				main.screenW=width;local last=0
				for _,key in ipairs({"back","save","saveAs","planningContext"}) do
					local c=build.controls[key];local x,y=c:GetPos();local w,h=c:GetSize()
					assert.is_true(c:IsShown());assert.is_true(x>=last and y>=0 and y+h<=28 and x+w<=width)
					assert.are.equal("planning-header",c.layoutAudit);last=x+w
				end
			end
			build.viewMode="TREE";assert.is_false(build.controls.planningContext:IsShown())
			for _,key in ipairs(keys) do assert.are.equal(original[key],build.controls[key]:IsShown(),key) end
		end)
		main.screenW=oldWidth;build.viewMode="TREE";assert.is_true(ok,tostring(message))
	end)
	it("distinguishes a live draft, kept build changes and an actual save",function()
		ui.draft(build,"workingCraft");assert.truthy(ui.saveStatus(build):find("Working draft",1,true))
		ui.kept(build,"workingCraft");build.modFlag=true;assert.truthy(ui.saveStatus(build):find("Kept",1,true))
		build:ResetModFlags();ui.saved(build);assert.equal("Build saved",ui.saveStatus(build))
		ui.draft(build,"atlas");ui.saved(build);assert.truthy(ui.saveStatus(build):find("Working draft",1,true))
	end)
	it("keeps list browsing separate from checkbox activation",function()
		local selected,activated
		local list=new("TextListControl"):TextListControl(nil,{0,0,300,120},nil,{{height=28,id="one","First"},{height=28,id="two","Second"}})
		ui.selectable(list,function(row) return row.id end,function(row) selected=row.id end,function(row) activated=row.id end)
		list.planningMove(1);assert.equal("one",selected);assert.is_nil(activated)
		list.planningMove(1);assert.equal("two",selected);assert.is_true(list.list[2].selected)
		list.planningActivate();assert.equal("two",activated)
	end)
	it("round trips completed guide quests through native build XML",function()
		local data=require("Modules.BuildJourney").empty();data.stages={{id="act1",title="Act 1",level=12,quests="Finish the act",questChecks={"Finish the act"}}}
		build.savers.BuildJourney:Replace(data)
		local bridge=require("Modules.DesktopBuildBridge");local candidate=bridge.prepare(build,{mode="edit",title="Keep quest guide",baseRevision=bridge.revision(build),operations={{type="set_character",level=40}}}).candidate
		assert.equal("Finish the act",candidate.savers.BuildJourney.data.stages[1].questChecks[1])
	end)
	it("retains the chosen starting currency when a project is saved and reloaded",function()
		local store=build.savers.CraftingProjects;store:Upsert({id="hat",title="Hat",slot="Helmet",startingItem="Rarity: NORMAL\nIron Hat\nItem Level: 86",preferredMethod="alchemy",goals={},steps={}})
		local xml={};store:Save(xml);local loaded=require("Modules.CraftingProjects").new(build);loaded:Load(xml)
		assert.equal("alchemy",loaded.projects[1].preferredMethod)
	end)
end)
