local ui=require("Modules.PlanningUI")
local visual=require("Modules.LootFilterVisuals")
local options=require("Modules.LootFilterAppearanceSettings")
local M={}
function M.Open(original,sample,onKeep)
	local c={};local w,h=760,548;local sounds={"Keep current","Silent","Numbered alert","Positional alert","Custom sound","Optional custom sound"};local volumeChanged=false
	local numbered=original.PlayAlertSound or original.PlayAlertSoundPositional
	local current=original.CustomAlertSound or original.CustomAlertSoundOptional or numbered
	local isCustom=current and (current==original.CustomAlertSound or current==original.CustomAlertSoundOptional)
	local volume=tonumber(current and current[2]) or (isCustom and 100 or 50)
	local function label(key,x,y,title) ui.label(c,key,x,y,title,14) end
	local function drop(key,x,y,entries) c[key]=new("DropDownControl"):DropDownControl(ui.anchor,{x,y,352,28},entries);return c[key] end
	label("soundLabel",16,140,"Alert type");drop("soundKind",16,164,sounds)
	label("iconLabel",392,140,"Minimap shape");local shapes={"Keep current","None"};for _,shape in ipairs(options.shapes) do shapes[#shapes+1]=shape end
	drop("iconShape",392,164,shapes);if original.MinimapIcon then c.iconShape:SelByValue(tonumber(original.MinimapIcon[1])==-1 and "None" or original.MinimapIcon[3] or "Keep current") end
	label("alertLabel",16,208,"Numbered alert identity");local ids={};for i=1,16 do ids[#ids+1]={label="Alert "..i,val=i} end
	drop("alertId",16,232,ids);c.alertId:SelByValue(tonumber(numbered and numbered[1]) or 1,"val")
	c.alertId.enabled=function() return c.soundKind.selIndex==3 or c.soundKind.selIndex==4 end
	label("iconColorLabel",392,208,"Minimap colour");drop("iconColor",392,232,options.colors);c.iconColor:SelByValue(original.MinimapIcon and original.MinimapIcon[2] or "Cyan")
	label("volumeLabel",16,276,"",14);c.volumeLabel.label=function() return "^7Alert volume: "..volume end
	c.volume=new("SliderControl"):SliderControl(ui.anchor,{16,304,352,24},function(value) volume=math.floor(value*300+0.5);volumeChanged=true end);c.volume.val=volume/300
	label("iconSizeLabel",392,276,"Minimap size");drop("iconSize",392,300,{{label="Large",val=0},{label="Medium",val=1},{label="Small",val=2}});c.iconSize:SelByValue(tonumber(original.MinimapIcon and original.MinimapIcon[1]) or 1,"val")
	for _,key in ipairs({"iconColor","iconSize"}) do c[key].enabled=function() return c.iconShape.selIndex>2 end end
	label("customLabel",16,348,"Custom sound file / relative path")
	c.customPath=new("EditControl"):EditControl(ui.anchor,{16,372,352,28},original.CustomAlertSound and original.CustomAlertSound[1] or original.CustomAlertSoundOptional and original.CustomAlertSoundOptional[1] or "",nil,nil,500);c.customPath.placeholder="sound.wav"
	c.customPath.enabled=function() return c.soundKind.selIndex>=5 end
	label("beamLabel",392,348,"Drop beam")
	local beams={"Keep current","None"};for _,color in ipairs(options.colors) do beams[#beams+1]=color end
	drop("beam",392,372,beams);c.beam:SelByValue(original.PlayEffect and original.PlayEffect[1] or "Keep current")
	label("beamDurationLabel",392,420,"Beam duration");drop("beamDuration",392,444,{"Permanent","Temporary"});c.beamDuration:SelByValue(original.PlayEffect and original.PlayEffect[2]=="Temp" and "Temporary" or "Permanent");c.beamDuration.enabled=function() return c.beam.selIndex>2 end
	ui.description(c,"help",16,420,352,58,{"Custom audio overrides built-in alerts; optional files fall back if missing. Previews use reference tones."},13)
	local function styles(strict)
		local next=copyTable(original);local mode=c.soundKind.selIndex
		if mode>1 then for _,key in ipairs({"PlayAlertSound","PlayAlertSoundPositional","CustomAlertSound","CustomAlertSoundOptional"}) do next[key]=nil end end
		if mode==2 then next.PlayAlertSound={"None"};next.CustomAlertSound={"None"}
		elseif mode==3 or mode==4 then next[mode==3 and "PlayAlertSound" or "PlayAlertSoundPositional"]={tostring(c.alertId:GetSelValueByKey("val")),tostring(volume)}
		elseif mode>=5 then
			local path=c.customPath.buf;local valid=path:match("%S") and not path:find('["\r\n]');if strict then assert(valid,"Enter a sound path without quotes or newlines") end
			if valid then next[mode==5 and "CustomAlertSound" or "CustomAlertSoundOptional"]={path,tostring(volume)} end
		elseif mode==1 and volumeChanged then for _,key in ipairs({"PlayAlertSound","PlayAlertSoundPositional","CustomAlertSound","CustomAlertSoundOptional"}) do if next[key] and next[key][1]~="None" then next[key][2]=tostring(volume) end end end
		if c.iconShape.selIndex==2 then next.MinimapIcon={"-1"} elseif c.iconShape.selIndex>2 then next.MinimapIcon={tostring(c.iconSize:GetSelValueByKey("val")),c.iconColor:GetSelValue(),c.iconShape:GetSelValue()} end
		if c.beam.selIndex==2 then next.PlayEffect={"None"} elseif c.beam.selIndex>2 then next.PlayEffect={c.beam:GetSelValue()};if c.beamDuration.selIndex==2 then next.PlayEffect[2]="Temp" end end
		return next
	end
	c.preview=new("Control"):Control(ui.anchor,{16,28,w-32,92});function c.preview:Draw() local x,y=self:GetPos();visual.floor(x,y,self.width,self.height);visual.chip(x,y,self.width,self.height,sample,{action="Show",styles=styles()}) end
	c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,h-42,220,28},"Use sound and effects",function() onKeep(styles(true));main:ClosePopup() end)
	c.test=new("ButtonControl"):ButtonControl(ui.anchor,{252,h-42,220,28},"Preview reference alert",function() local _,message=require("Modules.LootFilterAudio").play(styles());main:OpenMessagePopup("Reference alert",message) end)
	c.close=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-42,140,28},"Cancel",function() main:ClosePopup() end)
	ui.style(c,{keep=true});visual.layers(c,{preview=true});main:OpenPopup(w,h,"Sound, minimap icon and beam",c,nil,nil,"close");return c
end
return M
