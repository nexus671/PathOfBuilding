-- Saved working state, distinct from a recipe and from recorded real spending.
local simulator=require("Modules.CraftingSimulator")
local M={}
function M.validate(raw,run)
	assert(type(run)=="table" and run.schemaVersion==1,"Unsupported crafting checkpoint")
	local models={}
	local function state(value)
		assert(type(value)=="table","Missing checkpoint item")
		local base=value.baseItem or raw;local model=models[base]
		if not model then model=simulator.model(base);models[base]=model end
		-- Emulation may have created fractures since the original base was imported.
		model.initial.affixes=value.affixes
		local result=simulator.validateState(model,value)
		assert(simulator.toItem(model,result).base,"Invalid checkpoint item")
		return result
	end
	local result={schemaVersion=1,state=state(run.state),initial=state(run.initial),history={},actions={},configured={},settings={},sequence=run.sequence,targets=run.targets or {},requirements=run.requirements,requiredGroups=run.requiredGroups,page=run.page or "Emulate item",method=run.method or "alchemy",seed=run.seed or "104729"}
	assert(type(result.sequence)=="number" and result.sequence>=0 and result.sequence<=1e9 and result.sequence==math.floor(result.sequence),"Invalid craft sequence")
	for _,key in ipairs({"page","method","seed"}) do assert(type(result[key])=="string" and #result[key]<=80,"Invalid checkpoint setting") end
	for _,key in ipairs({"trials","budget","price","currency","baseCost"}) do local v=run.settings and run.settings[key];if v then assert(type(v)=="string" and #v<=80,"Invalid checkpoint setting");result.settings[key]=v end end
	assert(type(run.history)=="table" and type(run.actions)=="table","Invalid checkpoint history")
	for _,s in ipairs(run.history) do result.history[#result.history+1]=state(s) end
	local targetRecipe=simulator.validateRecipe({steps={{method="alchemy"}},targets=result.targets,requirements=result.requirements or {minAffixes=0},requiredGroups=result.requiredGroups})
	result.targets=targetRecipe.targets
	for _,action in ipairs(run.actions) do
		result.actions[#result.actions+1]=simulator.validateRecipe({steps={action},targets={},requirements={minAffixes=0}}).steps[1]
	end
	assert(#result.history<=#result.actions,"Checkpoint history exceeds action history")
	for method,action in pairs(run.configured or {}) do
		assert(method==action.method,"Invalid configured craft")
		result.configured[method]=simulator.validateRecipe({steps={action},targets={},requirements={minAffixes=0}}).steps[1]
	end
	return result
end
return M
