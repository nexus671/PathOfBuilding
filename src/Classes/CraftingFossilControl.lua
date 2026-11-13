-- Shared fossil configuration for the emulator and recipe editor.
local ui=require("Modules.PlanningUI")
local M={}
function M.Open(model,configured,onUse)
	local popup={};local choices={{label="None"}}
	ui.label(popup,"hint",16,28,"Choose up to four different fossils. Tangled needs its revealed outcome.",14)
	for _,entry in ipairs(model.fossils) do choices[#choices+1]={label=entry.name,id=entry.id} end
	for i=1,4 do
		popup["fossil"..i]=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,26+i*34,608,24},choices)
		local id=configured and configured.fossils and configured.fossils[i];if id then popup["fossil"..i]:SelByValue(id,"id") end
	end
	local outcomes={};for id,fossil in pairs(require("Modules.CraftingAdvanced").data().fossils) do if id:find("RandomFossilOutcome",1,true) then
		local descriptions={};for _,text in pairsSortByKey(fossil.descriptions) do descriptions[#descriptions+1]=text end
		outcomes[#outcomes+1]={label=table.concat(descriptions," / "),id=id}
	end end;table.sort(outcomes,function(a,b) return a.label < b.label end);table.insert(outcomes,1,{label="No revealed Tangled outcome"})
	popup.tangled=new("DropDownControl"):DropDownControl({"TOPLEFT",nil,"TOPLEFT"},{16,210,608,24},outcomes)
	if configured and configured.tangledOutcome then popup.tangled:SelByValue(configured.tangledOutcome,"id") end
	popup.use=ui.styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{16,260,180,24},"Use combination",function()
		local ok,err=pcall(function()
			local ids,seen={},{};for i=1,4 do local value=popup["fossil"..i]:GetSelValue();if value.id then
				assert(not seen[value.id],"Choose each fossil only once");seen[value.id]=true;ids[#ids+1]=value.id
			end end
			assert(#ids > 0,"Choose at least one fossil")
			onUse({method="fossil",fossils=ids,tangledOutcome=popup.tangled:GetSelValueByKey("id")});main:ClosePopup()
		end)
		if not ok then main:OpenMessagePopup("Native crafting",ui.errorText(err)) end
	end))
	popup.close=ui.styleButton(new("ButtonControl"):ButtonControl({"TOPLEFT",nil,"TOPLEFT"},{508,260,116,24},"Cancel",function() main:ClosePopup() end))
	main:OpenPopup(640,310,"Fossil combination",popup,nil,nil,"close")
	return popup
end
return M
