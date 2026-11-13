describe("Read-only planning snapshots",function()
	local bridge=require("Modules.DesktopBuildBridge")
	before_each(function() newBuild() end)
	local function legacyRevision(raw)
		local root=assert(common.xml.ParseXML(raw))[1]
		for i=#root,1,-1 do local node=root[i]
			if type(node)=="table" then
				if node.elem=="TreeView" then table.remove(root,i)
				elseif node.elem=="Build" then
					node.attrib.viewMode=nil
					for j=#node,1,-1 do local child=node[j];if type(child)=="table" and (child.elem=="PlayerStat" or child.elem=="MinionStat" or child.elem=="FullDPSSkill") then table.remove(node,j) end end
				end
			end
		end
		return require("sha1")((build.buildName or "")..assert(common.xml.ComposeXML(root)))
	end
	it("matches native saves without reparsing or changing active item state",function()
		local raws={
			"Rarity: RARE\nRange Hat\nIron Hat\nItem Level: 86\nImplicits: 0\n{range:0.75}+(10-20) to maximum Life",
			"Rarity: UNIQUE\nVariant Ring\nPrismatic Ring\nVariant: Previous\nVariant: Current\nImplicits: 1\n+(8-10)% to all Elemental Resistances\n{variant:1}+(10-20) to maximum Life\n{variant:2}+(20-30) to maximum Life",
			"Rarity: MAGIC\nPrismatic Tincture\nItem Level: 85\nQuality: 20\nImplicits: 1\n100% increased Elemental Damage with Melee Weapons\n26% reduced Mana Burn rate\n29% increased Melee Weapon Attack Speed",
		}
		local items={}
		for _,raw in ipairs(raws) do local item=new("Item"):Item(raw);build.itemsTab:AddItem(item);items[#items+1]=item end
		items[1].quality=20;items[1].explicitModLines[1].range=1/3;items[2].variant=1;items[2].implicitModLines[1].range=nil
		local before={}
		for _,item in ipairs(items) do before[item]={raw=item.raw,lines=item.explicitModLines,mods=item.modList,range=item.explicitModLines[1].range,parse=item.BuildAndParseRaw};item.BuildAndParseRaw=function() error("Snapshot reparsed an active item") end end
		local ok,snapshot=pcall(bridge.freeze,build)
		for item,state in pairs(before) do item.BuildAndParseRaw=state.parse;assert.are.equal(state.raw,item.raw);assert.are.equal(state.lines,item.explicitModLines);assert.are.equal(state.mods,item.modList);assert.are.equal(state.range,item.explicitModLines[1].range) end
		assert.is_true(ok,tostring(snapshot));assert.are.equal(build:SaveDB("Snapshot equivalence"),snapshot.xml)
		assert.are.equal(legacyRevision(snapshot.xml),snapshot.revision)
	end)
	it("matches XML revision normalization without parsing or composing a full snapshot",function()
		local cases={"", " \t\r\n ","  <tag> & \"quoted\"  ","\nfirst\n second\n", "&amp; &#10; <!-- literal -->"}
		for _,text in ipairs(cases) do
			build.savers.SnapshotProbe={Save=function(_,xml)
				xml.attrib={escaped="<>&\"'"};xml[#xml+1]=text;xml[#xml+1]=" \n next ";xml[#xml+1]={elem="Nested",text,"",{elem="Leaf",text}," tail ",""}
			end}
			local frozen=bridge.freeze(build);assert.are.equal(legacyRevision(frozen.xml),frozen.revision)
			local parse,compose=common.xml.ParseXML,common.xml.ComposeXML;local calls=0
			common.xml.ParseXML=function() error("Revision reparsed its captured XML") end
			common.xml.ComposeXML=function(root) calls=calls+1;return compose(root) end
			local ok,revision=pcall(bridge.revision,build);common.xml.ParseXML,common.xml.ComposeXML=parse,compose
			assert.is_true(ok,tostring(revision));assert.are.equal(frozen.revision,revision);assert.are.equal(1,calls)
		end
	end)
	it("includes live item edits even when cached raw text has not changed",function()
		local item=new("Item"):Item("Rarity: NORMAL\nIron Hat\nItem Level: 86");build.itemsTab:AddItem(item)
		local original=item.raw;local frozen=bridge.freeze(build);item.quality=20
		assert.are.equal(original,item.raw);assert.is_not.equal(frozen.revision,bridge.revision(build));assert.are.equal(original,item.raw)
		assert.is_truthy(bridge.serialize(build):find("Quality: 20",1,true));assert.is_falsy(frozen.xml:find("Quality: 20",1,true))
	end)
	it("restores notes editor state when a later saver fails",function()
		local notes=build.notesTab;local edit=notes.controls.edit;edit:SetText("^xFFFFFFSnapshot & note");notes.showColorCodes=true
		edit.caret=4;edit.sel=2;local buf,caret,selection=edit.buf,edit.caret,edit.sel
		build.savers.SnapshotFailure={Save=function() error("Deliberate snapshot failure") end}
		assert.is_false(pcall(bridge.freeze,build));assert.are.equal(buf,edit.buf);assert.are.equal(caret,edit.caret);assert.are.equal(selection,edit.sel);assert.is_true(notes.showColorCodes)
	end)
end)
