-- Recipe graph edges use the simulator's route and recovery semantics.
local M={}
-- Explicit finish is encoded as step count + 1. Move it when appending so it
-- cannot silently become a reference to the new step. Default next routes
-- remain implicit and naturally continue to the appended step.
function M.append(recipe,action)
	assert(type(recipe)=="table" and type(recipe.steps)=="table" and #recipe.steps<20,"Use up to twenty steps")
	assert(type(action)=="table" and type(action.method)=="string","Choose a recipe action")
	local next=copyTable(recipe);local oldFinish=#next.steps+1
	for _,step in ipairs(next.steps) do for _,key in ipairs({"onSuccess","onFailure"}) do
		if step[key]==oldFinish then step[key]=oldFinish+1 end
	end end
	next.steps[oldFinish]=copyTable(action);return next
end
function M.edges(recipe)
	local result={};local finish=#recipe.steps+1
	for i,step in ipairs(recipe.steps) do
		result[#result+1]={source=i,target=step.onSuccess or i+1,kind="success",label="Success"}
		local policy=step.onFailureAction or "route";local target=policy=="restart" and 1 or (policy=="stop" or policy=="salvage") and finish or step.onFailure or i+1
		result[#result+1]={source=i,target=target,kind="failure",label=policy=="route" and "Failure" or policy:gsub("^%l",string.upper)}
	end
	return result
end
function M.set(recipe,index,kind,target)
	assert(type(index)=="number" and index==math.floor(index) and recipe.steps[index],"Choose a recipe step")
	assert(kind=="success" or kind=="failure","Choose a success or failure connector")
	assert(type(target)=="number" and target==math.floor(target) and target>=1 and target<=#recipe.steps+1,"Choose a destination step or Finish")
	local next=copyTable(recipe);next.steps[index][kind=="success" and "onSuccess" or "onFailure"]=target
	if kind=="failure" then next.steps[index].onFailureAction="route" end
	return next
end
return M
