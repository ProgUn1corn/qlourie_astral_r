-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local tMap
local maps
local throttle
local newThrottle

local reserved1
local reserved2

local function calculateThrottleMap(x, a, k)
	if k == 0 then return x end
	return (1 - a) * (math.log(1 + k * x) / math.log(1 + k)) + a * x
end

local function selectMap(index)
	tMap = math.max(1, math.min(#maps, math.floor(index or 2)))
end

local function displayState()
	guihooks.message(string.format("Throttle Map: %s (%s)", tMap, maps[tMap].name or tostring(tMap)), 2, "vehicle.throttleMap.map")
end

local function updateGFX(dt)
	if not electrics.values.cruiseControlActive or electrics.values.cruiseControlActive == 0 then
		--get input value
		throttle = electrics.values['throttle_input'] or 0

		local map = maps[tMap]
		newThrottle = calculateThrottleMap(throttle, map.a, map.k)

		--apply throttle map
		electrics.values.throttle = newThrottle
		--print(tMap)
	end
end

local function reset()
end

local function init(jbeamData)
	maps = jbeamData.maps
	if not maps or #maps == 0 then
		maps = {
			{name = "Progressive", a = 0.15, k = -0.88},
			{name = "Subtle Linear", a = 0.69, k = -0.28},
			{name = "Aggressive", a = 0.59, k = 9.8},
		}
	end
	--get map number
	selectMap(jbeamData.tMap)
	--print(tMap)
end

local function serialize()
	return {
		reserved1 = 0,
		reserved2 = 0
	}
end

local function deserialize(data)
	if data and data.reserved1 and data.reserved2 then
	reserved1 = 0
	end
end

local function setParameters(parameters)
	selectMap(parameters.tMap)
	if parameters.tMap then
		displayState()
	end
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.serialize = serialize
M.deserialize = deserialize
M.setParameters = setParameters
M.displayState = displayState

return M