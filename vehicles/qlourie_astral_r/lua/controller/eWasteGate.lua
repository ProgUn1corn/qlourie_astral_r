-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this file,
-- you can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local mbarToPsi = 0.0145037738
local avToRPM = 30 / math.pi

local engine
local baseBoostPsi, mapOffsetPsi
local targetFractions, fullThrottleBoostByRPM, turboPressurePSI
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
  local targetPsi
  if launchActive and values.launchBoostTargetPsi ~= nil then
    targetPsi = values.launchBoostTargetPsi
  else
    local fraction = interpolate(targetFractions, engine.requestedThrottle)
    if fullThrottleBoostByRPM and not launchActive then
      fraction = fraction * interpolate(fullThrottleBoostByRPM, engine.outputAV1 * avToRPM)
    end
    local basePsi = baseBoostPsi + mapOffsetPsi
    local trimPsi = boostTrimStepsMbar[trimIndex] * mbarToPsi
    targetPsi = math.max(0, basePsi * fraction - trimPsi)
    local stageRPM = values.stageAlsTargetRPM or 0
    if not launchActive and stageRPM > 0 then
      -- Let the turbine hold the requested shaft speed within the selected race boost limit.
      local holdPsi = interpolate(turboPressurePSI, stageRPM)
      targetPsi = math.max(targetPsi, math.min(holdPsi, basePsi - trimPsi))
    end
  end

  engine.turbocharger.setWastegateOffset(targetPsi - baseBoostPsi)
  values.boostTargetPsi = targetPsi
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
end

local function init(jbeamData)
  reset()
  baseBoostPsi = jbeamData.baseBoostPsi
  mapOffsetPsi = 0
  targetFractions = jbeamData.targetFractions
  fullThrottleBoostByRPM = jbeamData.fullThrottleBoostByRPM
  turboPressurePSI = v.data[v.data.mainEngine.turbocharger].pressurePSI
  boostTrimStepsMbar = jbeamData.boostTrimStepsMbar
  trimIndex = 1
end

M.init = init
M.reset = reset -- Keep the driver's BOOST selection. engineMap reapplies the MAP offset on reset.
M.updateGFX = updateGFX
M.setParameters = setParameters
M.changeBoostTrim = changeBoostTrim

return M
