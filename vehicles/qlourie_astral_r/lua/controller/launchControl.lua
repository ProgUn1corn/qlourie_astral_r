-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local engine = nil
local electricsName = nil
local hasBuiltPie = false
local idleRPM
local maxRPM

local rpmToAV = 0.104719755

local tempRevLimiterAV = 0
local tempRevLimiterRPM = 0
local twoStepState = "deactivated"

local function displayState()
	guihooks.message(string.format("Launch: %s (%d RPM)", (twoStepState ~= "deactivated" and "Active" or "Inactive"), tempRevLimiterRPM), 2, "vehicle.twoStep.status")
end

local function setTwoStep(enabled)
	if engine then
		if enabled then
			twoStepState = "idle"
		else
			twoStepState = "deactivated"
			engine:resetTempRevLimiter()
		end
		displayState()
	end
end

local function toggleTwoStep()
	if engine then
		setTwoStep(twoStepState == "deactivated")
	end
end

local function setTwoStepRPM(rpm)
	tempRevLimiterRPM = rpm
	tempRevLimiterAV = tempRevLimiterRPM * rpmToAV
	displayState()
end

local function changeTwoStepRPM(amount)
	setTwoStepRPM(tempRevLimiterRPM + amount)
end

local function updateGFX(dt)
	engine.idleAV = idleRPM * rpmToAV
	engine.revLimiterAV = maxRPM * rpmToAV

	if twoStepState == "idle" then
		local usesKeyboard = input.state.throttle.filter == FILTER_KBD or input.state.throttle.filter == FILTER_KBD2
		local isSpeedLowEnough = usesKeyboard and (electrics.values.wheelspeed <= 2) or (electrics.values.wheelspeed <= 0.5)
		local isThrottleHighEnough = usesKeyboard and (electrics.values.throttle >= 0.2) or (electrics.values.throttle >= 0.2)
		local isParkingBrakeActive = usesKeyboard and (electrics.values.parkingbrake >= 0.7) or (electrics.values.parkingbrake >= 0.7)

		if isSpeedLowEnough and isThrottleHighEnough and isParkingBrakeActive then
			twoStepState = "armed"
		end
	elseif twoStepState == "armed" then
		engine:setTempRevLimiter(tempRevLimiterAV)

		if electrics.values.parkingbrake <= 0 or electrics.values.throttle <= 0 then
			engine:resetTempRevLimiter()
			twoStepState = "idle"
		end
	end

	electrics.values[electricsName] = twoStepState ~= "deactivated"
end

local function reset()
	if engine then
		engine:resetTempRevLimiter()
	end
	if twoStepState ~= "deactivated" then
		twoStepState = "idle"
	end
end

local function init(jbeamData)
	local engineName = jbeamData.engineName or "mainEngine"
	electricsName = jbeamData.electricsName or "twoStep"
	engine = powertrain.getDevice(engineName)
	idleRPM = engine.idleRPM
	maxRPM = engine.maxRPM
	--dump(engine)
	M.updateGFX = engine and updateGFX or nop
	twoStepState = "deactivated"
	setTwoStepRPM(jbeamData.rpmLimit or 2000)

	if not hasBuiltPie then
		if engine then
			core_quickAccess.addEntry(
				{
					level = "/powertrain/",
					generator = function(entries)
						table.insert(entries, {title = "Two-Step", priority = 40, ["goto"] = "/powertrain/twoStep/", icon = "radial_flee"})
					end
				}
			)

			core_quickAccess.addEntry(
				{
					level = "/powertrain/twoStep",
					generator = function(entries)
						local enableEntry = {
							title = "Toggle",
							priority = 30,
							icon = "radial_toggle",
							onSelect = function()
								controller.getController("twoStepLaunch").toggleTwoStep()
								return {"reload"}
							end
						}
						if twoStepState ~= "deactivated" then
							enableEntry.color = "#ff6600"
						end
						local upEntry = {
							title = "RPM Up",
							priority = 10,
							icon = "material_keyboard_arrow_up",
							onSelect = function()
								controller.getController("twoStepLaunch").changeTwoStepRPM(100)
								return {"reload"}
							end
						}
						local downEntry = {
							title = "RPM Down",
							priority = 20,
							icon = "material_keyboard_arrow_down",
							onSelect = function()
								controller.getController("twoStepLaunch").changeTwoStepRPM(-100)
								return {"reload"}
							end
						}
						table.insert(entries, enableEntry)
						table.insert(entries, upEntry)
						table.insert(entries, downEntry)
					end
				}
			)
		end
		hasBuiltPie = true
	end
end

local function serialize()
	return {
		state = twoStepState,
		rpm = tempRevLimiterRPM
	}
end

local function deserialize(data)
	if data and data.state and data.rpm then
		twoStepState = data.state
		setTwoStepRPM(data.rpm)
	end
end

local function setParameters(parameters)
	if parameters.isEnabled ~= nil then
		setTwoStep(parameters.isEnabled)
	end

	if parameters.launchRPM then
		--print(parameters.launchRPM)
		setTwoStepRPM(parameters.launchRPM)
	end

	if parameters.idleRPM then
		idleRPM = parameters.idleRPM
	end

	if parameters.maxRPM then
		maxRPM = parameters.maxRPM
	else
		maxRPM = engine.maxRPM
	end
end

M.init = init
M.reset = reset
M.updateGFX = nop
M.setTwoStep = setTwoStep
M.toggleTwoStep = toggleTwoStep
M.changeTwoStepRPM = changeTwoStepRPM
M.serialize = serialize
M.deserialize = deserialize

M.setParameters = setParameters

return M
