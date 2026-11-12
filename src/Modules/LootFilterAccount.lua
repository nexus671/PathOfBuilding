-- Explicit account actions only. No background writes or tokens in build metadata.
local json=require("dkjson")
local M={busy=false,nextRequest=0}
function M.request(api,method,id,payload,callback)
	assert(method=="GET" or method=="POST","Unsupported filter action")
	assert(not id or type(id)=="string" and #id<=100 and id:match("^[%w_-]+$"),"Invalid account filter ID")
	assert(not M.busy,"Wait for the active account request")
	assert(os.time()>=M.nextRequest,"Wait before requesting account filters again")
	assert(api and api.authToken,"Log in with item-filter access first")
	if method=="POST" then
		assert(type(payload)=="table" and type(payload.filter)=="string" and #payload.filter<=2*1024*1024,"Invalid filter payload")
		assert(payload.realm=="pc" or payload.realm=="xbox" or payload.realm=="sony","Choose a PoE 1 realm")
		assert(type(payload.filter_name)=="string" and #payload.filter_name<=120 and payload.filter_name:match("%S"),"Enter an account filter name")
	end
	M.busy=true
	local function finish(value,err,wait) M.busy=false;M.nextRequest=os.time()+(wait or 1);callback(value,err) end
	api:ValidateAuth(function(valid,err)
		if not valid then finish(nil,err or "Log in with item-filter access first");return end
		local options={header="Authorization: Bearer "..api.authToken.."\r\nContent-Type: application/json"}
		if method=="POST" then options.body=json.encode(payload) end
		launch:DownloadPage("https://api.pathofexile.com/item-filter"..(id and "/"..id or "")..(method=="POST" and "?validate=true" or ""),function(response,errorMessage)
			local status=tonumber(response and response.header and response.header:match("HTTP/[%d%.]+ (%d+)"))
			if status==403 then finish(nil,"Item-filter access was not granted. The registered OAuth client must support account:item_filter; local export remains available.");return end
			if status==429 then local wait=math.max(60,tonumber((response.header or ""):lower():match("retry%-after:%s*(%d+)")) or 60);finish(nil,"Rate limited. Wait at least "..wait.." seconds before retrying.",wait);return end
			if status and status>=400 then finish(nil,"The account server rejected this request (HTTP "..status.."). Check validation and access before retrying.");return end
			if errorMessage then finish(nil,"Account request failed. For a write, check your account before retrying; its outcome may be unknown.");return end
			local decoded=response and type(response.body)=="string" and json.decode(response.body)
			if type(decoded)~="table" then finish(nil,"Invalid account response; check your account before retrying a write.");return end
			if status==202 or decoded.error then finish(decoded,"The server accepted the request but processing/validation is incomplete. Check the account before retrying.");return end
			if method=="POST" and (not decoded.filter or not decoded.filter.validation or decoded.filter.validation.valid~=true) then finish(decoded,"The server did not confirm a valid filter. Check its validation result on your account.");return end
			finish(decoded)
		end,options)
	end)
end
return M
