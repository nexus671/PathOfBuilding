local ui=require("Modules.PlanningUI")
local fossil=require("Modules.CraftingFossilResults")
local visual=require("Modules.LootFilterVisuals")
local P={}
function P.Open(result,onChoose)
	local c={};local width,height=math.min(1080,main.screenW-40),math.min(660,main.screenH-60)
	local listWidth=width-340;local side=width-308;local sideWidth=292
	local ordered,selected;local images={}
	local artFile=assert(io.open("Assets/Crafting/currencies.json","rb"));local art=assert(require("dkjson").decode(artFile:read("*a")));artFile:close()
	local unit=result.costCurrency or "currency"
	local intro={string.format("%d subsets | %d trials each | Prices in %s",#result.combinations,result.trialsPerCombination,unit)}
	if result.priceSource then intro[#intro+1]=ui.fit("Quotes: "..result.priceSource.." | "..os.date("%Y-%m-%d",result.priceQuotedAt),width-32,14) else intro[#intro+1]="No saved quote source. Missing ingredient prices remain unknown." end
	ui.description(c,"intro",16,24,width-32,40,intro,14)
	c.sort=new("DropDownControl"):DropDownControl(ui.anchor,{16,82,listWidth,28},{
		{label="Cost per observed success",val="costPerSuccess"},{label="Success chance",val="successChance"},{label="Cost per trial",val="meanCost"}})
	ui.label(c,"orderNote",16,114,"",12)
	c.orderNote.label=function() return ui.fit(c.sort:GetSelValueByKey("val")=="successChance" and "Highest sampled chance first." or "Unknown estimates follow priced subsets; ties use success chance.",listWidth,12) end
	c.results=new("TextListControl"):TextListControl(ui.anchor,{16,128,listWidth,height-184},nil,{})
	ui.description(c,"names",side,82,sideWidth,100,{},16)
	ui.description(c,"stats",side,192,sideWidth,142,{},14)
	local graph=new("Control"):Control(ui.anchor,{side,346,sideWidth,86});c.probability=graph
	function graph:Draw()
		local x,y=self:GetPos();SetViewport(x,y,self.width,self.height);visual.box(0,0,self.width,self.height,"^x101822")
		visual.text(12,10,12,"Modeled success / 95% sampling interval","^xD5DEE8",self.width-24)
		visual.box(12,36,self.width-24,12,"^x344253")
		if selected and not selected.error then
			local w=self.width-24;visual.box(12,36,w*selected.successChance/100,12,"^x79D8A0")
			visual.box(12+w*selected.confidenceLow/100,54,math.max(1,w*(selected.confidenceHigh-selected.confidenceLow)/100),3,"^xDDBB78")
		end
		visual.text(12,64,12,"0%","^xD5DEE8");visual.text(self.width-40,64,12,"100%","^xD5DEE8");SetViewport()
	end
	ui.description(c,"note",side,442,sideWidth,48,{"Captured inputs; rerun after edits. Sampling intervals exclude uncertainty in game rules."},12)
	local function choose(index)
		selected=ordered[index];c.results.selectedKey=index
		for _,row in ipairs(c.results.list) do row.selected=row.key==index end
		c.names.list=ui.rows(fossil.names(selected),sideWidth-20,16)
		local actionOverride=(selected.actionPriceOverridesApplied or 0)>0
		local resourceOverride=result.resourcePriceOverridesSupplied
		if actionOverride or resourceOverride then
			local label=actionOverride and resourceOverride and "Resource + action overrides supplied" or actionOverride and "Action total override" or "Resource quote overrides supplied"
			c.names.list[#c.names.list+1]={height=17,textSize=14,"^xDDBB78"..label}
		end
		local lines={}
		if selected.error then lines={ui.errorText(selected.error)} else
			lines={string.format("%.2f%% success (%d / %d)",selected.successChance,selected.successes,result.trialsPerCombination),string.format("95%% interval: %.2f-%.2f%%",selected.confidenceLow,selected.confidenceHigh)}
			lines[#lines+1]=selected.meanCost~=nil and string.format("Mean / trial: %.4g %s",selected.meanCost,unit) or "Cost unknown: quote every ingredient."
			lines[#lines+1]=selected.costPerSuccess~=nil and string.format("Per observed success: %.4g %s",selected.costPerSuccess,unit) or "Cost per success: no estimate."
			if selected.successes==0 then lines[#lines+1]="No observed successes does not prove impossibility." end
		end
		c.stats.list=ui.rows(lines,sideWidth-20,14)
	end
	local function refresh()
		ordered=fossil.sort(result.combinations,c.sort:GetSelValueByKey("val"));local rows={}
		for index,entry in ipairs(ordered) do
			local names={};for _,name in ipairs(fossil.names(entry)) do names[#names+1]=name:gsub(" Fossil$","") end
			rows[#rows+1]={height=24,textSize=16,x=138,"^xE2C28C"..ui.fit(table.concat(names," + "),listWidth-164,16),key=index,fossils=entry.fossils}
			rows[#rows+1]={height=24,textSize=13,x=138,entry.error and "^xE07070Unavailable" or string.format("^xD5DEE8%.2f%% | %d / %d",entry.successChance,entry.successes,result.trialsPerCombination),key=index}
			local cost=entry.costPerSuccess~=nil and string.format("%.4g %s / success",entry.costPerSuccess,unit) or entry.meanCost~=nil and string.format("%.4g %s / trial",entry.meanCost,unit) or "Cost unknown"
			rows[#rows+1]={height=24,textSize=13,x=138,"^xA6B3C6"..ui.fit(cost,listWidth-164,13),key=index}
		end
		c.results.list=rows;c.results.controls.scrollBar.offset=0
		if #ordered>0 then choose(1) else c.names.list=ui.rows({"No subsets to compare."},sideWidth,16);c.stats.list={} end
	end
	local draw=c.results.Draw
	function c.results:Draw(viewport)
		draw(self,viewport);local x,y=self:GetPos();local w,h=self:GetSize();SetViewport(x+2,y+2,w-20,h-4)
		local top=-self.controls.scrollBar.offset
		for _,row in ipairs(self.list) do
			if row.fossils and top+52>=0 and top<h-4 then for i,id in ipairs(row.fossils) do
				local entry=art.items[id]
				if entry then local image=images[id];if not image then image=NewImageHandle();image:Load(entry.path);images[id]=image end
					SetDrawColor(1,1,1);DrawImage(image,6+(i-1)*30,top+18,28,28)
				end
			end end
			top=top+row.height
		end
		SetViewport()
	end
	ui.selectable(c.results,function(row) return row.key end,function(row) choose(row.key) end)
	c.sort.selFunc=refresh
	c.choose=new("ButtonControl"):ButtonControl(ui.anchor,{side,height-82,sideWidth,28},"Use selected fossils",function() onChoose(copyTable(selected.fossils));main:ClosePopup() end)
	c.choose.enabled=function() return onChoose~=nil and selected~=nil and not selected.error end
	c.choose.tooltipText="Configure this combination in the workbench. No currency is spent and the item is unchanged."
	c.copy=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-42,220,28},"Copy comparison (CSV)",function() Copy(fossil.csv(result)) end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{width-132,height-42,116,28},"Close",function() main:ClosePopup() end)
	ui.style(c,{choose=true});for _,control in pairs(c) do control.layoutAudit="crafting-fossil-comparison" end
	refresh();main:OpenPopup(width,height,"Fossil comparison",c,nil,nil,"close");return c
end
return P
