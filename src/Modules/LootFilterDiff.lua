-- Bounded patience comparison for review, not a claim of a minimal edit script.
local M={maxLines=100000}
local function lines(raw)
	assert(type(raw)=="string" and #raw<=2*1024*1024,"Filter text exceeds the review size guard")
	local result={};if raw=="" then return result end
	for line in (raw:gsub("\r\n","\n").."\n"):gmatch("([^\n]*)\n") do result[#result+1]=line;assert(#result<=M.maxLines+1,"Detailed review supports up to 100,000 lines; copy the full source instead") end
	if raw:sub(-1)=="\n" then result[#result]=nil end;return result
end
function M.compare(before,after)
	local a,b=lines(before),lines(after);local rows={};local budget=(#a+#b)*12+256;local grouped=false
	local function emit(kind,i,j) rows[#rows+1]={kind=kind,oldLine=i,newLine=j,text=kind=="+" and b[j] or a[i]} end
	local function replaced(al,ah,bl,bh,limited)
		grouped=grouped or limited or ah-al+bh-bl>14;for i=al,ah do emit("-",i) end;for j=bl,bh do emit("+",nil,j) end
	end
	local walk
	walk=function(al,ah,bl,bh,depth)
		while al<=ah and bl<=bh and a[al]==b[bl] do emit(" ",al,bl);al=al+1;bl=bl+1 end
		local tail=0;while al<=ah and bl<=bh and a[ah]==b[bh] do tail=tail+1;ah=ah-1;bh=bh-1 end
		if al>ah then for j=bl,bh do emit("+",nil,j) end
		elseif bl>bh then for i=al,ah do emit("-",i) end
		elseif budget<0 or depth>=64 then replaced(al,ah,bl,bh,true)
		else
			budget=budget-(ah-al+1)-(bh-bl+1)
			local ac,bc,bp={},{},{}
			for i=al,ah do ac[a[i]]=(ac[a[i]] or 0)+1 end
			for j=bl,bh do bc[b[j]]=(bc[b[j]] or 0)+1;bp[b[j]]=j end
			local candidates,tails={},{}
			for i=al,ah do if ac[a[i]]==1 and bc[a[i]]==1 then
				local value=bp[a[i]];local lo,hi=1,#tails
				while lo<=hi do local mid=math.floor((lo+hi)/2);if candidates[tails[mid]].b<value then lo=mid+1 else hi=mid-1 end end
				candidates[#candidates+1]={a=i,b=value,previous=tails[lo-1]};tails[lo]=#candidates
			end end
			if #tails==0 then replaced(al,ah,bl,bh)
			else
				local anchors={};local index=tails[#tails];while index do anchors[#anchors+1]=candidates[index];index=candidates[index].previous end
				for i=#anchors,1,-1 do local anchor=anchors[i];walk(al,anchor.a-1,bl,anchor.b-1,depth+1);emit(" ",anchor.a,anchor.b);al=anchor.a+1;bl=anchor.b+1 end
				walk(al,ah,bl,bh,depth+1)
			end
		end
		for i=1,tail do emit(" ",ah+i,bh+i) end
	end
	walk(1,#a,1,#b,0)
	local added,removed=0,0;for _,row in ipairs(rows) do if row.kind=="+" then added=added+1 elseif row.kind=="-" then removed=removed+1 end end
	return {rows=rows,added=added,removed=removed,grouped=grouped,equal=before==after,beforeLines=#a,afterLines=#b,
		beforeFinalNewline=before:sub(-1)=="\n",afterFinalNewline=after:sub(-1)=="\n",before=before,after=after}
end
function M.visible(diff,context,query)
	context=context or 3;query=(query or ""):lower();local ranges={}
	for i,row in ipairs(diff.rows) do if row.kind~=" " then
		local lo,hi=math.max(1,i-context),math.min(#diff.rows,i+context);local last=ranges[#ranges]
		if last and lo<=last[2]+1 then last[2]=math.max(last[2],hi) else ranges[#ranges+1]={lo,hi} end
	end end
	local result={};for _,range in ipairs(ranges) do
		local shown=false;for i=range[1],range[2] do local row=diff.rows[i];if row.text:lower():find(query,1,true) then
			if not shown then result[#result+1]={heading=true,text="@@ Review rows "..range[1].."-"..range[2].." @@"};shown=true end
			result[#result+1]=row
		end end
	end;return result
end
function M.report(diff)
	local result={"--- Before (line endings normalized for review)","+++ After",diff.added.." added lines; "..diff.removed.." removed lines",
		"Final newline before: "..tostring(diff.beforeFinalNewline).."; after: "..tostring(diff.afterFinalNewline)}
	if diff.grouped then result[#result+1]="Large or repeated changes are grouped; this is not a minimal patch." end
	if diff.added+diff.removed==0 and not diff.equal then result[#result+1]="Only line-ending or final-newline differences." end
	for _,row in ipairs(M.visible(diff)) do result[#result+1]=(row.heading and "" or row.kind)..row.text end;return table.concat(result,"\n")
end
return M
