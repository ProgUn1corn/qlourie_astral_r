-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Based on BeamNG's shiftLights.lua; adds neutral/per-gear RPM targets, offsets and ranges.
-- Array order: neutral, 1st, 2nd, ...; reverse always turns the shift lights off.

local M = {}
M.type = "auxiliary"

local max = math.max
local min = math.min
local floor = math.floor

local lightProfiles = nil
local flashingLEDsOn = nil
local flashingLEDsOff = nil
local inputElectricsName = nil
local flashDuration = 0
local flashTimer = 0
local flashSwitch = false
local keepLowerLEDsOn = true
local stallWarningEngine = nil
local hasStallWarning = false

local function isFiniteNumber(value)
  return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function readGearValues(value, defaultValue, parameterName)
  local values = {}
  local previousValue = defaultValue

  if type(value) == "table" then
    for i, entry in ipairs(value) do
      if isFiniteNumber(entry) then
        previousValue = entry
      else
        local gearName = i == 1 and "neutral" or ("gear " .. (i - 1))
        log("W", "multiShiftLights", "Invalid " .. parameterName .. " for " .. gearName .. "; using " .. previousValue)
      end
      values[i] = previousValue
    end
    if #values == 0 then
      log("W", "multiShiftLights", "Empty " .. parameterName .. " array; using " .. defaultValue .. " for all gears.")
      values[1] = defaultValue
    end
  else
    if value ~= nil and not isFiniteNumber(value) then
      log("W", "multiShiftLights", "Invalid " .. parameterName .. "; using " .. defaultValue .. " for all gears.")
    end
    values[1] = isFiniteNumber(value) and value or defaultValue
  end
  return values
end

local function updateGFX(dt)
  local rpm = electrics.values[inputElectricsName] or 0
  local gearIndex = electrics.values.gearIndex or 0

  local profileIndex = min(max(floor(gearIndex) + 1, 1), #lightProfiles)
  local profile = lightProfiles[profileIndex]
  local lightSteps = profile.steps

  for _, v in ipairs(lightSteps) do
    electrics.values[v.electricsName] = 0
  end

  -- Reverse turns off all shift lights; array entry 1 is reserved for neutral.
  if gearIndex < 0 then
    for _, v in ipairs(flashingLEDsOn) do
      electrics.values[v] = 0
    end
    for _, v in ipairs(flashingLEDsOff) do
      electrics.values[v] = 0
    end
    electrics.values.shouldShift = false
    flashTimer = 0
    flashSwitch = false
    return
  end

  local isOverMaxRPM = rpm >= profile.maxRPM

  for _, v in ipairs(lightSteps) do
    if rpm >= v.startRPM and (rpm < v.endRPM or keepLowerLEDsOn) and not isOverMaxRPM then
      electrics.values[v.electricsName] = 1
    end
  end

  electrics.values.shouldShift = isOverMaxRPM

  flashTimer = max(flashTimer - dt, 0)
  if isOverMaxRPM or (hasStallWarning and stallWarningEngine.isStalled) then
    if flashTimer <= 0 then
      flashSwitch = not flashSwitch
      flashTimer = flashDuration
    end
    local flashValue = flashSwitch and 1 or 0
    for _, v in ipairs(flashingLEDsOn) do
      electrics.values[v] = flashValue
    end
    for _, v in ipairs(flashingLEDsOff) do
      electrics.values[v] = 1 - flashValue
    end
  else
    flashSwitch = false
  end
end

local function init(jbeamData)
  flashTimer = 0
  flashSwitch = false
  lightProfiles = {}
  stallWarningEngine = nil
  hasStallWarning = false

  local usesDirectRPM = jbeamData.maxRPM ~= nil
  local gearValues
  if usesDirectRPM then
    gearValues = readGearValues(jbeamData.maxRPM, 7000, "maxRPM")
  else
    gearValues = readGearValues(jbeamData.maxEngineRPMOffset, 0, "maxEngineRPMOffset")
  end
  local engine = nil

  if jbeamData.engineName and (usesDirectRPM or jbeamData.maxEngineRPMOffset ~= nil) then
    engine = powertrain.getDevice(jbeamData.engineName)
    if engine and (usesDirectRPM or isFiniteNumber(engine.maxRPM)) then
      stallWarningEngine = engine
      hasStallWarning = jbeamData.hasStallWarning or false
    else
      log("W", "multiShiftLights", "Engine or engine.maxRPM unavailable; using maxRPM or the 7000 RPM default.")
      engine = nil
    end
  end

  inputElectricsName = jbeamData.inputElectricsName or "rpm"
  keepLowerLEDsOn = jbeamData.keepLEDsActive == nil and true or jbeamData.keepLEDsActive
  flashDuration = jbeamData.flashDuration or 0.1

  local rpmRanges = readGearValues(jbeamData.rpmRange, 3000, "rpmRange")
  local steps = jbeamData.outputElectrics or {}
  local stepCount = #steps

  for gearIndex = 1, max(#gearValues, #rpmRanges) do
    local value = gearValues[min(gearIndex, #gearValues)]
    local rpmRange = rpmRanges[min(gearIndex, #rpmRanges)]
    local maxRPM
    if usesDirectRPM then
      maxRPM = value
    else
      maxRPM = engine and (engine.maxRPM - value) or 7000
    end
    local minRPM = jbeamData.minRPM or (maxRPM - rpmRange)
    local rpmStep = (maxRPM - minRPM) / max(stepCount, 1)
    local profile = {maxRPM = maxRPM, steps = {}}
    for i = 1, stepCount do
      profile.steps[i] = {startRPM = minRPM + rpmStep * (i - 1), endRPM = minRPM + rpmStep * i, electricsName = steps[i]}
    end
    lightProfiles[gearIndex] = profile
  end

  flashingLEDsOn = {}
  flashingLEDsOff = {}
  for _, v in pairs(jbeamData.flashingOutputElectrics or {}) do
    table.insert(flashingLEDsOn, v)
  end
  for _, v in pairs(jbeamData.flashingAlternateOutputElectrics or {}) do
    table.insert(flashingLEDsOff, v)
  end
end

M.init = init
M.updateGFX = updateGFX

return M
