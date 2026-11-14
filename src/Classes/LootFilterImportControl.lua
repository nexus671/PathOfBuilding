-- Build-owned copies of external filter texts for offline previews and export.
local ui=require("Modules.PlanningUI")
local filters=require("Modules.LootFilters")
local M={}
function M.Open(profile,keep)
	local draft=copyTable(profile);draft.importFiles=draft.importFiles or {};local c={};local selected=0
	local w,h=math.min(860,main.screenW-40),math.min(640,main.screenH-60)
	ui.description(c,"help",16,28,w-32,48,{"Paste each file under the exact Import name. Choose Add / update, then Keep files. Copies are saved with this build; unresolved imports remain explicit."},14)
	c.files=new("DropDownControl"):DropDownControl(ui.anchor,{16,82,w-32,26},{})
	ui.label(c,"nameLabel",16,120,"Import filename",14)
	c.name=new("EditControl"):EditControl(ui.anchor,{16,142,w-32,26},"",nil,nil,240)
	ui.label(c,"textLabel",16,180,"Filter file contents",14)
	c.text=new("EditControl"):EditControl(ui.anchor,{16,202,w-32,h-322},"",nil,"^%C\t\n",filters.limit,nil,14,true)
	local function refresh(index)
		selected=index or 0;local list={{label="Add a file",val=0}}
		for i,file in ipairs(draft.importFiles) do list[#list+1]={label=file.name,val=i} end
		c.files:SetList(list);c.files:SelByValue(selected,"val");local file=draft.importFiles[selected]
		c.name:SetText(file and file.name or "");c.text:SetText(file and file.text or "")
	end
	c.files.selFunc=function(_,entry) refresh(entry.val) end
	local function button(key,x,width,label,callback) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,h-96,width,28},label,function()
		local ok,why=pcall(callback);if not ok then main:OpenMessagePopup("Included filter",require("Modules.PlanningUI").errorText(why)) end
	end) end
	button("saveFile",16,152,"Add / update",function()
		local next=copyTable(draft);local file={name=c.name.buf,text=c.text.buf}
		if selected==0 then next.importFiles[#next.importFiles+1]=file else next.importFiles[selected]=file end
		local checked=filters.validate({schemaVersion=1,activeId=next.id,profiles={next}}).profiles[1]
		draft=checked;refresh(selected==0 and #draft.importFiles or selected)
	end)
	button("removeFile",180,120,"Remove",function() assert(selected>0,"Select a file first");table.remove(draft.importFiles,selected);refresh(0) end)
	c.removeFile.enabled=function() return selected>0 end
	c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,h-48,152,28},"Keep files",function() keep(draft.importFiles);main:ClosePopup() end)
	c.cancel=new("ButtonControl"):ButtonControl(ui.anchor,{w-156,h-48,140,28},"Cancel",function() main:ClosePopup() end)
	refresh(0);ui.style(c,{keep=true});main:OpenPopup(w,h,"Included filter files",c,nil,"name","cancel")
end
return M
