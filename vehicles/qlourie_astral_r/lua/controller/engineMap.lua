-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Adapted from BeamNG's lua/vehicle/controller/driveModes.lua for numbered Road and Stage engine maps.

local M = {}
M.type = "auxiliary"

local rpmToAV = 0.104719755

local defaultSettings = {}

local mapsById = {}
local mapsByKey = {}
local firstMapId, lastMapId

local activeDriveMode = nil
local defaultDriveModeKey = nil
local roadGearbox
local shiftPoints, stageShiftPoints

local simpleControlButtons = {}

local stateData
local stateDataNameActiveMode

local function setTurbochargerWastegateOffset(engineName, wastegateOffset)
  local engine = powertrain.getDevice(engineName)
  if not engine or not engine.turbocharger or not engine.turbocharger.setWastegateOffset then
    return
  end

  engine.turbocharger.setWastegateOffset(wastegateOffset)
end

local function updateSimpleControlButton(buttonData)
  -- Treat any non-default mode as engaged
  local active = nil
  if not buttonData.color then
    active = activeDriveMode ~= nil and activeDriveMode.key ~= defaultDriveModeKey
  end
  extensions.ui_simplePowertrainControl.setButton(buttonData.id, buttonData.uiName, buttonData.icon, buttonData.currentColor, nil, buttonData.onClick, nil, active)
end

local function setSimpleControlButton(id, buttonUIName, icon, color, offColor, offColorElectric, onClick, remove)
  if remove then
    simpleControlButtons[id] = nil
    extensions.ui_simplePowertrainControl.setButton(id, nil, nil, nil, nil, nil, true)
  else
    simpleControlButtons[id] = simpleControlButtons[id] or {}
    simpleControlButtons[id].id = id
    simpleControlButtons[id].uiName = buttonUIName
    simpleControlButtons[id].icon = icon
    simpleControlButtons[id].lastColor = nil
    simpleControlButtons[id].currentColor = color
    simpleControlButtons[id].color = color
    simpleControlButtons[id].offColor = offColor or "343434"
    simpleControlButtons[id].offColorElectric = offColorElectric
    simpleControlButtons[id].onClick = onClick or string.format("controller.getController(%q).nextDriveMode()", M.name)
    updateSimpleControlButton(simpleControlButtons[id])
  end
end

local function updateSimpleControlButtons()
  for _, buttonData in pairs(simpleControlButtons) do
    updateSimpleControlButton(buttonData)
  end
end

local function applyDriveMode(mode)
  local isRoad = mode.mapId == 0
  roadGearbox = isRoad and powertrain.getDevice("gearbox") or nil
  for _, setting in pairs(mode.settings) do
    if setting.type == "engine" then
      local engine = powertrain.getDevice(setting.name)
      if engine then
        local maxRPM = setting.maxRPM or engine.maxRPM
        engine.idleAV = (setting.idleRPM or engine.idleRPM) * rpmToAV
        engine.revLimiterAV = maxRPM * rpmToAV
        if shiftPoints then
          local scale = roadGearbox and maxRPM / engine.maxRPM or 1
          for gear = 1, #stageShiftPoints do
            shiftPoints[gear].highShiftUpAV = stageShiftPoints[gear].highShiftUpAV * scale
            shiftPoints[gear].highShiftDownAV = stageShiftPoints[gear].highShiftDownAV * scale
            if roadGearbox and gear > 1 then
              -- Leave room for RPM to drop during the Road upshift cut before asking for a downshift.
              local afterUpshift = shiftPoints[gear - 1].highShiftUpAV * roadGearbox.gearRatios[gear] / roadGearbox.gearRatios[gear - 1]
              shiftPoints[gear].highShiftDownAV = math.min(shiftPoints[gear].highShiftDownAV, afterUpshift * 0.95)
            end
          end
        end

        local engineData = v.data[setting.name] or {}
        -- Shift afterfire uses the same fuel as instant lift-off afterfire.
        engine.instantAfterFireCoef = isRoad and 0 or engineData.instantAfterFireCoef or 0
        engine.sustainedAfterFireTime = isRoad and 0 or engineData.sustainedAfterFireTime or 1.5
        if isRoad then
          engine.sustainedAfterFireTimer = 0
        end
        -- Stage fuel already in the exhaust can still trigger a sound after the MAP change.
        for _, outlet in pairs(engine.thermals.exhaustEndNodes) do
          outlet.astralAfterFireAudioCoef = outlet.astralAfterFireAudioCoef or outlet.afterFireAudioCoef
          outlet.afterFireAudioCoef = isRoad and 0 or outlet.astralAfterFireAudioCoef
        end
        local roughnessAV = (setting.idleRPMRoughness or engineData.idleRPMRoughness or 50) * rpmToAV
        if roughnessAV ~= engine.idleAVReadErrorRange then
          local rate = engineData.idleRPMRoughnessRate or roughnessAV * 2
          engine.idleAVReadErrorRange = roughnessAV
          engine.idleAVReadErrorRangeHalf = roughnessAV * 0.5
          engine.idleAVReadErrorSmoother = newTemporalSmoothing(rate, rate)
          engine.idleAVReadError = 0
        end
      end
    elseif setting.type == "turbocharger" then
      setTurbochargerWastegateOffset(setting.name, setting.wastegateOffset)
    elseif setting.type == "simpleControlButton" then
      setSimpleControlButton(setting.buttonId, setting.uiName or mode.label, setting.icon, setting.color, setting.offColor, setting.offColorElectric, setting.onClick, setting.remove)
    elseif setting.type == "controller" then
      local controller = controller.getController(setting.controllerName)
      if controller and controller.setParameters then
        local controllerSettings = deepcopy(setting)
        controllerSettings.type = nil
        controllerSettings.key = nil
        controllerSettings.controllerName = nil
        controller.setParameters(controllerSettings)
      end
    end
  end
end

local function updateGFX(dt)
  -- The stock sequential controller requests its cut before the gearbox engages the next gear.
  if roadGearbox and roadGearbox.targetGearIndex and roadGearbox.gearIndex > 0
    and roadGearbox.targetGearIndex > roadGearbox.gearIndex and controller.mainController.throttle > 0 then
    powertrain.getDevice("mainEngine"):cutIgnition(0.150)
  end

  for _, buttonData in pairs(simpleControlButtons) do
    local desiredColor = (electrics.values[buttonData.offColorElectric] and electrics.values[buttonData.offColorElectric] >= 1) and buttonData.offColor or buttonData.color
    if desiredColor ~= buttonData.currentColor then
      buttonData.currentColor = desiredColor
      updateSimpleControlButton(buttonData)
    end
  end
end

local function getDriveModeData(idOrKey)
  return mapsById[idOrKey] or mapsByKey[idOrKey]
end

local function setDriveMode(idOrKey, silent)
  local mode = getDriveModeData(idOrKey)
  if mode then
    activeDriveMode = mode
    applyDriveMode(mode)

    local als = mode.settings.dynamicAntiLag
    electrics.values.engineMapNumber = mode.mapId + 1
    electrics.values.engineMapName = mode.name
    electrics.values.engineMapALS = als and als.ALS or -1
    if not silent then
      local message = {txt = "ui.astral.engineMap.notice." .. (als and als.ALS or "none"), context = {map = mode.label}}
      guihooks.message(message, 5, "vehicle.astral.engineMap", "engine")
    end
    return true
  end
end

local function selectMapNumber(number)
  if setDriveMode(number - 1) then
    controller.getControllerSafe("gauge").displayPopupMessage("map", nil, 2)
  end
end

local function cycleDriveMode(direction)
  if not activeDriveMode then return end

  local nextId = direction == 1 and firstMapId or lastMapId
  local nearestDistance = math.huge
  for id in pairs(mapsById) do
    local distance = (id - activeDriveMode.mapId) * direction
    if distance > 0 and distance < nearestDistance then
      nextId = id
      nearestDistance = distance
    end
  end
  selectMapNumber(nextId + 1)
end

local function nextDriveMode()
  cycleDriveMode(1)
end

local function previousDriveMode()
  cycleDriveMode(-1)
end

local function getCurrentDriveModeKey()
  if activeDriveMode then
    return activeDriveMode.key
  end
end

local function resetLastStage()
  if activeDriveMode then
    setDriveMode(activeDriveMode.mapId)
  end
end

local function serialize()
  if activeDriveMode then
    return {mapId = activeDriveMode.mapId}
  end
end

local function deserialize(data)
  if data then
    setDriveMode(data.mapId or data.activeDriveModeKey)
  end
end

local function getState()
  if activeDriveMode then
    stateData[stateDataNameActiveMode] = activeDriveMode.mapId
  end
  return stateData
end

local function setState(data)
  if not data then
    return
  end

  local mode = getDriveModeData(data[stateDataNameActiveMode] or data.driveModesActiveMode)
  if mode and mode ~= activeDriveMode then
    setDriveMode(mode.mapId, true)
  end
end

local function init(jbeamData)
  stateData = {}
  stateDataNameActiveMode = M.name .. "ActiveMode"

  defaultSettings = {}
  if jbeamData.defaultSettings then
    local defaults = jbeamData.defaultSettings
    local defaultSettingData = tableFromHeaderTable(defaults)
    for _, v in pairs(defaultSettingData) do
      local key = v.key or v.controllerName or v.type
      defaultSettings[key] = v
    end
  end

  local modeData = {}
  for k, v in pairs(jbeamData) do
    if k:sub(1, #"modes") == "modes" then
      tableMergeRecursive(modeData, v)
    end
  end

  mapsById, mapsByKey = {}, {}
  firstMapId, lastMapId = nil, nil
  activeDriveMode = nil
  for key, mode in pairs(modeData) do
    local id = mode.mapId
    if type(id) ~= "number" or id < 0 or id % 1 ~= 0 or mapsById[id] then
      error(string.format("Engine map '%s' requires a unique non-negative integer mapId, got %s", key, tostring(id)))
    end

    local map = {
      mapId = id,
      key = key,
      name = mode.name,
      label = string.format("MAP %d: %s", id + 1, mode.name),
      settings = deepcopy(defaultSettings)
    }
    mapsById[id] = map
    mapsByKey[key] = map
    firstMapId = math.min(firstMapId or id, id)
    lastMapId = math.max(lastMapId or id, id)

    for _, setting in pairs(tableFromHeaderTable(mode.settings or {}) or {}) do
      local settingsKey = setting.key or setting.controllerName or setting.type
      map.settings[settingsKey] = setting
    end
  end
end

local function initLastStage(jbeamData)
  local gearbox = powertrain.getDevice("gearbox")
  shiftPoints = gearbox and gearbox.arcadeShiftPoints
  stageShiftPoints = shiftPoints and deepcopy(shiftPoints)
  local mode = getDriveModeData(jbeamData.defaultMode) or mapsById[firstMapId]
  if mode then
    defaultDriveModeKey = mode.key
    setDriveMode(mode.mapId)
  end
end

M.init = init
M.reset = nop -- Keep the selected map for resetLastStage; without reset, BeamNG calls init again.
M.resetLastStage = resetLastStage
M.initLastStage = initLastStage
M.updateGFX = updateGFX
M.serialize = serialize
M.deserialize = deserialize

M.getState = getState
M.setState = setState

M.nextDriveMode = nextDriveMode
M.previousDriveMode = previousDriveMode
M.setDriveMode = setDriveMode
M.selectMapNumber = selectMapNumber
M.getCurrentDriveModeKey = getCurrentDriveModeKey
M.getDriveModeData = getDriveModeData

M.updateSimpleControlButtons = updateSimpleControlButtons
M.setSimpleControlButton = setSimpleControlButton

return M
