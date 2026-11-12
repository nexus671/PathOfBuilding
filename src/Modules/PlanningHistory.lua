-- Session history is bounded by memory use, not by the number of saved projects.
local json=require("dkjson")
local encode=require("Modules.PlanningData").encode
local M={limit=16*1024*1024}
function M.new(value,state)
	local self=state or {undo={},redo={}};self.current=encode(value)
	function self:record(next,label)
		local raw=encode(next);if raw==self.current then return false end
		local now=GetTime();local grouped=label and self.label==label and self.at and now-self.at<750 and #self.redo==0
		if not grouped then self.undo[#self.undo+1]=self.current end
		self.current=raw;self.redo={};self.label=label;self.at=now
		local size=0;for _,v in ipairs(self.undo) do size=size+#v end
		while size>M.limit and #self.undo>1 do size=size-#table.remove(self.undo,1) end
		return true
	end
	function self:step(back)
		local from,to=back and self.undo or self.redo,back and self.redo or self.undo
		assert(#from>0,back and "Nothing to undo" or "Nothing to redo")
		to[#to+1]=self.current;self.current=table.remove(from);self.label=nil;self.at=nil
		return assert(json.decode(self.current))
	end
	function self:snapshot() return {undo=self.undo,redo=self.redo} end
	return self
end
return M
