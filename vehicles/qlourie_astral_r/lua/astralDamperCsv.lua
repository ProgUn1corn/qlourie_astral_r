local M = {}

local sampleInterval = 1 / 500
local run

function M.start()
  if run then
    print("Already recording " .. run.path)
    return
  end

  local left, right
  for _, beam in pairs(v.data.beams) do
    if beam.name == "damper_FL" then left = beam.cid end
    if beam.name == "damper_FR" then right = beam.cid end
  end
  if not left or not right then
    print("Recording needs both damper_FL and damper_FR on the selected vehicle.")
    return
  end

  local stem = "front_dampers_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. obj:getID()
  local path = stem .. ".csv"
  local suffix = 1
  while FS:fileExists(path) do
    suffix = suffix + 1
    path = stem .. "_" .. suffix .. ".csv"
  end
  if not writeFile(path, "time_s,fl_velocity_mps,fr_velocity_mps,fl_length_m,fr_length_m\n") then
    print("Could not create " .. path)
    return
  end

  run = {path = path, left = left, right = right, elapsed = 0, nextSample = sampleInterval, count = 0, rows = {}}
  enablePhysicsStepHook()
  print("Recording front dampers at 500 Hz to " .. path)
end

function M.onPhysicsStep(dt)
  if not run then return end
  run.elapsed = run.elapsed + dt
  if run.elapsed + 1e-9 < run.nextSample then return end
  run.nextSample = (math.floor((run.elapsed + 1e-9) / sampleInterval) + 1) * sampleInterval
  run.count = run.count + 1
  run.rows[#run.rows + 1] = string.format("%.6f,%.6f,%.6f,%.6f,%.6f\n", run.elapsed,
    obj:getBeamVelocity(run.left), obj:getBeamVelocity(run.right),
    obj:getBeamLength(run.left), obj:getBeamLength(run.right))
end

local function flushRows()
  if #run.rows == 0 then return true end
  local file, err = io.open(run.path, "a")
  if file then
    local _, writeErr = file:write(table.concat(run.rows))
    local _, closeErr = file:close()
    err = writeErr or closeErr
  end
  if not file or err then
    print("Recording interrupted: " .. run.path .. " (" .. tostring(err) .. ")")
    run = nil
    return false
  end
  run.rows = {}
  return true
end

function M.updateGFX()
  if run and #run.rows >= 250 then flushRows() end
end

function M.stop()
  if not run or not flushRows() then return end
  print(string.format("Saved %d samples (%.3f s) to %s", run.count, run.elapsed, run.path))
  run = nil
end

M.onReset = M.stop
M.onExtensionUnloaded = M.stop

return M
