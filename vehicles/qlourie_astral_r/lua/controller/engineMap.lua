-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--Purpose: Switches coordinated vehicle settings as driver-selectable drive modes

local M = {}
M.type = "auxiliary"

local defaultIcon = "ESC"

local hasRegisteredQuickAccess = false
local quickAccessTitle
local quickAccessIcon
local radialIcon
local quickAccessLevel

local defaultSettings = {}

local mapsById = {}
local mapsByKey = {}
local firstMapId, lastMapId

local activeDriveMode = nil
local defaultDriveModeKey = nil
local uiName

local simpleControlButtons = {}

local stateData
local stateDataNameActiveMode

local function setExhaustGainMufflingOffset(engineName, mufflingOffset, gainOffset)
  local engine = powertrain.getDevice(engineName)
  if not engine or not engine.setExhaustGainMufflingOffset then
    return
  end

  engine:setExhaustGainMufflingOffset(mufflingOffset, gainOffset)
end

local function setTurbochargerWastegateOffset(engineName, wastegateOffset)
  local engine = powertrain.getDevice(engineName)
  if not engine or not engine.turbocharger or not engine.turbocharger.setWastegateOffset then
    return
  end

  engine.turbocharger.setWastegateOffset(wastegateOffset)
end

local function setSuperchargerBypassPressure(engineName, bypassPressure)
  local engine = powertrain.getDevice(engineName)
  if not engine or not engine.supercharger or not engine.supercharger.setBypassPressure then
    return
  end

  engine.supercharger.setBypassPressure(bypassPressure)
end

local function setGearboxMode(mode)
  if controller.mainController.setDefaultForwardMode then
    controller.mainController.setDefaultForwardMode(mode)
  end
end

local function updateSimpleControlButton(buttonData)
  -- treat any non-default mode as engaged
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

local function modeLabel(name)
  return { txt = name, prefix = "ui.vehicleconfig.modes." }
end

local function modeValue(name)
  return { txt = name, prefix = "ui.vehicleconfig.modeValues." }
end

local function applyDriveMode(mode)
  --dump(mode)
  for _, settingsKey in ipairs(mode.settingsOrder) do
    local setting = mode.settings[settingsKey]

    if setting.type == "exhaust" then
      setExhaustGainMufflingOffset(setting.name, setting.mufflingOffset, setting.gainOffset)
    elseif setting.type == "turbocharger" then
      setTurbochargerWastegateOffset(setting.name, setting.wastegateOffset)
    elseif setting.type == "supercharger" then
      setSuperchargerBypassPressure(setting.name, setting.bypassPressure)
    elseif setting.type == "transmission" then
      setGearboxMode(setting.defaultForwardMode)
    elseif setting.type == "quickAccess" then
      quickAccessIcon = setting.icon or quickAccessIcon
      quickAccessTitle = setting.title or quickAccessTitle
    elseif setting.type == "simpleControlButton" then
      setSimpleControlButton(setting.buttonId, setting.uiName, setting.icon, setting.color, setting.offColor, setting.offColorElectric, setting.onClick, setting.remove)
    elseif setting.type == "controller" then
      local controller = controller.getController(setting.controllerName)
      if controller and controller.setParameters then
        local controllerSettings = deepcopy(setting)
        controllerSettings.type = nil
        controllerSettings.key = nil
        controllerSettings.controllerName = nil
        controller.setParameters(controllerSettings)
      end
    elseif setting.type == "powertrainDeviceMode" then
      local deviceName = setting.deviceName
      local deviceMode = setting.mode
      if deviceName and deviceMode then
        local device = powertrain.getDevice(deviceName)
        if device and device.setMode then
          device:setMode(deviceMode)
        end
      end
    elseif setting.type == "electricsValue" then
      local electricsName = setting.electricsName
      local electricsValue = setting.value
      if electricsName then
        electrics.values[electricsName] = electricsValue
      end
    end
  end
end

local function updateGFX(dt)
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

    if not silent then
      if uiName then
        guihooks.message({txt = "vehicle.driveModes.namedMode", context = {uiName = modeLabel(uiName), mode = modeValue(mode.name)}}, 5, "vehicle.driveModes." .. uiName)
      else
        guihooks.message({txt = "vehicle.driveModes.defaultMode", context = {mode = modeValue(mode.name)}}, 5, "vehicle.driveModes")
      end
    end
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
  setDriveMode(nextId)
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

local function reset(jbeamData)
  quickAccessTitle = jbeamData.quickAccessTitle or "ui.radialmenu2.ESC"
  quickAccessIcon = jbeamData.quickAccessIcon
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

local function registerQuickAccess()
  if not hasRegisteredQuickAccess and firstMapId ~= nil then
    core_quickAccess.addEntry(
      {
        level = "/root/playerVehicle" .. quickAccessLevel,
        generator = function(entries)
          local entry = {
            title = modeLabel(quickAccessTitle),
            desc = {txt = "ui.radialmenu2.currentValueColon", context = {value = modeValue(activeDriveMode.name)}},
            priority = 40,
            uniqueID = "driveModeNext" .. quickAccessTitle,
            onSelect = function()
              controller.getControllerSafe(M.name).nextDriveMode()
              return {"reload"}
            end
          }
          if radialIcon then
            entry.icon = radialIcon
          elseif quickAccessIcon then
            entry.icon = quickAccessIcon
          else
            entry.icon = defaultIcon
          end
          table.insert(entries, entry)
        end
      }
    )
    hasRegisteredQuickAccess = true
  end
end

local function init(jbeamData)
  stateData = {}
  stateDataNameActiveMode = M.name .. "ActiveMode"

  uiName = jbeamData.uiName
  quickAccessTitle = jbeamData.quickAccessTitle or "ui.radialmenu2.ESC"
  quickAccessIcon = jbeamData.quickAccessIcon
  quickAccessLevel = jbeamData.quickAccessLevel or "/vehicleFeatures/"
  radialIcon = jbeamData.radialIcon

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

  local highPrioritySettings = {yawControl = 0, tractionControl = 0}
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
      settings = deepcopy(defaultSettings),
      settingsOrder = {}
    }
    mapsById[id] = map
    mapsByKey[key] = map
    firstMapId = math.min(firstMapId or id, id)
    lastMapId = math.max(lastMapId or id, id)

    for _, setting in pairs(tableFromHeaderTable(mode.settings or {}) or {}) do
      local settingsKey = setting.key or setting.deviceName or setting.electricsName or setting.controllerName or setting.type
      map.settings[settingsKey] = setting
    end
    for settingsKey in pairs(map.settings) do
      table.insert(map.settingsOrder, settingsKey)
    end
    table.sort(map.settingsOrder, function(a, b)
      return (highPrioritySettings[a] or 1) < (highPrioritySettings[b] or 1)
    end)
  end

  registerQuickAccess()
end

local function initLastStage(jbeamData)
  local mode = getDriveModeData(jbeamData.defaultMode) or mapsById[firstMapId]
  if mode then
    defaultDriveModeKey = mode.key
    setDriveMode(mode.mapId)
  end
end

M.init = init
M.reset = reset
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
M.getCurrentDriveModeKey = getCurrentDriveModeKey
M.getDriveModeData = getDriveModeData

M.updateSimpleControlButtons = updateSimpleControlButtons
M.setSimpleControlButton = setSimpleControlButton

return M
