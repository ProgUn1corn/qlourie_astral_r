-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
-- Based on BeamNG's shiftLights.lua. Gear arrays start in neutral and repeat their
-- last value in higher gears. Reverse turns the shift lights off.

local M = {type = "auxiliary"}

local min, max = math.min, math.max
local lightProfiles, lamps
local inputElectricsName, keepLowerLEDsOn, stallWarningEngine
local flashDuration, flashTimer, flashSwitch

local function asGearTable(value)
  return type(value) == "table" and value or {value}
end

local function init(jbeamData)
  inputElectricsName = jbeamData.inputElectricsName or "rpm"
  keepLowerLEDsOn = jbeamData.keepLEDsActive ~= false
  flashDuration = jbeamData.flashDuration or 0.1
  flashTimer, flashSwitch = 0, false

  -- A channel may be used both for a steady step and for flashing.
  lamps = {}
  for _, name in pairs(jbeamData.flashingOutputElectrics or {}) do
    lamps[name] = {flashOn = true}
  end
  for _, name in pairs(jbeamData.flashingAlternateOutputElectrics or {}) do
    lamps[name] = {flashOn = false}
  end
  local steps = jbeamData.outputElectrics or {}
  for i, name in ipairs(steps) do
    local lamp = lamps[name] or {}
    lamp[#lamp + 1] = i
    lamps[name] = lamp
  end

  local rpmSetting = jbeamData.maxRPM or jbeamData.maxEngineRPMOffset
  local usesOffset = jbeamData.maxRPM == nil and jbeamData.maxEngineRPMOffset ~= nil
  local engine = rpmSetting and jbeamData.engineName and powertrain.getDevice(jbeamData.engineName)
  local engineMaxRPM = engine and engine.maxRPM
  stallWarningEngine = jbeamData.hasStallWarning and engine

  local rpmSettings = asGearTable(rpmSetting)
  local ranges = asGearTable(jbeamData.rpmRange)
  local target = usesOffset and 0 or 7000
  local range = 3000
  lightProfiles = {}
  for gear = 1, max(1, #rpmSettings, #ranges) do
    if type(rpmSettings[gear]) == "number" then target = rpmSettings[gear] end
    if type(ranges[gear]) == "number" then range = ranges[gear] end
    local maxRPM = target
    if usesOffset then maxRPM = engineMaxRPM and (engineMaxRPM - target) or 7000 end
    local minRPM = jbeamData.minRPM or (maxRPM - range)
    local stepSize = (maxRPM - minRPM) / max(#steps, 1)
    local profile = {maxRPM = maxRPM}
    for i = 1, #steps + 1 do
      profile[i] = minRPM + stepSize * (i - 1)
    end
    lightProfiles[gear] = profile
  end
end

local function updateGFX(dt)
  local e = electrics.values
  local rpm = e[inputElectricsName] or 0
  local gear = e.gearIndex or 0
  local reverse = gear < 0
  local profile = lightProfiles[min(max(gear + 1, 1), #lightProfiles)]
  local overMaxRPM = not reverse and rpm >= profile.maxRPM
  local flashing = overMaxRPM or (stallWarningEngine and stallWarningEngine.isStalled)

  e.shouldShift = overMaxRPM
  -- Launch uses the neutral threshold even with first gear engaged.
  e.launchLight = e.launchActive == 1 and rpm >= lightProfiles[1].maxRPM and 1 or 0

  flashTimer = max(flashTimer - dt, 0)
  if reverse then
    flashTimer, flashSwitch = 0, false
  elseif flashing then
    if flashTimer <= 0 then
      flashSwitch = not flashSwitch
      flashTimer = flashDuration
    end
  else
    flashSwitch = false
  end

  for name, lamp in pairs(lamps) do
    if reverse then
      e[name] = 0
    elseif flashing and lamp.flashOn ~= nil then
      e[name] = lamp.flashOn == flashSwitch and 1 or 0
    elseif lamp[1] then
      local value = 0
      for _, step in ipairs(lamp) do
        if not overMaxRPM and rpm >= profile[step] and (keepLowerLEDsOn or rpm < profile[step + 1]) then
          value = 1
          break
        end
      end
      e[name] = value
    end
  end
end

M.init = init
M.updateGFX = updateGFX

return M
