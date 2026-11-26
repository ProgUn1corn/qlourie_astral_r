-- Sends the visible Astral dash readings after multiShiftLights has updated the lamps.
local M = {type = "auxiliary"}

local modeColor = "BBBBBB"
local overlay, overlayUntil
local imperial, hasCodriverDisplay
local lastTick, lastFrame, lastCodriverFrame

local function reset()
  overlay, overlayUntil = nil, 0
  lastTick, lastFrame, lastCodriverFrame = -1, nil, nil
end

local function init(jbeamData)
  imperial = settings.getValue("uiUnitLength") == "imperial"
  hasCodriverDisplay = jbeamData.hasCodriverDisplay
  -- Ctrl+R rebuilds the vehicle while the shared GE renderer can stay loaded.
  obj:queueGameEngineLua([[
    local path = "/lua/ge/extensions/astralNativeDash.lua"
    local hash = FS:hashFileSHA1(path)
    if not extensions.isExtensionLoaded("astralNativeDash") or extensions.astralNativeDash.sourceHash ~= hash then
      extensions.reload("astralNativeDash")
      extensions.astralNativeDash.sourceHash = hash
      log("I", "astralNativeDash", "Loaded " .. FS:getFileRealPath(path) .. " (" .. hash .. ")")
    end
  ]])
  reset()
end

local function displayPopupMessage(name, icon, duration)
  if name == "map" or name == "boost" or name == "launchPreset" then
    overlay, overlayUntil = name, os.clockhp() + duration
    return name
  end
end

local function setParameters(parameters)
  if parameters.modeColor then modeColor = parameters.modeColor end
end

local function updateGFX()
  if not playerInfo.anyPlayerSeated then return end
  local now = os.clockhp()
  local tick = math.floor(now * 60)
  if tick == lastTick then return end
  lastTick = tick

  local e = electrics.values
  local map = e.engineMapNumber or 0
  local powered = (e.ignitionLevel or 0) > 0
  local active = powered and map > 0
  local rpm = math.floor((e.rpm or 0) + 0.5)
  local launch = e.launchArmed == 1
  if not active or launch or now >= overlayUntil then overlay = nil end
  local page = not active and "off" or launch and "launch" or overlay or (map == 1 and "road" or "stage")
  local data = {page = page}
  if page == "stage" or page == "road" then
    data.gear = e.gearIndex or 0
    data.rpm = rpm
    data.map, data.color = map, modeColor
    if page == "stage" then
      data.blue, data.yellow, data.red = e.led0 == 1, e.led1 == 1, e.led2 == 1
    else
      data.speed = math.floor(math.abs(e.wheelspeed or 0) * (imperial and 2.236936 or 3.6) + 0.5)
      data.imperial = imperial
      data.coolant = math.floor((e.watertemp or 0) + 0.5)
      data.fuel = string.format("%.1f", e.fuelVolume or 0)
    end
  elseif page == "launch" then
    data.preset, data.als = e.launchPreset, e.engineMapALS
    data.limit, data.lit = e.launchTargetRPM, e.launchLight == 1
  elseif page == "map" then
    data.map = map
  elseif page == "boost" then
    data.trim = e.boostTrimMbar
  elseif page == "launchPreset" then
    data.preset = e.launchPreset
  end

  local sample = serialize(data)
  local codriverSample
  if hasCodriverDisplay then
    local readings = {page = powered and "codriver" or "off"}
    if powered then
      readings.map, readings.color = map, modeColor
      readings.rpm = rpm
      -- turboBoost is measured gauge pressure in PSI.
      readings.boost = e.turboBoost and string.format("%.2f", e.turboBoost * 0.06894757) or "--"
      readings.coolant = e.watertemp and math.floor(e.watertemp + 0.5)
      readings.oil = e.oiltemp and math.floor(e.oiltemp + 0.5)
      readings.fuel = e.fuelVolume and string.format("%.1f", e.fuelVolume)
    end
    codriverSample = serialize(readings)
  end

  if sample == lastFrame and codriverSample == lastCodriverFrame then return end
  obj:queueGameEngineLua(string.format("extensions.astralNativeDash.update(%d,%s,%s)", obj:getID(),
    sample ~= lastFrame and sample or "nil", codriverSample ~= lastCodriverFrame and codriverSample or "nil"))
  lastFrame, lastCodriverFrame = sample, codriverSample
end

M.init = init
M.reset = reset
M.displayPopupMessage = displayPopupMessage
M.setParameters = setParameters
M.updateGFX = updateGFX
return M
