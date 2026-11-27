-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local tMap
local maps

local function selectMap(index)
	tMap = clamp(math.floor(index), 1, #maps)
end

local function displayState()
	guihooks.message(string.format("Throttle Map: %s (%s)", tMap, maps[tMap].name), 2, "vehicle.throttleMap.map")
end

local function updateGFX()
	local cruiseActive = electrics.values.cruiseControlActive
	if cruiseActive and cruiseActive ~= 0 then return end
	-- Arcade mode swaps the pedals when reversing.
	local throttle = controller.mainController.throttle
	local map = maps[tMap]
	if map.k ~= 0 then
		throttle = (1 - map.a) * (math.log(1 + map.k * throttle) / math.log(1 + map.k)) + map.a * throttle
	end
	electrics.values.throttle = throttle
end

local function init(jbeamData)
	maps = jbeamData.maps
	selectMap(jbeamData.tMap)
end

local function setParameters(parameters)
	if parameters.tMap then
		selectMap(parameters.tMap)
		displayState()
	end
end

M.init = init
M.reset = nop -- Keep the selected map when the vehicle resets.
M.updateGFX = updateGFX
M.setParameters = setParameters
M.displayState = displayState

return M
