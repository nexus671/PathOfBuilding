-- Portable data only. Native build XML carries kept plans and checkpoints.
local json=require("dkjson")
local sha1=require("sha1")
local M={limit=16*1024*1024}
function M.contents(xml)
	local parsed=assert(common.xml.ParseXML(xml));local root=assert(parsed[1]);assert(root.elem=="PathOfBuilding","Bundle needs native Path of Building XML")
	local result={crafts=0,checkpoints=0,inventory=0,atlas=0,stages=0,wishlist=0,milestones=0,filters=0,sections={}}
	for _,node in ipairs(root) do if type(node)=="table" then
		result.sections[#result.sections+1]=node.elem
		if node.elem=="CraftingProjects" or node.elem=="AtlasPlans" or node.elem=="BuildJourney" or node.elem=="LootFilters" then
			local data=json.decode(table.concat(node));if type(data)=="table" then
				if node.elem=="CraftingProjects" then for _,p in ipairs(data.projects or {}) do result.crafts=result.crafts+1;result.inventory=result.inventory+#(p.inventory or {});if p.run then result.checkpoints=result.checkpoints+1 end end
				elseif node.elem=="AtlasPlans" then result.atlas=#(data.plans or {})
				elseif node.elem=="LootFilters" then result.filters=#(data.profiles or {})
				else for _,key in ipairs({"stages","wishlist","milestones"}) do result[key]=#(data[key] or {}) end end
			end
		end
	end end
	return result
end
function M.export(build)
	local xml=require("Modules.DesktopBuildBridge").serialize(build)
	local bundle={kind="PathOfBuilding-AI-Edition",schemaVersion=1,createdAt=os.time(),sourceVersion=launch.versionNumber,buildName=(build.buildName or "Imported planning bundle"):sub(1,120),xml=xml,checksum=sha1(xml)}
	local raw=json.encode(bundle);assert(#raw<=M.limit,"Planning bundle exceeds 16 MiB");return raw,M.contents(xml)
end
function M.import(raw)
	assert(type(raw)=="string" and #raw<=M.limit,"Planning bundle exceeds 16 MiB")
	local bundle=assert(json.decode(raw),"Invalid planning bundle JSON")
	assert(type(bundle)=="table" and bundle.kind=="PathOfBuilding-AI-Edition" and bundle.schemaVersion==1,"Unsupported planning bundle")
	assert(type(bundle.xml)=="string" and type(bundle.checksum)=="string" and sha1(bundle.xml)==bundle.checksum,"Bundle checksum does not match")
	assert(type(bundle.buildName)=="string" and #bundle.buildName<=120 and bundle.buildName:match("%S") and not bundle.buildName:find("[%c]"),"Invalid bundle build name")
	bundle.contents=M.contents(bundle.xml);return bundle
end
function M.lines(contents)
	return {string.format("%d crafting guides | %d working checkpoints | %d saved items | %d Atlas plans",contents.crafts,contents.checkpoints,contents.inventory or 0,contents.atlas),string.format("%d milestones | %d gear goals | %d leveling stages",contents.milestones,contents.wishlist,contents.stages),string.format("%d loot-filter profiles | native character, items, skills, passives, configuration and notes.",contents.filters or 0),"Only kept plans and checkpoints travel. Keep working drafts before exporting.","Prices, crafting odds and external references retain their recorded dates and assumptions. They are not refreshed on import."}
end
return M
