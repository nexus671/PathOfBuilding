-- Run from src: luajit ../tools/check_snapshot_equivalence.lua path/to/build.xml
-- Loads an isolated build and never writes the supplied file or installed PoB.
local fixture=assert(arg[1],"Provide a build XML file")
arg={};dofile("HeadlessWrapper.lua");main.disableDevAutoSave=true
local file=assert(io.open(fixture,"rb"));local xml=file:read("*a");file:close()
loadBuildFromXML(xml,"Read-only snapshot proof")
assert(not main.popups[1],"Fixture requires an interactive conversion")
local before={};for _,item in pairs(build.itemsTab.items) do before[item]={raw=item.raw,mods=item.modList,lines=item.explicitModLines} end
local bridge=require("Modules.DesktopBuildBridge");local start=os.clock();local frozen=bridge.freeze(build);local snapshotMs=(os.clock()-start)*1000
for item,saved in pairs(before) do assert(item.raw==saved.raw and item.modList==saved.mods and item.explicitModLines==saved.lines,"Snapshot mutated active item") end
start=os.clock();local revision=bridge.revision(build);local revisionMs=(os.clock()-start)*1000;assert(revision==frozen.revision)
local legacyStart=os.clock()
local raw=build:SaveDB("Legacy serialization proof");assert(raw==frozen.xml,"Serialized XML differs")
local root=assert(common.xml.ParseXML(raw))[1]
for i=#root,1,-1 do local node=root[i];if type(node)=="table" then
 if node.elem=="TreeView" then table.remove(root,i) elseif node.elem=="Build" then node.attrib.viewMode=nil
  for j=#node,1,-1 do local child=node[j];if type(child)=="table" and (child.elem=="PlayerStat" or child.elem=="MinionStat" or child.elem=="FullDPSSkill") then table.remove(node,j) end end
 end
end end
assert(frozen.revision==require("sha1")((build.buildName or "")..assert(common.xml.ComposeXML(root))),"Legacy revision differs")
print("SNAPSHOT_EQUIVALENCE "..require("dkjson").encode({xmlEquivalent=true,legacyRevisionEquivalent=true,activeItemsUnchanged=true,snapshotMs=snapshotMs,revisionMs=revisionMs,legacyMs=(os.clock()-legacyStart)*1000,bytes=#raw}))
