-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local rpmToAV = 0.104719755
local exitSpeed = 10 / 3.6 -- m/s
local handbrakeThreshold = 0.6
local engine, presets
local previousTorqueLimit
local presetIndex = 1
local allowed = false
local state = "off"

local function updateSimpleControlButtons()
  local preset = presets[presetIndex]
  local label = string.format("LC%d: %d RPM / %d%%", presetIndex, preset.rpm, preset.torquePercent)
  extensions.ui_simplePowertrainControl.setButton(
    "astralLaunchPreset", label, "astral_launch_" .. presetIndex, state ~= "off" and "FF2701" or "343434", nil,
    "controller.getControllerSafe('launchControl').nextPreset()"
  )
end

local function handbrakePulled()
  return (electrics.values.parkingbrake_input or 0) > handbrakeThreshold
end

local function setState(nextState)
  local armed = nextState ~= "off"
  local active = nextState == "active"
  local preset = presets[presetIndex]
  if active then
    engine:setTempRevLimiter(preset.rpm * rpmToAV)
    if preset.torquePercent < 100 then
      previousTorqueLimit = engine.maxTorqueLimit
      engine.maxTorqueLimit = math.min(previousTorqueLimit, engine.maxTorque * preset.torquePercent / 100)
    end
  elseif state == "active" then
    engine:resetTempRevLimiter()
    if previousTorqueLimit then
      engine.maxTorqueLimit = previousTorqueLimit
      previousTorqueLimit = nil
    end
  end
  state = nextState
  electrics.values.launchArmed = armed and 1 or 0
  electrics.values.launchActive = active and 1 or 0
  electrics.values.launchTargetRPM = armed and preset.rpm or 0
  electrics.values.launchTargetTorquePercent = armed and preset.torquePercent or 0
  electrics.values.twoStep = electrics.values.launchActive
  updateSimpleControlButtons()
  if active then
    guihooks.message({txt = "vehicle.astral.launch.active", context = {preset = presetIndex, rpm = preset.rpm, torque = preset.torquePercent}}, 2, "vehicle.astral.launch")
  elseif armed then
    guihooks.message({txt = "vehicle.astral.launch.armed", context = {preset = presetIndex, threshold = handbrakeThreshold * 100}}, 2, "vehicle.astral.launch")
  end
end

local function toggleLaunch()
  if state ~= "off" then
    setState("off")
    guihooks.message("vehicle.astral.launch.cancelled", 2, "vehicle.astral.launch")
    return
  end

  if not allowed then
    guihooks.message("vehicle.astral.launch.unavailable", 2, "vehicle.astral.launch")
    return
  end
  if math.abs(obj:getGroundSpeed()) > 0.5 then
    guihooks.message("vehicle.astral.launch.stopVehicle", 2, "vehicle.astral.launch")
    return
  end

  setState(handbrakePulled() and "active" or "armed")
end

local function selectPreset(index)
  if state ~= "off" then
    guihooks.message("vehicle.astral.launch.cancelToSelect", 2, "vehicle.astral.launch")
    return
  end
  local preset = presets[index]
  if not preset then return end
  presetIndex = index
  electrics.values.launchPreset = index
  updateSimpleControlButtons()
  controller.getControllerSafe("gauge").displayPopupMessage("launchPreset", nil, 1.6)
  guihooks.message({txt = "vehicle.astral.launch.preset", context = {preset = index, rpm = preset.rpm, torque = preset.torquePercent}}, 2, "vehicle.astral.launch")
end

local function updateGFX()
  if state == "off" then return end
  if math.abs(obj:getGroundSpeed()) >= exitSpeed then
    setState("off")
  elseif state == "armed" and handbrakePulled() then
    setState("active")
  elseif state == "active" and not handbrakePulled() then
    setState("armed")
  end
end

local function setParameters(parameters)
  allowed = parameters.isAllowed
  if state ~= "off" and not allowed then
    setState("off")
  end
end

local function reset()
  -- BeamNG resets the powertrain before resetting vehicle controllers.
  previousTorqueLimit = nil
  allowed = false
  setState("off")
  electrics.values.launchPreset = presetIndex
end

local function init(jbeamData)
  engine = powertrain.getDevice("mainEngine")
  presets = jbeamData.presets
  presetIndex = 1
  reset()
end

local function serialize()
  return {presetIndex = presetIndex}
end

local function deserialize(data)
  if presets[data.presetIndex] then
    presetIndex = data.presetIndex
  elseif data.rpm then
    -- Older saves stored the selected RPM directly.
    for i, preset in ipairs(presets) do
      if preset.rpm == data.rpm then
        presetIndex = i
        break
      end
    end
  end
  setState("off")
  electrics.values.launchPreset = presetIndex
end

M.init = init
M.reset = reset
M.updateGFX = updateGFX
M.setParameters = setParameters
M.toggleLaunch = toggleLaunch
M.nextPreset = function() selectPreset(presetIndex % #presets + 1) end
M.previousPreset = function() selectPreset((presetIndex - 2) % #presets + 1) end
M.selectPreset = selectPreset
M.updateSimpleControlButtons = updateSimpleControlButtons
M.serialize = serialize
M.deserialize = deserialize

return M
