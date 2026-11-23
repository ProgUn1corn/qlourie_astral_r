-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this file,
-- you can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local mbarToPsi = 0.0145037738
local avToRPM = 30 / math.pi

local engine
local baseBoostPsi, mapOffsetPsi
local targetFractions, closedThrottleBoostByRPM, fullThrottleBoostByRPM, turboPressurePSI
local turboPressureCurve
local freeRevBoostPsi
local boostTrimStepsMbar, trimIndex

local function interpolate(points, input)
  for i = 2, #points do
    local upper = points[i]
    if input <= upper[1] then
      local lower = points[i - 1]
      return linearScale(input, lower[1], upper[1], lower[2], upper[2])
    end
  end
  return points[#points][2]
end

local function updateGFX()
  local values = electrics.values
  local launchActive = values.launchActive == true or values.launchActive == 1
  local basePsi = baseBoostPsi + mapOffsetPsi
  local fraction = interpolate(targetFractions, engine.requestedThrottle)
  local targetPsi
  if launchActive and not turboPressureCurve and values.launchBoostTargetPsi ~= nil then
    targetPsi = values.launchBoostTargetPsi
  else
    if fullThrottleBoostByRPM then
      local rpm = engine.outputAV1 * avToRPM
      local closed = closedThrottleBoostByRPM and interpolate(closedThrottleBoostByRPM, rpm) or 0
      local full = interpolate(fullThrottleBoostByRPM, rpm)
      fraction = closed + fraction * (full - closed)
    end
    -- Rally launch uses the same pedal/RPM surfaces, independently of the race BOOST dial.
    local trimPsi = (launchActive and turboPressureCurve) and 0 or boostTrimStepsMbar[trimIndex] * mbarToPsi
    targetPsi = math.max(0, basePsi * fraction - trimPsi)
    if freeRevBoostPsi and not launchActive and targetPsi > freeRevBoostPsi then
      local engagement = values.gearIndex == 0 and 0 or (values.clutchRatio or 1)
      local rolling = linearScale(math.abs(obj:getGroundSpeed()), 0.5, 4, 0, 1)
      targetPsi = freeRevBoostPsi + (targetPsi - freeRevBoostPsi) * math.max(engagement, rolling)
    end
    local stageRPM = values.stageAlsTargetRPM or 0
    if not turboPressureCurve and not launchActive and stageRPM > 0 then
      -- Let the turbine hold the requested shaft speed within the selected race boost limit.
      local holdPsi = interpolate(turboPressurePSI, stageRPM)
      targetPsi = math.max(targetPsi, math.min(holdPsi, basePsi - trimPsi))
    end
  end

  engine.turbocharger.setWastegateOffset(targetPsi - baseBoostPsi)
  values.boostTargetPsi = targetPsi
  if turboPressureCurve then
    local rpm = 0
    if targetPsi > 0 then
      -- Find the first shaft RPM that reaches this boost on the native turbo's spline.
      local upper = turboPressurePSI[#turboPressurePSI][1]
      while rpm < upper do
        local mid = math.floor((rpm + upper) / 2)
        if turboPressureCurve[mid] < targetPsi then
          rpm = mid + 1
        else
          upper = mid
        end
      end
    end
    values.boostTargetTurboRPM = rpm
  end
  values.boostTrimMbar = boostTrimStepsMbar[trimIndex]
end

local function setParameters(parameters)
  mapOffsetPsi = parameters.mapOffsetPsi
end

local function changeBoostTrim(direction)
  trimIndex = clamp(trimIndex + direction, 1, #boostTrimStepsMbar)
  guihooks.message(string.format("BOOST: %d mbar", -boostTrimStepsMbar[trimIndex]), 2, "vehicle.boost.trim")
end

local function reset()
  engine = powertrain.getDevice("mainEngine")
  electrics.values.boostTargetTurboRPM = turboPressureCurve and 0 or nil
end

local function init(jbeamData)
  baseBoostPsi = jbeamData.baseBoostPsi
  mapOffsetPsi = 0
  targetFractions = jbeamData.targetFractions
  closedThrottleBoostByRPM = jbeamData.closedThrottleBoostByRPM
  freeRevBoostPsi = jbeamData.freeRevBoostPsi
  fullThrottleBoostByRPM = jbeamData.fullThrottleBoostByRPM
  turboPressurePSI = v.data[v.data.mainEngine.turbocharger].pressurePSI
  turboPressureCurve = jbeamData.supplyALSTargetRPM and createCurve(turboPressurePSI, true)
  boostTrimStepsMbar = jbeamData.boostTrimStepsMbar
  trimIndex = 1
  reset()
end

M.init = init
M.reset = reset -- Keep the driver's BOOST selection. engineMap reapplies the MAP offset on reset.
M.updateGFX = updateGFX
M.setParameters = setParameters
M.changeBoostTrim = changeBoostTrim

return M
