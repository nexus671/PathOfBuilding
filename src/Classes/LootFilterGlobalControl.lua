-- Reversible, build-owned settings applied to the complete compiled filter.
local ui=require("Modules.PlanningUI")
local filters=require("Modules.LootFilters")
local parser=require("Modules.LootFilterParser")
local visual=require("Modules.LootFilterVisuals")
local M={}
function M.Open(profile,onKeep)
	local c={};local settings=copyTable(profile.appearance or {})
	ui.description(c,"help",16,24,588,48,{"Change labels and alerts across personal rules and the base preset. Only declared sizes change; inherited sizes stay intact. Pickup conditions and tier colours are preserved."},14)
	local function setting(key,y,title,entries)
		ui.label(c,key.."Label",16,y,title,14)
		c[key]=new("DropDownControl"):DropDownControl(ui.anchor,{268,y-4,336,28},entries,function(_,value) settings[key]=value.val~=false and value.val or nil end)
		c[key]:SelByValue(settings[key]~=nil and settings[key] or false,"val")
	end
	local fonts={{label="Keep original sizes",val=false}};for _,size in ipairs({28,32,36,40,45}) do fonts[#fonts+1]={label="Minimum size "..size,val=size} end
	setting("minimumFontSize",92,"Label size",fonts)
	local volumes={{label="Keep original volumes",val=false},{label="Mute filter alerts",val=0}};for _,v in ipairs({50,100,200,300}) do volumes[#volumes+1]={label="Alert volume "..v,val=v} end
	setting("alertVolume",134,"Alert sounds",volumes)
	setting("disableEffects",176,"Drop beams",{{label="Keep original beams",val=false},{label="Disable beams",val=true}})
	c.preview=new("Control"):Control(ui.anchor,{16,212,588,74})
	function c.preview:Draw()
		local example=filters.rule("example","Example",{'BaseType == "Iron Hat"'},nil,profile.theme)
		local styles=parser.parse(require("Modules.LootFilterDecorators").apply(example.text,settings)).rules[1].styles
		local x,y=self:GetPos();visual.floor(x,y,588,74);visual.chip(x,y,588,74,{BaseType="Crafting base"},{action="Show",styles=styles})
	end
	c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,306,220,28},"Keep appearance",function() local next=copyTable(profile);next.appearance=settings;filters.compile(next);onKeep(next);main:ClosePopup() end)
	c.reset=new("ButtonControl"):ButtonControl(ui.anchor,{252,306,180,28},"Restore original",function() local next=copyTable(profile);next.appearance=nil;onKeep(next);main:ClosePopup() end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{448,306,156,28},"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keep=true});main:OpenPopup(620,354,"Whole-filter appearance",c,nil,nil,"close")
	for _,control in pairs(c) do if control.anchor then control.anchor.other=main.popups[1] end end
end
return M
