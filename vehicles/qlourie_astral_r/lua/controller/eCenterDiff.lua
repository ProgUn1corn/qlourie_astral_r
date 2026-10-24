-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
M.type = "auxilliary"
M.relevantDevice = "transfercase"

--math
local abs = math.abs
local min = math.min
local max = math.max
local clamp = math.clamp

local transfercase = nil
local transfercaseName
local transferType
local preload

--common values
local minLockCoef
local lockRange
local hbRelease
local newPreload
local rearBias
local clutchRatioSmoother = newTemporalSmoothingNonLinear(24, 16)

--active values
local activeBasePreload
local preloadMultiplier
local throttle
local brake
local steer
local speed
local steeringLockCut
local speedMapFactor
local throttleTravel
local throttleRatio
local throttleStart
local brakeTravel
local brakeRatio
local brakeStart
local lbThreshold --left foot
local lbThrottleGain --left foot
local lbBrakeGain --left foot
local coastStart
local modeBlendTime
local mapNames = {"coast", "throttle", "brake"}
local mapWeights = {coast = 0, throttle = 0, brake = 0}
local mapBlendFrom = {coast = 0, throttle = 0, brake = 0}
local mapTarget
local mapBlendElapsed = 0

--passive values
local maxLockCoef

--PEAL values

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local function steerLock(steer, speed)
    local normalSteer = abs(steer) ^ 0.74
    local clampSpeed = clamp(speed, 0, 140)
    local contributionSteer = clamp(lockRange * normalSteer * (1 - steeringLockCut), 0, 1)
    local speedFactor = clamp(1 - 0.9 * (clampSpeed / 140) * speedMapFactor, 0.1, 1)
    return contributionSteer * speedFactor
end

local function throttleLock(throttle, throttleStart, throttleRatio, xLockCoef)
    local throttleNormalized = clamp((throttle - throttleStart) / (throttleRatio - throttleStart), 0, 1)
    local throttleCurve = throttleNormalized ^ 1.59
    local yLock = clamp(lockRange * throttleCurve + minLockCoef - xLockCoef, 0, 1)
    return yLock
end

local function brakeLock(brake, brakeStart, brakeRatio, xLockCoef)
    local brakeNormalized = clamp((brake - brakeStart) / (brakeRatio - brakeStart), 0, 1)
    local brakeCurve = brakeNormalized ^ 0.67
    local yLock = clamp(lockRange * brakeCurve + minLockCoef - xLockCoef, 0, 1)
    return yLock
end

local function applyLeftFoot(gain, preloadAdj, lbInput, lbGain)
	if throttle > coastStart and brake > coastStart then
		local lbInputNorm = clamp((lbInput - lbThreshold) / (1 - lbThreshold), 0, 1)
		gain = gain - lbInputNorm ^ 1.3 * lbGain * 0.4
		preloadAdj = preloadAdj - lbInputNorm ^ 0.8 * preloadAdj * lbGain
	end
	return clamp(gain, 0, 1), clamp(preloadAdj, 0, preload)
end

local function updateMapWeights(activeMap, dt)
	if not mapTarget or modeBlendTime <= 0 then
		mapTarget = activeMap
		mapBlendElapsed = modeBlendTime
		for _, name in ipairs(mapNames) do
			mapWeights[name] = name == activeMap and 1 or 0
			mapBlendFrom[name] = mapWeights[name]
		end
		return
	end

	if activeMap ~= mapTarget then
		mapTarget = activeMap
		mapBlendElapsed = 0
		for _, name in ipairs(mapNames) do
			mapBlendFrom[name] = mapWeights[name]
		end
	end

	if mapBlendElapsed < modeBlendTime then
		mapBlendElapsed = min(mapBlendElapsed + dt, modeBlendTime)
		local t = mapBlendElapsed / modeBlendTime
		local blend = t * t * (3 - 2 * t)
		for _, name in ipairs(mapNames) do
			local target = name == mapTarget and 1 or 0
			mapWeights[name] = lerp(mapBlendFrom[name], target, blend)
		end
	end
end

local function updateFixedStep(dt)
	--print("THICC")
	--common detecion variables
	local handbrake
	handbrake = electrics.values['parkingbrake_input'] or 0

	if transfercase and transferType == "active" then
		--get input value
		throttle = electrics.values['throttle_input'] or 0
		brake = electrics.values['brake_input'] or 0
		steer = electrics.values['steering_input'] or 0
		speed = electrics.values.wheelspeed * 3.6 or 0

		--calculate steering lock map using steering and speed
		local xLockCoef = steerLock(steer, speed)
		--print(xLockCoef)

		local activeMap
		if throttle <= coastStart and brake <= coastStart then
			activeMap = "coast"
		elseif throttle > brake then
			activeMap = "throttle"
		else
			activeMap = "brake"
		end

		local smallPreload = activeBasePreload * (1 - xLockCoef)
		local coastGain = minLockCoef
		local throttleGain = throttleLock(throttle, throttleStart, throttleRatio, xLockCoef)
		local brakeGain = brakeLock(brake, brakeStart, brakeRatio, xLockCoef)
		local throttlePreload, brakePreload

		-- Apply each candidate's left-foot modifier before blending modes.
		throttleGain, throttlePreload = applyLeftFoot(throttleGain, smallPreload, brake, lbBrakeGain)
		brakeGain, brakePreload = applyLeftFoot(brakeGain, preload * brakeGain, throttle, lbThrottleGain)
		updateMapWeights(activeMap, dt)

		local newLockCoef = mapWeights.coast * coastGain + mapWeights.throttle * throttleGain + mapWeights.brake * brakeGain
		local newPreload = mapWeights.coast * smallPreload + mapWeights.throttle * throttlePreload + mapWeights.brake * brakePreload
		newLockCoef = clamp(newLockCoef, 0, 1)
		newPreload = clamp(newPreload, 0, preload)

		transfercase.speedLimitCoef = 0 -- WHY THIS IS NOT 0 BY DEFAULT?
		local clutchTarget = (handbrake >= hbRelease) and 0 or 1
		local clutchRatio = clutchRatioSmoother:get(clutchTarget, dt)
		clutchRatio = clamp(clutchRatio, 0, 1)

		transfercase.lsdLockCoef = newLockCoef * 0.499 * clutchRatio
		transfercase.lsdRevLockCoef = transfercase.lsdLockCoef
		transfercase.diffTorqueSplitA = lerp(0, rearBias, clutchRatio)
		transfercase.diffTorqueSplitB = lerp(1, 1 - rearBias, clutchRatio)
		transfercase.lsdPreload = newPreload * clutchRatio
		--print(transfercase.lsdLockCoef)

	elseif transfercase and transferType == "passive" then
		transfercase.speedLimitCoef = 0 -- WHY THIS IS NOT 0 BY DEFAULT?
		local clutchTarget = (handbrake >= hbRelease) and 0 or 1
		local clutchRatio = clutchRatioSmoother:get(clutchTarget, dt)
		local clutchOverride = clamp(1 - clutchRatio ^ 1.2, 0, 1)

		local clutchInput = electrics.values['clutch_input'] or 0
		local isClutchManual = clutchInput > 0.01
		if not isClutchManual and clutchOverride >= 0.01 then
			electrics.values.clutchOverride = clutchOverride
		else
			electrics.values.clutchOverride = nil
		end

		transfercase.lsdLockCoef = maxLockCoef * clutchRatio
		transfercase.lsdRevLockCoef = minLockCoef * clutchRatio
		transfercase.diffTorqueSplitA = lerp(0, rearBias, clutchRatio)
		transfercase.diffTorqueSplitB = lerp(1, 1 - rearBias, clutchRatio)
		transfercase.lsdPreload = preload * clutchRatio
		--print(electrics.values.clutch)

	elseif transfercase and transferType == "peal" then
		local clutchTarget = (handbrake >= hbRelease) and 0 or 1
		local clutchRatio = clutchRatioSmoother:get(clutchTarget, dt)
		clutchRatio = clamp(clutchRatio, 0, 1)
		transfercase.clutchRatio = clutchRatio
		--print(transfercase.clutchRatio)
	end
end

local function reset()
	mapTarget = nil
	mapBlendElapsed = 0
end

local function init(jbeamData)
	--print("TWICE?")
	transfercaseName = jbeamData.transfercaseName
	transfercase = powertrain.getDevice(transfercaseName) or nil
	transferType = jbeamData.transferType or 0

	reset()

	--get tuning data for active
	if transfercase and transferType == "active" then
		minLockCoef = jbeamData.lockMap.minLockCoef or 0.1
		lockRange = 1 - minLockCoef
		steeringLockCut = jbeamData.lockMap.steeringLockCut or 0
		speedMapFactor = jbeamData.lockMap.speedMapFactor or 0.54
		throttleStart = jbeamData.lockMap.throttleStart or 0.3
		throttleTravel = jbeamData.lockMap.throttleTravel or (6 / 7)
		throttleRatio = throttleStart + (1 - throttleStart) * throttleTravel
		brakeStart = jbeamData.lockMap.brakeStart or 0.15
		brakeTravel = jbeamData.lockMap.brakeTravel or (12 / 17)
		brakeRatio = brakeStart + (1 - brakeStart) * brakeTravel
		lbThreshold = jbeamData.lockMap.lbThreshold or 0.10
		lbThrottleGain = jbeamData.lockMap.lbThrottleGain or 1
		lbBrakeGain = jbeamData.lockMap.lbBrakeGain or 1
		coastStart = jbeamData.lockMap.coastStart or 0.05
		rearBias = jbeamData.lockMap.rearBias or 0.5
		hbRelease = jbeamData.lockMap.hbRelease or 0.65
		activeBasePreload = jbeamData.lockMap.activeBasePreload or 80
		preloadMultiplier = jbeamData.lockMap.preloadMultiplier or 40
		preload = activeBasePreload * preloadMultiplier
		modeBlendTime = jbeamData.lockMap.modeBlendTime or 0.03
	end

	--get tuning data for passive
	if transfercase and transferType == "passive" then
		maxLockCoef = jbeamData.lockMap.maxLockCoef or 0.25
		minLockCoef = jbeamData.lockMap.minLockCoef or 0.25
		preload = jbeamData.lockMap.preload or 0
		rearBias = jbeamData.lockMap.rearBias or 0.5
		hbRelease = jbeamData.lockMap.hbRelease or 0.65
	end

	--get tuning data for PEAL
	if transfercase and transferType == "peal" then
		hbRelease = jbeamData.hbRelease or 0.65
	end
end

--local function setParameters(parameters)
	--print(parameters.tMap)
	--if parameters.minLockCoef then
		--minLockCoef = parameters.minLockCoef
	--else
		--tMap = 2
	--end
--end

M.init = init
M.reset = reset
M.setParameters = setParameters
M.updateFixedStep = updateFixedStep

return M