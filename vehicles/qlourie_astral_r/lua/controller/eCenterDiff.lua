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
local preload

--common values
local minLockCoef
local lockRange
local hbrelease
local newPreload
local rearBias
local finalDrive
local clutchRatioSmoother = newTemporalSmoothingNonLinear(24, 16)

--active values
local throttle
local brake
local steer
local speed
local steerRatio
local speedMap
local throttleRatio
local throttleStart
local brakeRatio
local brakeStart
local lbThreshold --left foot
local lbThrottleGain --left foot
local lbBrakeGain --left foot
local coastStart

--passive values
local maxLockCoef

--PEAL values

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

local function steerLock(steer, speed)
    local normalSteer = abs(steer) ^ 0.74
    local clampSpeed = clamp(speed, 0, 140)
    local contributionSteer = clamp(lockRange * normalSteer * steerRatio, 0, 1)
    local speedFactor = clamp(1 - 0.9 * (clampSpeed / 140) * (-speedMap / 2000), 0.1, 1)
    return contributionSteer * speedFactor
end

local function throttleLock(throttle, throttleStart, throttleRatio, xLockCoef)
    local throttleNormalized = clamp((throttle - throttleStart) / (throttleRatio - throttleStart), 0, 1)
    local throttleCurve = throttleNormalized ^ 1.59
    local yLock = clamp(lockRange * throttleCurve + minLockCoef - xLockCoef, minLockCoef, 1)
    return yLock
end

local function brakeLock(brake, brakeStart, brakeRatio, xLockCoef)
    local brakeNormalized = clamp((brake - brakeStart) / (brakeRatio - brakeStart), 0, 1)
    local brakeCurve = brakeNormalized ^ 0.67
    local yLock = clamp(lockRange * brakeCurve + minLockCoef - xLockCoef, minLockCoef, 1)
    return yLock
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

		--Brake and throttle contribution with left foot factor
		local activeMap
		local yLockCoef
		local preloadAdj

		if throttle <= coastStart and brake <= coastStart then
			activeMap = "coast"
		elseif throttle > brake then
			activeMap = "throttle"
		else
			activeMap = "brake"
		end
		--print(activeMap)

		if activeMap == "throttle" then --calculate throttle lock map using torsen (clutch-type)
			if throttleRatio - throttleStart <= 0 then
				yLockCoef = 1
				preloadAdj = preload * minLockCoef	* (1 - xLockCoef)
			else
				yLockCoef = throttleLock(throttle, throttleStart, throttleRatio, xLockCoef)
				preloadAdj = preload * minLockCoef	* (1 - xLockCoef)
			end
		elseif activeMap == "brake" then --calculate brake lock map additionally added with preload
			if brakeRatio - brakeStart <= 0 then
				yLockCoef = 1
				preloadAdj = preload * yLockCoef
			else
				yLockCoef = brakeLock(brake, brakeStart, brakeRatio, xLockCoef)
				preloadAdj = preload * yLockCoef * (1 - xLockCoef)
			end
		elseif activeMap == "coast" then --apply coast map
			yLockCoef = minLockCoef
			preloadAdj = preload * minLockCoef	* (1 - xLockCoef)
		end

		local lbMap = throttle > coastStart and brake > coastStart --left foot
		local lbGain = 0
		local yLockLbReduction = 0
		local preloadLbReduction = 0

		if lbMap then
			local lbInput
			if activeMap == "throttle" then
				lbInput = brake
				lbGain = lbBrakeGain
			elseif activeMap == "brake" then
				lbInput = throttle
				lbGain = lbThrottleGain
			elseif activeMap == "coast" then
				lbInput = nil
				lbGain = nil
			end

			if lbInput and lbGain then
				local lbInputNorm = clamp((lbInput - lbThreshold) / (1 - lbThreshold), 0, 1)
				yLockLbReduction = lbInputNorm ^ 1.3 * lbGain * 0.4
				preloadLbReduction = lbInputNorm ^ 0.8 * preloadAdj * lbGain
			else
				yLockLbReduction = 0
				preloadLbReduction = 0
			end
			yLockCoef = yLockCoef - yLockLbReduction
			preloadAdj = preloadAdj - preloadLbReduction
		end
		--print(yLockLbReduction)
		--print(preloadLbReduction)

		--sum up X and Y lock factors
		local newLockCoef = clamp(yLockCoef, minLockCoef, 1)
		local newPreload = clamp(preloadAdj, 0, preload)
		--print(newLockCoef)
		--print(newPreload)

		transfercase.speedLimitCoef = 0 -- WHY THIS IS NOT 0 BY DEFAULT?
		local clutchTarget = (handbrake >= hbrelease) and 0 or 1
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
		local clutchTarget = (handbrake >= hbrelease) and 0 or 1
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
		local clutchTarget = (handbrake >= hbrelease) and 0 or 1
		local clutchRatio = clutchRatioSmoother:get(clutchTarget, dt)
		clutchRatio = clamp(clutchRatio, 0, 1)
		transfercase.clutchRatio = clutchRatio
		--print(transfercase.clutchRatio)
	end
end

local function reset()
end

local function init(jbeamData)
	--print("TWICE?")
	transfercase = powertrain.getDevice(jbeamData.transfercaseName) or nil
	transferType = jbeamData.type or 0

	--get tuning data for active
	if transfercase and transferType == "active" then
		minLockCoef = jbeamData.lockMap.minLock or 0.1
		lockRange = 1 - minLockCoef
		steerRatio = jbeamData.lockMap.steerRatio or 1
		speedMap = jbeamData.lockMap.speedMap or 0
		throttleRatio = jbeamData.lockMap.lockThrottle or 0.8
		throttleStart = jbeamData.lockMap.lockThrottleStart or 0.25
		brakeRatio = jbeamData.lockMap.lockBrake or 0.8
		brakeStart = jbeamData.lockMap.lockBrakeStart or 0.25
		lbThreshold = jbeamData.lockMap.leftThreshold or 0.10
		lbThrottleGain = jbeamData.lockMap.leftThrottleGain or 1
		lbBrakeGain = jbeamData.lockMap.leftBrakeGain or 1
		coastStart = jbeamData.lockMap.coastStart or 0.05
		rearBias = jbeamData.lockMap.rearBias or 0.5
		hbrelease = jbeamData.lockMap.hbRelease or 0.65
		preload = jbeamData.lockMap.preload or 0
		finalDrive = jbeamData.lockMap.finalDrive or 4

		if throttleRatio ~= 0 and throttleRatio - throttleStart <= 0 then
			log("Throttle start point is higher than throttle threshold! Locking center diff...")
		end
		if brakeRatio ~= 0 and brakeRatio - brakeStart <= 0 then
			log("Brake start point is higher than brake threshold! Locking center diff...")
		end
	end

	--get tuning data for passive
	if transfercase and transferType == "passive" then
		maxLockCoef = jbeamData.lockMap.lock or 0.25
		minLockCoef = jbeamData.lockMap.revLock or 0.25
		preload = jbeamData.lockMap.preload or 0
		rearBias = jbeamData.lockMap.rearBias or 0.5
		hbrelease = jbeamData.lockMap.hbRelease or 0.65
	end

	--get tuning data for PEAL
	if transfercase and transferType == "peal" then
		hbrelease = jbeamData.hbRelease or 0.65
	end
end

--local function setParameters(parameters)
	--print(parameters.tMap)
	--if parameters.minLock then
		--minLockCoef = parameters.minLock
	--else
		--tMap = 2
	--end
--end

M.init = init
M.reset = reset
M.setParameters = setParameters
M.updateFixedStep = updateFixedStep

return M