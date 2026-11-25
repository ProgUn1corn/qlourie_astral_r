-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local sequential = require("controller/vehicleController/shiftLogic/sequentialGearbox")

local function init(jbeamData, sharedFunctions)
  sequential.init(jbeamData, sharedFunctions)
  powertrain.getDevice("gearbox").arcadeShiftPoints = sharedFunctions.getShiftPoints()
end

-- The vehicle controller and the native shift logic both write to the same live state.
return setmetatable({init = init}, {__index = sequential, __newindex = sequential})
