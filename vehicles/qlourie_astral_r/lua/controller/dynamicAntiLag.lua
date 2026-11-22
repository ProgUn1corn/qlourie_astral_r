-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local rpmToAV = math.pi / 30
local stageTimeout = 10 -- Maximum seconds of stage ALS per lift.
local levelNames = {[0] = "Off", "Soft", "Medium", "Aggressive"}

local engine
local turbo
local turboAVPIDController
local level, minTurboAV, stagePowerCoef
local stageTargetCurve
local wasOnThrottle, liftStartAV, timeSinceLift

local launchTurboTargetAV
local launchSustainedAfterFireCoef
local preLaunchAfterFireCoef

local function getStageTargetAV(dt)
	-- Arm on power. The gap between pedal thresholds keeps noise from restarting the hold.
	local throttle = electrics.values.throttle or 0
	if engine.outputAV1 <= engine.maxIdleAV then
		wasOnThrottle = false
		liftStartAV = nil
	elseif throttle >= 0.05 then
		wasOnThrottle = true
		liftStartAV = nil
	elseif wasOnThrottle and throttle <= 0.02 then
		wasOnThrottle = false
		liftStartAV = turbo.turboAV
		timeSinceLift = 0
	end

	if not liftStartAV then return 0 end
	if timeSinceLift >= stageTimeout then
		liftStartAV = nil
		return 0
	end

	timeSinceLift = timeSinceLift + dt
	if stageTargetCurve then
		local rpm = clamp(math.floor(engine.outputAV1 / rpmToAV + 0.5), 0, #stageTargetCurve)
		return math.max(0, stageTargetCurve[rpm]) * rpmToAV
	end

	-- ECUs with a fixed floor hold at most the shaft speed seen at pedal release.
	local targetAV = math.min(liftStartAV, minTurboAV)
	local idleFade = clamp((engine.outputAV1 - engine.maxIdleAV) / (0.5 * engine.maxIdleAV), 0, 1)
	return targetAV * idleFade
end

local function updateLaunchAfterFire(antilagCoef)
	if launchSustainedAfterFireCoef and antilagCoef > 0 then
		preLaunchAfterFireCoef = preLaunchAfterFireCoef or engine.sustainedAfterFireCoef
		engine.sustainedAfterFireCoef = lerp(preLaunchAfterFireCoef, launchSustainedAfterFireCoef, antilagCoef)
	elseif preLaunchAfterFireCoef then
		engine.sustainedAfterFireCoef = preLaunchAfterFireCoef
		preLaunchAfterFireCoef = nil
	end
end

local function updateGFX(dt)
	local launchActive = electrics.values.launchActive == 1
	local running = engine.ignitionCoef > 0 and not engine.isStalled and not engine.isDisabled
	local stageTargetAV = 0
	local targetAV = 0
	local state = launchActive and "launch" or "off"
	if running and not launchActive and level > 0 then
		stageTargetAV = getStageTargetAV(dt)
		targetAV = stageTargetAV
		state = (wasOnThrottle or liftStartAV) and "armed" or "idle"
	else
		wasOnThrottle = false
		liftStartAV = nil
		if running and launchActive then
			targetAV = launchTurboTargetAV
		end
	end
	local antilagCoef = targetAV > 0 and turboAVPIDController:get(turbo.turboAV, targetAV, dt) or 0
	if stageTargetAV > 0 then
		antilagCoef = antilagCoef * stagePowerCoef
	end
	updateLaunchAfterFire(launchActive and antilagCoef or 0)

	electrics.values.alsActive = antilagCoef > 0
	electrics.values.alsState = state
	electrics.values.stageAlsTargetRPM = stageTargetAV / rpmToAV
	engine:setAntilagCoef(antilagCoef)
end

local function reset()
	wasOnThrottle = false
	liftStartAV = nil
	turboAVPIDController:reset()
	updateLaunchAfterFire(0)
	engine:setAntilagCoef(0)
	electrics.values.alsActive = false
	electrics.values.alsState = level == 0 and "off" or "idle"
	electrics.values.stageAlsTargetRPM = 0
end

local function init(jbeamData)
	engine = powertrain.getDevice(jbeamData.controlledEngine or "mainEngine")
	turbo = engine.turbocharger
	stageTargetCurve = jbeamData.stageTurboRPMByEngineRPM and createCurve(jbeamData.stageTurboRPMByEngineRPM)
	launchSustainedAfterFireCoef = jbeamData.launchSustainedAfterFireCoef
	launchTurboTargetAV = (jbeamData.launchTurboTargetRPM or 120000) * rpmToAV
	turboAVPIDController = newPIDParallel(0.01, 0, 0, 0, 1, -10, 10)
	level = 0
	reset()
end

local function displayState()
	guihooks.message("ALS: " .. levelNames[level], 2, "vehicle.ALS.map")
end

local function setParameters(parameters)
	level = parameters.ALS
	if level == 0 then
		wasOnThrottle = false
		liftStartAV = nil
		electrics.values.stageAlsTargetRPM = 0
	else
		stagePowerCoef = clamp(parameters.powerCoef or 1, 0, 1)
		if not stageTargetCurve then
			minTurboAV = math.max(0, parameters.minTurboRPM or 0) * rpmToAV
		end
	end
	displayState()
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
M.displayState = displayState

return M
