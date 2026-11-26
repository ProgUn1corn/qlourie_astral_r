-- Sends the visible Astral dash readings after multiShiftLights has updated the lamps.
local M = {type = "auxiliary"}

local modeColor = "BBBBBB"
local overlay, overlayUntil
local imperial
local lastTick, lastFrame

local function reset()
  overlay, overlayUntil = nil, 0
  lastTick, lastFrame = -1, nil
end

local function init()
  imperial = settings.getValue("uiUnitLength") == "imperial"
  obj:queueGameEngineLua("extensions.load('astralNativeDash')")
  reset()
end

local function displayPopupMessage(name, icon, duration)
  if name == "map" or name == "boost" then
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
  local active = (e.ignitionLevel or 0) > 0 and map > 0
  local launch = e.launchActive == 1
  if not active or launch or now >= overlayUntil then overlay = nil end
  local page = not active and "off" or launch and "launch" or overlay or (map == 1 and "road" or "stage")
  local data = {page = page}
  if page == "stage" or page == "road" then
    data.gear = e.gearIndex or 0
    data.rpm = math.floor((e.rpm or 0) + 0.5)
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
  end

  local sample = serialize(data)
  if sample == lastFrame then return end
  lastFrame = sample
  obj:queueGameEngineLua(string.format("extensions.astralNativeDash.update(%d,%s)", obj:getID(), sample))
end

M.init = init
M.reset = reset
M.displayPopupMessage = displayPopupMessage
M.setParameters = setParameters
M.updateGFX = updateGFX
return M
