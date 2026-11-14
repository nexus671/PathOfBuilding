local prices=require("Modules.CraftingPrices")
local ui=require("Modules.PlanningUI")
local Panel={}
function Panel.Open(model,state,actions,book,currency,onKeep,books,recipeState)
	book=book and prices.normalized(book,model) or {currency=currency or "chaos",source="Manual quotes",quotedAt=os.time(),values={}}
	local entries=prices.entries(model,state,actions,book,recipeState);local buffers={};for key,value in pairs(book.values) do buffers[key]=tostring(value) end
	local controls={};local width=math.min(960,main.screenW-40);local height=math.min(660,main.screenH-60)
	local listWidth=width-320;local side=listWidth+32;local sideWidth=width-side-16
	local selected,visible;local images={}
	local timeFormat="%Y-%m-%d %H:%M:%S";local originalTime=os.date(timeFormat,book.quotedAt)
	ui.label(controls,"currencyLabel",16,24,"Common unit",14)
	controls.currency=new("EditControl"):EditControl(ui.anchor,{16,46,136,26},book.currency,nil,nil,24)
	ui.label(controls,"sourceLabel",168,24,"Quote source",14)
	controls.source=new("EditControl"):EditControl(ui.anchor,{168,46,width-600,26},book.source,nil,nil,240)
	ui.label(controls,"timeLabel",width-296,24,"Quote time (local)",14)
	controls.quotedAt=new("EditControl"):EditControl(ui.anchor,{width-296,46,184,26},originalTime,nil,nil,19)
	controls.now=new("ButtonControl"):ButtonControl(ui.anchor,{width-96,46,80,26},"Now",function() book.quotedAt=os.time();originalTime=os.date(timeFormat,book.quotedAt);controls.quotedAt:SetText(originalTime) end)
	controls.search=new("EditControl"):EditControl(ui.anchor,{16,96,listWidth,28},"","Search",nil,160)
	controls.mode=new("DropDownControl"):DropDownControl(ui.anchor,{side,96,sideWidth,28},{"Recipe resources","Quoted resources","All resources"})
	controls.resources=new("TextListControl"):TextListControl(ui.anchor,{16,140,listWidth,height-252},nil,{})
	ui.description(controls,"selected",side,146,sideWidth,64,{},16)
	ui.label(controls,"priceLabel",side,232,"Price for one unit",14)
	controls.price=new("EditControl"):EditControl(ui.anchor,{side,254,sideWidth,28},"",nil,nil,32)
	ui.description(controls,"hint",side,298,sideWidth,math.min(60,height-500),{"Select a currency to quote its unit price.","0 means free; blank stays unknown.","Recipe resources include possible costs."},14)
	local function stash() if selected then buffers[selected.key]=controls.price.buf:match("^%s*(.-)%s*$") end end
	local function renderRows()
		local rows={}
		for _,entry in ipairs(visible or {}) do
			local value=buffers[entry.key] or "";local number=tonumber(value);local quote=value=="" and "Unknown price" or number and number>=0 and number<=1e12 and value.." "..controls.currency.buf or "Invalid price"
			rows[#rows+1]={height=24,textSize=16,x=48,"^xE2C28C"..ui.fit(entry.name,listWidth-78,16),key=entry.key,path=entry.path,selected=selected and selected.key==entry.key}
			rows[#rows+1]={height=24,textSize=13,x=48,(quote=="Invalid price" and "^xE07070" or "^xA6B3C6")..ui.fit(quote.." | "..entry.kind,listWidth-78,13),key=entry.key,selected=selected and selected.key==entry.key}
		end
		if #rows==0 then rows=ui.rows({"No matching resources. Try All resources or a shorter search."},listWidth-30) end
		controls.resources.list=rows
	end
	local function choose(entry)
		stash();selected=entry;controls.resources.selectedKey=entry and entry.key;controls.price:SetText(entry and buffers[entry.key] or "")
		controls.selected.list=ui.rows({entry and entry.name or "No resource selected"},sideWidth,16)
		controls.hint.list=ui.rows(entry and {entry.kind=="Whole action" and "Price of the complete craft." or "Quote one unit of this resource.","0 means free; blank stays unknown.","Recipe resources include possible costs."} or {"Select a resource from the list.","Recipe resources include possible costs."},sideWidth,14)
		renderRows()
	end
	local function refresh()
		stash();visible={};local kept;local query=controls.search.buf:lower();local mode=controls.mode:GetSelValue()
		for _,entry in ipairs(entries) do
			local quoted=buffers[entry.key] and buffers[entry.key]~=""
			if (mode=="All resources" or mode=="Recipe resources" and (entry.required or quoted) or mode=="Quoted resources" and quoted) and (entry.name.." "..entry.key.." "..entry.kind):lower():find(query,1,true) then
				visible[#visible+1]=entry;if selected and selected.key==entry.key then kept=entry end
			end
		end
		choose(kept or visible[1])
	end
	controls.copy=new("ButtonControl"):ButtonControl(ui.anchor,{width-416,46,104,26},"Copy quotes",function()
		local c={};local choices={};for _,project in ipairs(books or {}) do choices[#choices+1]={label=project.title.." | "..project.priceBook.currency,val=project} end
		ui.description(c,"info",16,24,608,32,{"Replace this editor's staged quotes with another project's saved quotes."},14)
		c.books=new("DropDownControl"):DropDownControl(ui.anchor,{16,68,608,28},choices)
		c.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,128,220,28},"Use selected quotes",function()
			local ok,message=pcall(function()
				local project=assert(c.books:GetSelValueByKey("val"),"Select a saved price book")
				local source=new("Item"):Item(project.startingItem);assert(source.base,"Source project needs a recognized item")
				book=prices.normalized(project.priceBook,{item=source});buffers={};for key,value in pairs(book.values) do buffers[key]=tostring(value) end
				entries=prices.entries(model,state,actions,book,recipeState);selected=nil;controls.price:SetText("")
				controls.currency:SetText(book.currency);controls.source:SetText(book.source);originalTime=os.date(timeFormat,book.quotedAt);controls.quotedAt:SetText(originalTime)
				refresh();main:ClosePopup()
			end)
			if not ok then main:OpenMessagePopup("Copy resource prices",ui.errorText(message)) end
		end)
		c.close=new("ButtonControl"):ButtonControl(ui.anchor,{508,128,116,28},"Cancel",function() main:ClosePopup() end)
		ui.style(c,{keep=true});for _,control in pairs(c) do control.layoutAudit="crafting-price-copy" end
		main:OpenPopup(640,176,"Copy resource quotes",c,nil,nil,"close")
	end)
	controls.copy.enabled=function() return books and #books>0 end
	local draw=controls.resources.Draw
	function controls.resources:Draw(viewport)
		draw(self,viewport);local x,y=self:GetPos();local w,h=self:GetSize();SetViewport(x+2,y+2,w-20,h-4)
		local top=-self.controls.scrollBar.offset
		for _,row in ipairs(self.list) do
			if row.path and top+40>=0 and top<h-4 then
				local image=images[row.path];if not image then image=NewImageHandle();image:Load(row.path);images[row.path]=image end
				SetDrawColor(1,1,1);DrawImage(image,6,top+4,32,32)
			end
			top=top+row.height
		end
		SetViewport()
	end
	ui.selectable(controls.resources,function(row) return row.key end,function(row) for _,entry in ipairs(visible) do if entry.key==row.key then choose(entry);break end end end)
	controls.search.changeFunc=function() controls.resources.controls.scrollBar.offset=0;refresh() end
	controls.mode.selFunc=function() controls.resources.controls.scrollBar.offset=0;refresh() end
	controls.price.changeFunc=function() stash();renderRows() end
	controls.currency.changeFunc=renderRows
	controls.currency.enabled=function() for _,value in pairs(buffers) do if value~="" then return false end end;return true end
	controls.currency.showDisabledValue=true
	controls.currency.tooltipText="Clear existing quotes before changing their common unit. Values are not converted."
	controls.price.enabled=function() return selected~=nil end
	controls.clear=new("ButtonControl"):ButtonControl(ui.anchor,{side,height-194,sideWidth,28},"Clear selected quote",function() controls.price:SetText("",true) end);controls.clear.enabled=controls.price.enabled
	controls.reset=new("ButtonControl"):ButtonControl(ui.anchor,{side,height-152,sideWidth,28},"Reset prices to change unit",function()
		selected=nil;buffers={};controls.price:SetText("");refresh()
	end)
	ui.description(controls,"scope",16,height-96,width-32,34,{"All quotes use the common unit above. No live prices or currency conversion.","Changes stay in this editor until you keep them."},14)
	controls.keep=new("ButtonControl"):ButtonControl(ui.anchor,{16,height-48,220,28},"Keep resource prices",function()
		local ok,message=pcall(function()
			stash();local values={}
			for key,value in pairs(buffers) do if value~="" then
				local name=prices.describe(key,model);local number=tonumber(value)
				assert(number and number==number and number>=0 and number<=1e12,"Invalid unit price for "..name);values[key]=number
			end end
			local quotedAt=book.quotedAt
			if controls.quotedAt.buf~=originalTime then
				local year,month,day,hour,min,sec=controls.quotedAt.buf:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
				assert(year,"Use quote time YYYY-MM-DD HH:MM:SS")
				quotedAt=os.time({year=tonumber(year),month=tonumber(month),day=tonumber(day),hour=tonumber(hour),min=tonumber(min),sec=tonumber(sec)})
				assert(quotedAt and os.date(timeFormat,quotedAt)==controls.quotedAt.buf,"Enter a valid quote time")
			end
			local saved=prices.normalized({currency=controls.currency.buf:match("^%s*(.-)%s*$"),source=controls.source.buf:match("^%s*(.-)%s*$"),quotedAt=quotedAt,values=values},model)
			onKeep(saved);main:ClosePopup()
		end)
		if not ok then main:OpenMessagePopup("Resource prices",ui.errorText(message)) end
	end)
	controls.close=new("ButtonControl"):ButtonControl(ui.anchor,{width-132,height-48,116,28},"Cancel",function() main:ClosePopup() end)
	ui.style(controls,{keep=true});for _,control in pairs(controls) do control.layoutAudit="crafting-prices" end
	refresh();main:OpenPopup(width,height,"Crafting resource prices",controls,nil,nil,"close");return controls
end
return Panel
