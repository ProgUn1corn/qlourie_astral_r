-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
M.type = "auxilliary"
M.relevantDevice = "transfercase"

--math
local abs = math.abs
local min = math.min

local transfercase = nil
local transfercaseName
local transferType

--common values
local minLockCoef
local lockRange
local hbRelease
local basePreload
local rearBias
local clutchRatioSmoother = newTemporalSmoothingNonLinear(24, 16)

--active values
local preloadMultiplier
local steeringLockCut
local speedMapFactor
local throttleTravel
local throttleStart
local brakeTravel
local brakeStart
local lbThreshold
local lbThrottleGain
local lbBrakeGain
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

local function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local function steerLock(steer, speed)
    local normalSteer = abs(steer) ^ 0.74
    local clampSpeed = clamp(speed, 0, 140)
    local contributionSteer = clamp(lockRange * normalSteer * (1 - steeringLockCut), 0, 1)
    local speedFactor = clamp(1 - 0.9 * (clampSpeed / 140) * speedMapFactor, 0.1, 1)
    return contributionSteer * speedFactor
end

local function pedalLock(input, start, travel, exponent, xLockCoef)
    local span = (1 - start) * travel
    local normalized = clamp((input - start) / span, 0, 1)
    return clamp(minLockCoef + lockRange * normalized ^ exponent - xLockCoef, 0, 1)
end

local function applyLeftFoot(gain, preloadAdj, lbInput, lbGain)
	local lbInputNorm = clamp((lbInput - lbThreshold) / (1 - lbThreshold), 0, 1)
	gain = gain - lbInputNorm ^ 1.3 * lbGain * 0.4
	preloadAdj = preloadAdj - lbInputNorm ^ 0.8 * preloadAdj * lbGain
	return clamp(gain, 0, 1), clamp(preloadAdj, 0, basePreload * preloadMultiplier)
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
	local handbrake = electrics.values['parkingbrake_input'] or 0

	if transfercase and transferType == "active" then
		--get input value
		local throttle = electrics.values['throttle_input'] or 0
		local brake = electrics.values['brake_input'] or 0
		local steer = electrics.values['steering_input'] or 0
		local speed = (electrics.values.wheelspeed or 0) * 3.6

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

		local coastGain = minLockCoef
		local small = basePreload * (1 - xLockCoef)
		local throttleGain = pedalLock(throttle, throttleStart, throttleTravel, 1.59, xLockCoef)
		local throttlePreload = small
		local brakeGain = pedalLock(brake, brakeStart, brakeTravel, 0.67, xLockCoef)
		local brakePreload = basePreload * preloadMultiplier * brakeGain

		-- Apply each candidate's left-foot modifier before blending modes
		if throttle > coastStart and brake > coastStart then
			throttleGain, throttlePreload = applyLeftFoot(throttleGain, throttlePreload, brake, lbBrakeGain)
			brakeGain, brakePreload = applyLeftFoot(brakeGain, brakePreload, throttle, lbThrottleGain)
		end
		updateMapWeights(activeMap, dt)

		local newLockCoef = mapWeights.coast * coastGain + mapWeights.throttle * throttleGain + mapWeights.brake * brakeGain
		local newPreload = mapWeights.coast * small + mapWeights.throttle * throttlePreload + mapWeights.brake * brakePreload
		newLockCoef = clamp(newLockCoef, 0, 1)
		newPreload = clamp(newPreload, 0, basePreload * preloadMultiplier)

		transfercase.speedLimitCoef = 0 -- WHY THIS IS NOT 0 BY DEFAULT?
		local clutchTarget = (handbrake >= hbRelease) and 0 or 1
		local clutchRatio = clutchRatioSmoother:get(clutchTarget, dt)
		clutchRatio = clamp(clutchRatio, 0, 1)

		transfercase.lsdLockCoef = newLockCoef * 0.499 * clutchRatio
		transfercase.lsdRevLockCoef = transfercase.lsdLockCoef
		transfercase.diffTorqueSplitA = lerp(0, rearBias, clutchRatio)
		transfercase.diffTorqueSplitB = lerp(1, 1 - rearBias, clutchRatio)
		transfercase.lsdPreload = newPreload * clutchRatio
		--print(transfercase.lsdPreload)

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
		transfercase.lsdPreload = basePreload * clutchRatio
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
		steeringLockCut = jbeamData.lockMap.steeringLockCut or 0.4
		speedMapFactor = jbeamData.lockMap.speedMapFactor or 0.54
		throttleStart = jbeamData.lockMap.throttleStart or 0.3
		throttleTravel = jbeamData.lockMap.throttleTravel or (6 / 7)
		brakeStart = jbeamData.lockMap.brakeStart or 0.15
		brakeTravel = jbeamData.lockMap.brakeTravel or (12 / 17)
		lbThreshold = jbeamData.lockMap.lbThreshold or 0.10
		lbThrottleGain = jbeamData.lockMap.lbThrottleGain or 1
		lbBrakeGain = jbeamData.lockMap.lbBrakeGain or 1
		coastStart = jbeamData.lockMap.coastStart or 0.05
		rearBias = jbeamData.lockMap.rearBias or 0.5
		hbRelease = jbeamData.lockMap.hbRelease or 0.65
		basePreload = jbeamData.lockMap.basePreload or 80
		preloadMultiplier = jbeamData.lockMap.preloadMultiplier or 40
		modeBlendTime = 0.02
	end

	--get tuning data for passive
	if transfercase and transferType == "passive" then
		maxLockCoef = jbeamData.lockMap.maxLockCoef or 0.25
		minLockCoef = jbeamData.lockMap.minLockCoef or 0.25
		basePreload = jbeamData.lockMap.basePreload or 0
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