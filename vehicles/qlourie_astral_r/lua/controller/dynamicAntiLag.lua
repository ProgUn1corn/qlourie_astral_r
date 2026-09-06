-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- modified from vanilla anti lag but not as simple as old style wrc where turbo is full blown all the time
local M = {}
M.type = "auxiliary"

local max = math.max

local rpmToAV = 0.10471971768
local avToRPM = 9.5493

local states = {off = "off", idle = "idle", armed = "armed"}
local state

local ALS
local ALSDesc = {
	[1] = "Soft",
	[2] = "Medium",
	[3] = "Aggressive",
	[4] = "Boost OFF",
}

local controlledEngine
local controlledTurbocharger
local engineAftefireCoef
local engineAftefireTime
local engineAftefireInstant

local maxTurboTargetAV
local minTurboTargetAV
local maxActiveEngineAV
local minActiveEngineAV
local minActiveWheelSpeed
local maxActiveThrottleInput
local minActiveBrakeInput

local reserved1
local reserved2

local turboAVPIDController

local function setAntilagState(newState)
	state = newState
end

local function setAntilagLevel(rpm, t ,b)
	minActiveEngineAV = rpm * rpmToAV
	maxActiveThrottleInput = t
	minActiveBrakeInput = b
end

local function displayState()
	guihooks.message(string.format("ALS: %s", ALSDesc[ALS]), 2, "vehicle.ALS.map")
end

local function updateGFX(dt)
	local throttle = electrics.values.throttle
	local engineAV = controlledEngine.outputAV1
	local antilagCoef = 0
	--print(state)

	-- IDLE STATE: System is ready but waiting for activation conditions
	if state == states.idle then
		-- ARMED STATE: System is active and can engage antilag
		-- Check if throttle and engine speed are high enough to arm the system
		if throttle >= 0.1	then
			state = states.armed
		end
	elseif state == states.armed then
		-- Check all conditions required for antilag operation
		local wheelSpeedHighEnough = electrics.values.wheelspeed >= minActiveWheelSpeed
		local throttleLowEnough = electrics.values.throttle <= maxActiveThrottleInput
		local brakeHighEnough = electrics.values.brake >= minActiveBrakeInput
		local engineAVHighEnough = controlledEngine.outputAV1 >= minActiveEngineAV
		local coast = electrics.values.throttle == 0 and electrics.values.brake == 0

		-- If all conditions are met, engage antilag
		if wheelSpeedHighEnough and (throttleLowEnough or brakeHighEnough) and engineAVHighEnough and not coast then
			-- Calculate how much antilag is needed based on turbo speed difference
			local currentTurboAV = controlledTurbocharger.turboAV
			local engineRatio = (engineAV - minActiveEngineAV) / (maxActiveEngineAV - minActiveEngineAV)
			local turboTargetDynamicAV = minTurboTargetAV + (maxTurboTargetAV - minTurboTargetAV) * engineRatio
			antilagCoef = turboAVPIDController:get(currentTurboAV, turboTargetDynamicAV, dt)
			controlledEngine.sustainedAfterFireCoef = engineAftefireCoef * antilagCoef
			--controlledEngine.instantAfterFireCoef = engineAftefireInstant * antilagCoef
			--print(turboTargetDynamicAV*avToRPM)
		elseif not throttleLowEnough or brakeHighEnough or coast then
			antilagCoef = 0
			controlledEngine.sustainedAfterFireCoef = engineAftefireCoef
			controlledEngine.sustainedAfterFireTime = engineAftefireTime*999
			controlledEngine.instantAfterFireCoef = engineAftefireInstant
		end
		--print("antilagCoef: " .. antilagCoef)
	elseif state == states.off then
			antilagCoef = 0
			controlledEngine.sustainedAfterFireCoef = 0
			controlledEngine.sustainedAfterFireTime = 0
			controlledEngine.instantAfterFireCoef = 0
	end

	electrics.values.alsActive = antilagCoef > 0
	electrics.values.alsState = state

	-- Apply the calculated antilag coefficient to the engine
	controlledEngine:setAntilagCoef(antilagCoef)
end

local function reset(jbeamData)
	state = states.idle
	turboAVPIDController:reset()
	electrics.values.alsActive = false
	electrics.values.alsState = state
end

local function init(jbeamData)
	local engineName = jbeamData.controlledEngine or "mainEngine"
	controlledEngine = powertrain.getDevice(engineName)
	engineAftefireCoef = controlledEngine.sustainedAfterFireCoef
	engineAftefireTime = controlledEngine.sustainedAfterFireTime
	engineAftefireInstant = controlledEngine.instantAfterFireCoef

	maxTurboTargetAV = (jbeamData.maxTurboTargetRPM or 120000) * rpmToAV --Max turbo speed ECU can spin up to
	minTurboTargetAV = (jbeamData.minTurboTargetRPM or 50000) * rpmToAV --Max turbo speed ECU can spin up to
	minActiveWheelSpeed = jbeamData.minActiveWheelSpeed or 1 --Vehicle must be moving faster than this [m/s]
	maxActiveEngineAV = (jbeamData.maxActiveEngineRPM or 6000) * rpmToAV --Engine must be above this speed for antilag

	setAntilagLevel(jbeamData.minActiveEngineRPM or 2500, jbeamData.maxActiveThrottleInput or 0.15, jbeamData.minActiveBrakeInput or 0.8)
	--minActiveEngineAV = (jbeamData.minActiveEngineRPM or 2000) * rpmToAV --Engine must be above this speed for antilag
	--maxActiveThrottleInput = jbeamData.maxActiveThrottleInput or 0.2 --Antilag only works below this throttle [0-1]
	--minActiveBrakeInput = jbeamData.minActiveBrakeInput or 0.2 --Brake must be pressed harder than this [0-1]

	controlledTurbocharger = controlledEngine.turbocharger

	turboAVPIDController = newPIDParallel(0.01, 0, 0, 0, 1, -10, 10)

	state = states.idle
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
	--print(parameters.minActiveEngineRPM)
	if parameters.isEnabled == true then
		state = states.idle
		if parameters.minActiveEngineRPM or parameters.maxActiveThrottleInput or parameters.minActiveBrakeInput then
			setAntilagLevel(parameters.minActiveEngineRPM or 2500, parameters.maxActiveThrottleInput or 0.15, parameters.minActiveBrakeInput or 0.8)
		end
	elseif parameters.isEnabled == false then
		state = states.off
	end
	ALS = parameters.ALS
	displayState()
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.setAntilagState = setAntilagState
M.setAntilagLevel = setAntilagLevel
M.serialize = serialize
M.deserialize = deserialize
M.setParameters = setParameters
M.displayState = displayState

return M
