-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local rpmToAV = math.pi / 30
local stageTimeout = 10 -- Maximum seconds of stage ALS per lift.
local maxAfterFireMultiplier = 20
local levelNames = {[0] = "Off", "Soft", "Medium", "Aggressive"}

local engine
local turbo
local turboAVPIDController
local level, minTurboAV, stagePowerCoef
local wasOnThrottle, liftStartAV, timeSinceLift

local launchTurboTargetAV
local baseAfterFireCoef

local function getLiftTargetAV(dt)
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
	-- ECUs with a fixed floor hold at most the shaft speed seen at pedal release.
	local targetAV = math.min(liftStartAV, minTurboAV)
	local idleFade = clamp((engine.outputAV1 - engine.maxIdleAV) / (0.5 * engine.maxIdleAV), 0, 1)
	return targetAV * idleFade
end

local function updateGFX(dt)
	local launchActive = electrics.values.launchActive == 1
	local boostTargetRPM = electrics.values.boostTargetTurboRPM
	local running = engine.ignitionCoef > 0 and not engine.isStalled and not engine.isDisabled
	local stageTargetAV = 0
	local targetAV = 0
	local state = launchActive and "launch" or "off"
	if running and not launchActive and level > 0 then
		if boostTargetRPM ~= nil then
			stageTargetAV = boostTargetRPM * rpmToAV
			state = stageTargetAV > 0 and "armed" or "idle"
		else
			stageTargetAV = getLiftTargetAV(dt)
			state = (wasOnThrottle or liftStartAV) and "armed" or "idle"
		end
		targetAV = stageTargetAV
	else
		wasOnThrottle = false
		liftStartAV = nil
		if running and launchActive then
			targetAV = boostTargetRPM and boostTargetRPM * rpmToAV or launchTurboTargetAV
		end
	end
	local antilagCoef = targetAV > 0 and turboAVPIDController:get(turbo.turboAV, targetAV, dt) or 0
	if stageTargetAV > 0 then
		antilagCoef = antilagCoef * stagePowerCoef
	end
	electrics.values.alsActive = antilagCoef > 0
	-- RX1's fixed-speed ALS uses the afterfire calibration supplied by its engine.
	if boostTargetRPM ~= nil then
		engine.sustainedAfterFireCoef = baseAfterFireCoef * lerp(1, maxAfterFireMultiplier, antilagCoef)
	end
	electrics.values.alsState = state
	electrics.values.stageAlsTargetRPM = stageTargetAV / rpmToAV
	engine:setAntilagCoef(antilagCoef)
end

local function reset()
	wasOnThrottle = false
	liftStartAV = nil
	turboAVPIDController:reset()
	engine.sustainedAfterFireCoef = baseAfterFireCoef
	engine:setAntilagCoef(0)
	electrics.values.alsActive = false
	electrics.values.alsState = level == 0 and "off" or "idle"
	electrics.values.stageAlsTargetRPM = 0
end

local function init(jbeamData)
	engine = powertrain.getDevice(jbeamData.controlledEngine or "mainEngine")
	turbo = engine.turbocharger
	baseAfterFireCoef = v.data[engine.name].sustainedAfterFireCoef or 0
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
		minTurboAV = math.max(0, parameters.minTurboRPM or 0) * rpmToAV
	end
	displayState()
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
M.displayState = displayState

return M
