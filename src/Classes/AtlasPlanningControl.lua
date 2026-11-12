-- Progression and farming inputs belong to the saved Atlas plan.
local ui=require("Modules.PlanningUI")
local atlas=require("Modules.AtlasPlanner")
local M={}
function M.Open(build,plan,keep)
	local draft=copyTable(plan);local c={};local w,h=math.min(920,main.screenW-40),math.min(680,main.screenH-48)
	local function button(key,x,y,width,label,run) c[key]=new("ButtonControl"):ButtonControl(ui.anchor,{x,y,width,28},label,run) end
	c.page=new("DropDownControl"):DropDownControl(ui.anchor,{16,24,220,28},{"Progression","Strategy"})
	ui.tabs(c,c.page,{{"progressionTab","Progression","Progression"},{"strategyTab","Strategy","Strategy requirements"}},16,24,w-32)
	ui.label(c,"stageLabel",16,76,"Stage")
	c.stage=new("DropDownControl"):DropDownControl(ui.anchor,{16,102,240,28},{{label="Starter",val="starter"},{label="Intermediate",val="intermediate"},{label="Final",val="final"}});c.stage:SelByValue(draft.progression and draft.progression.stage or "starter","val")
	ui.label(c,"previousLabel",280,76,"Previous saved Atlas plan")
	local previous={{label="No previous plan",val=""}};for _,p in ipairs(build.savers.AtlasPlans.plans) do if p.id~=plan.id and p.version==plan.version then previous[#previous+1]={label=p.title,val=p.id} end end
	c.previous=new("DropDownControl"):DropDownControl(ui.anchor,{280,102,w-296,28},previous);c.previous:SelByValue(draft.progression and draft.progression.previousId or "","val")
	c.transition=new("TextListControl"):TextListControl(ui.anchor,{16,156,w-32,h-230},nil,{})
	local function refresh()
		local lines={"Keep each stage as its own saved plan. Choose the prior stage to review the respec.","No prior stage selected."}
		for _,p in ipairs(build.savers.AtlasPlans.plans) do if p.id==c.previous:GetSelValueByKey("val") then lines=require("Modules.PlanningPerformance").measure(build,"Atlas respec route",require("Modules.AtlasStrategy").transition,p,draft).lines end end
		c.transition.list=ui.rows(lines,w-56)
	end
	c.previous.selFunc=refresh
	local s=draft.strategy or {};local fields={{"maps","Maps and rolling requirements"},{"scarabs","Scarabs and consumables"},{"requirements","Character / unlock requirements"},{"avoid","Mechanics or map modifiers to avoid"}}
	local col=math.floor((w-48)/2)
	for i,field in ipairs(fields) do local x=16+(i-1)%2*(col+16);local y=78+math.floor((i-1)/2)*144
		ui.label(c,field[1].."Label",x,y,field[2],15);c[field[1]]=new("EditControl"):EditControl(ui.anchor,{x,y+26,col,100},s[field[1]] or "",nil,"^%C\t\n",4000,nil,16)
	end
	ui.label(c,"costLabel",16,378,"Setup estimate / currency / source",15)
	for _,entry in ipairs({{"amount",16,120,s.setupCost and tostring(s.setupCost.amount) or ""},{"currency",148,140,s.setupCost and s.setupCost.currency or "chaos"},{"source",300,w-316,s.setupCost and s.setupCost.source or ""}}) do c[entry[1]]=new("EditControl"):EditControl(ui.anchor,{entry[2],404,entry[3],28},entry[4],nil,nil,240) end
	ui.description(c,"costHint",16,448,w-32,48,{"Costs use your supplied currency and source, dated when edited. They do not reserve or spend Journey resources automatically."},14)
	for _,key in ipairs({"stageLabel","stage","previousLabel","previous","transition"}) do c[key].shown=function() return c.page:GetSelValue()=="Progression" end end
	for _,key in ipairs({"maps","scarabs","requirements","avoid","mapsLabel","scarabsLabel","requirementsLabel","avoidLabel","costLabel","amount","currency","source","costHint"}) do c[key].shown=function() return c.page:GetSelValue()=="Strategy" end end
	button("keep",16,h-48,200,"Use in Atlas draft",function()
		draft.progression={stage=c.stage:GetSelValueByKey("val"),previousId=c.previous:GetSelValueByKey("val")};draft.strategy=copyTable(s)
		for _,field in ipairs(fields) do draft.strategy[field[1]]=c[field[1]].buf end
		if c.amount.buf~="" then local amount=assert(tonumber(c.amount.buf),"Enter a numeric setup cost");local old=s.setupCost;draft.strategy.setupCost={amount=amount,currency=c.currency.buf,source=c.source.buf,quotedAt=old and old.amount==amount and old.currency==c.currency.buf and old.source==c.source.buf and old.quotedAt or os.time()} else draft.strategy.setupCost=nil end
		local validated=atlas.validate(draft);keep(validated);main:ClosePopup()
	end)
	button("close",w-156,h-48,140,"Cancel",function() main:ClosePopup() end)
	refresh();ui.style(c,{keep=true});main:OpenPopup(w,h,"Atlas stages and strategy",c,nil,nil,"close")
end
return M
