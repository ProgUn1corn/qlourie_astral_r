-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local tMap
local tMapDesc = {
	[1] = "Progressive",
	[2] = "Subtle Linear",
	[3] = "Aggressive",
}
local throttle
local newThrottle

local reserved1
local reserved2

--throttle map slope
local a = nil	--a is alpha to linear
local k = nil	--k is slope of log curve

local function calculateThrottleMap(x, y, z)
	return (1 - y) * ((math.log(1 + z * x)) / (math.log(1 + z))) + (y * x)
end

local function displayState()
	guihooks.message(string.format("Throttle Map: %s (%s)", tMap, tMapDesc[tMap]), 2, "vehicle.throttleMap.map")
end

local function updateGFX(dt)
	if not electrics.values.cruiseControlActive or electrics.values.cruiseControlActive == 0 then
		--get input value
		throttle = electrics.values['throttle_input'] or 0

		--progressive map (used in really precise and road situations)
		if tMap == 1 then
			a =	0.15
			k = -0.88
			newThrottle = calculateThrottleMap(throttle, a, k)
		end

		-- mostly linear with a TINY bit of progressive map
		if tMap == 2 then
			a =	0.69 --nice
			k = -0.28
			newThrottle = calculateThrottleMap(throttle, a, k)
		end

		--aggressive map
		if tMap == 3 then
			a = 0.59
			k = 9.8
			newThrottle = calculateThrottleMap(throttle, a, k)
		end

		--apply throttle map
		electrics.values.throttle = newThrottle
		--print(tMap)
	end
end

local function reset()
end

local function init(jbeamData)
	--get map number
	tMap = (jbeamData.tMap) or 2
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
	--print(parameters.tMap)
	if parameters.tMap then
		tMap = parameters.tMap
		displayState()
	else
		tMap = 2
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