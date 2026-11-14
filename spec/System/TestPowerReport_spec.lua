describe("PowerReportListControl", function()
	local PowerReportListControl

	before_each(function()
		LoadModule("Classes/PowerReportListControl")
		PowerReportListControl = common.classes.PowerReportListControl
	end)

	local function relist(originalList, showClusters, allocated)
		local control = {
			originalList = originalList,
			showClusters = showClusters or false,
			allocated = allocated or false,
		}
		PowerReportListControl.ReList(control)
		return control.list
	end

	it("Show Unallocated excludes allocated nodes", function()
		local list = relist({
			{ name = "allocated", power = 10, pathDist = 1, allocated = true },
			{ name = "unallocated", power = 5, pathDist = 1, allocated = false },
		}, false, false)

		assert.are.equal(1, #list)
		assert.are.equal("unallocated", list[1].name)
	end)

	it("Show Allocated includes allocated nodes", function()
		local list = relist({
			{ name = "allocated", power = -10, pathDist = 1, allocated = true },
			{ name = "unallocated", power = 5, pathDist = 1, allocated = false },
		}, false, true)

		assert.are.equal(1, #list)
		assert.are.equal("allocated", list[1].name)
	end)
	it("shows and sorts unallocated losses when requested", function()
		local control = {
			originalList = {
				{ name = "gain", power = 5 },
				{ name = "loss", power = -3 },
				{ name = "unchanged", power = 0 },
				{ name = "allocated", power = -8, allocated = true },
			},
			includeLosses = true,
			reportReady = true,
		}
		PowerReportListControl.ReList(control)
		PowerReportListControl.ReSort(control, 3)
		assert.equal(2, #control.list)
		assert.equal("gain", control.list[1].name)
		assert.equal("loss", control.list[2].name)
		control.includeLosses = false
		PowerReportListControl.ReList(control)
		assert.equal(1, #control.list)
		control.originalList = { { name = "unchanged", power = 0 } }
		PowerReportListControl.ReList(control)
		assert.matches("No gains", control.defaultText)
		control.includeLosses = true
		PowerReportListControl.ReList(control)
		assert.matches("No non%-zero", control.defaultText)
	end)
end)
