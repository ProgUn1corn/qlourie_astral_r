-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this file,
-- you can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.type = "auxiliary"

local mbarToPsi = 0.0145037738

local engine
local baseBoostPsi, mapOffsetPsi
local targetFractions
local boostTrimStepsMbar, trimIndex

local function updateGFX()
  local values = electrics.values
  local launchActive = values.launchActive == true or values.launchActive == 1
  local targetPsi
  if launchActive and values.launchBoostTargetPsi ~= nil then
    targetPsi = values.launchBoostTargetPsi
  else
    local request = engine.requestedThrottle
    local fraction = targetFractions[#targetFractions][2]
    for i = 2, #targetFractions do
      local upper = targetFractions[i]
      if request <= upper[1] then
        local lower = targetFractions[i - 1]
        fraction = linearScale(request, lower[1], upper[1], lower[2], upper[2])
        break
      end
    end
    targetPsi = math.max(0, (baseBoostPsi + mapOffsetPsi) * fraction - boostTrimStepsMbar[trimIndex] * mbarToPsi)
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
  boostTrimStepsMbar = jbeamData.boostTrimStepsMbar
  trimIndex = 1
end

M.init = init
M.reset = reset -- Keep the driver's BOOST selection. engineMap reapplies the MAP offset on reset.
M.updateGFX = updateGFX
M.setParameters = setParameters
M.changeBoostTrim = changeBoostTrim

return M
