-- Sends the visible Astral dash readings after multiShiftLights has updated the lamps.
local M = {type = "auxiliary"}

local modeColor = "BBBBBB"
local overlay, overlayUntil
local imperial, hasCodriverDisplay
local codriverPage
local driverReadingsHz, codriverHz = 30, 15
local driverData, lastDriverReadingsTick
local lastCodriverTick, lastCodriverPage
local brakeSplit, brakeSlope, frontPressureGain, rearPressureGain
local corners = {"FL", "FR", "RL", "RR"}
local lastTick, lastFrame, lastCodriverFrame
local testClock, mapPressedAt

local function reset()
  overlay, overlayUntil = nil, 0
  codriverPage = "codriver"
  driverData, lastDriverReadingsTick = {}, -1
  lastCodriverTick, lastCodriverPage = -1, nil
  mapPressedAt = nil
  lastTick, lastFrame, lastCodriverFrame = -1, nil, nil
end

local function init(jbeamData)
  imperial = settings.getValue("uiUnitLength") == "imperial"
  hasCodriverDisplay = jbeamData.hasCodriverDisplay
  if hasCodriverDisplay then
    local tuning = v.data.variables
    local bias = tuning["$brakeBias"]
    local cylinders = v.data.components.brakes
    -- All four service brakes use the same pedal curve, resolved by the wheel system.
    brakeSplit, brakeSlope = 1, 1
    for _, wheel in pairs(wheels.wheels) do
      if wheel.brakeTorque > 0 then
        brakeSplit, brakeSlope = wheel.brakeInputSplit, wheel.brakeSplitCoef
        break
      end
    end
    -- Both bars use front circuit pressure at full pedal as their reference.
    frontPressureGain, rearPressureGain = 0, 0
    if bias and cylinders and cylinders.multiplierMC_F then
      local fullPedalForce = brakeSplit + (1 - brakeSplit) * brakeSlope
      frontPressureGain = 1 / fullPedalForce
      rearPressureGain = frontPressureGain * (1 - bias.val) * (cylinders.multiplierMC_R or 0)
        / (bias.val * cylinders.multiplierMC_F)
    end
  end
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
    -- serialize() keeps ten significant digits for numbers, which rounds Unix time to seconds.
    mapPressedAt = name == "map" and testClock and string.format("%.6f", testClock()) or nil
    overlay, overlayUntil = name, os.clockhp() + duration
    return name
  end
end

local function setParameters(parameters)
  if parameters.modeColor then modeColor = parameters.modeColor end
end

local function cyclePages()
  if hasCodriverDisplay then
    codriverPage = codriverPage == "codriver" and "brakes" or "codriver"
  end
end

local function displaySpeed(wheelspeed)
  return math.floor(math.abs(wheelspeed or 0) * (imperial and 2.236936 or 3.6) + 0.5)
end

local function updateGFX()
  if not playerInfo.anyPlayerSeated then return end
  local now = os.clockhp()
  local tick = math.floor(now * 60)
  if tick == lastTick then return end
  lastTick = tick
  local sampledAt = testClock and testClock()

  local e = electrics.values
  local map = e.engineMapNumber or 0
  local powered = (e.ignitionLevel or 0) > 0
  local active = powered and map > 0
  local rpm = math.floor((e.rpm or 0) + 0.5)
  local launch = e.launchArmed == 1
  if not active or launch or now >= overlayUntil then overlay = nil end
  local page = not active and "off" or launch and "launch" or overlay or (map == 1 and "road" or "stage")
  if driverData.page ~= page then
    driverData, lastDriverReadingsTick = {page = page}, -1
  end
  local data = driverData
  if page == "stage" or page == "road" then
    local readingsTick = math.floor(now * driverReadingsHz)
    if readingsTick ~= lastDriverReadingsTick then
      lastDriverReadingsTick = readingsTick
      data.gear, data.rpm = e.gearIndex or 0, rpm
      if page == "road" then
        data.speed = displaySpeed(e.wheelspeed)
        data.imperial = imperial
        data.coolant = math.floor((e.watertemp or 0) + 0.5)
        data.fuel = string.format("%.1f", e.fuelVolume or 0)
        data.signal_L, data.signal_R = e.signal_L == 1, e.signal_R == 1
        data.lowbeam, data.highbeam = e.lowbeam == 1, e.highbeam == 1
      end
    end
    data.map, data.color = map, modeColor
    -- Keep lamp transitions on the 60 Hz tick even between numeric updates.
    if page == "stage" then
      data.blue, data.yellow, data.red = e.led0 == 1, e.led1 == 1, e.led2 == 1
    end
  elseif page == "launch" then
    data.preset, data.als = e.launchPreset, e.engineMapALS
    data.limit, data.lit = e.launchTargetRPM, e.launchLight == 1
  elseif page == "map" then
    data.map = map
    data.mapPressedAt = mapPressedAt
  elseif page == "boost" then
    data.trim = e.boostTrimMbar
  elseif page == "launchPreset" then
    data.preset = e.launchPreset
  end

  local sample = serialize(data)
  local codriverSample = lastCodriverFrame
  local displayPage = powered and codriverPage or "off"
  local codriverTick = math.floor(now * codriverHz)
  -- Page and ignition changes bypass the telemetry interval.
  if hasCodriverDisplay and (codriverTick ~= lastCodriverTick or displayPage ~= lastCodriverPage) then
    lastCodriverTick, lastCodriverPage = codriverTick, displayPage
    local readings = {page = displayPage}
    if readings.page == "brakes" then
      local pedal = e.brake or 0
      local force = math.min(pedal, brakeSplit) + math.max(0, pedal - brakeSplit) * brakeSlope
      readings.frontPressure = force * frontPressureGain
      readings.rearPressure = force * rearPressureGain
      for _, corner in ipairs(corners) do
        local thermal = e.wheelThermals[corner]
        if thermal then readings[corner] = math.floor(thermal.brakeSurfaceTemperature + 0.5) end
      end
    elseif readings.page == "codriver" then
      readings.map, readings.color = map, modeColor
      readings.speed, readings.imperial = displaySpeed(e.wheelspeed), imperial
      -- turboBoost is measured gauge pressure in PSI.
      readings.boost = e.turboBoost and string.format("%.2f", e.turboBoost * 0.06894757) or "--"
      readings.coolant = e.watertemp and math.floor(e.watertemp + 0.5)
      readings.oil = e.oiltemp and math.floor(e.oiltemp + 0.5)
      readings.fuel = e.fuelVolume and string.format("%.1f", e.fuelVolume)
    end
    codriverSample = serialize(readings)
  end

  if sample == lastFrame and codriverSample == lastCodriverFrame then return end
  local stamp = sampledAt and sample ~= lastFrame and string.format(",%.6f", sampledAt) or ""
  obj:queueGameEngineLua(string.format("extensions.astralNativeDash.update(%d,%s,%s%s)", obj:getID(),
    sample ~= lastFrame and sample or "nil", codriverSample ~= lastCodriverFrame and codriverSample or "nil", stamp))
  lastFrame, lastCodriverFrame = sample, codriverSample
end

M.init = init
M.reset = reset
M.cyclePages = cyclePages
M.displayPopupMessage = displayPopupMessage
M.setParameters = setParameters
M.updateGFX = updateGFX
function M.setLatencyTest(enabled)
  testClock = enabled and require("socket").gettime or nil
  mapPressedAt, lastFrame = nil, nil
end
return M
