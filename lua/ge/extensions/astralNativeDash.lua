-- The driver and co-driver screens use separate per-vehicle Skia textures.
local M = {}
local black, white, label, line = "#080a0c", "#f6f8fa", "#bcc5ca", "#596169"
local cyan, yellow, red = "#00ccff", "#fff68f", "#ff2701"
local font = "/ui/common/Overpass/static/Overpass-Bold.ttf"
-- Glyphs from BeamNG's bngIcons font, in Road header order.
local roadIndicators = {
  {signal = "signal_L", glyph = "\xEE\xAF\xBE", color = "#56df81"},
  {signal = "lowbeam",  glyph = "\xEE\xB3\xA2", color = "#56df81"},
  {signal = "highbeam", glyph = "\xEE\xB2\xAB", color = "#559dff"},
  {signal = "signal_R", glyph = "\xEE\xAF\xBF", color = "#56df81"},
}
local adjustmentTitles = {map = "ENGINE MAP", boost = "BOOST LEVEL", launchPreset = "LAUNCH CONTROL"}
local discCorners = {"FL", "FR", "RL", "RR"}
local pressureBarWidth = 368
local pages = {}
local pendingDriver, pendingCodriver = {}, {}
local latencyTest

local function box(x, y, w, h, fill, radius)
  return {type = "box", color = fill, radius = radius,
    style = {position = "absolute", left = x, top = y, width = w, height = h}}
end

local function text(value, x, y, w, h, size, align, fill)
  return {type = "text", text = value, font = font, fontSize = size, textAlign = align, color = fill or white,
    style = {position = "absolute", left = x, top = y, width = w, height = h}}
end

local function build(page)
  local c = {box(0, 0, 800, 480, black)}
  local fields = {}
  local function add(node, key)
    c[#c + 1] = node
    if key then fields[key] = node end
  end
  if page ~= "off" and page ~= "codriver" and page ~= "brakes" then add(box(32, 67, 736, 2, line)) end

  if page == "stage" then
    add(box(0, 0, 800, 86, cyan), "top")
    add(box(0, 86, 800, 84, yellow), "upper")
    add(box(0, 170, 800, 140, red), "center")
    add(box(0, 310, 800, 84, yellow), "lower")
    add(box(0, 394, 800, 86, cyan), "bottom")
    add(box(32, 24, 118, 39, black, 8))
    add(box(656, 24, 112, 39, black, 8))
    add(text("STAGE", 32, 26, 118, 41, 33, "center"))
    add(text("", 656, 29, 112, 38, 27, "center"), "map")
    -- Center the visible glyphs in their bands, accounting for Overpass's baseline.
    add(text("GEAR", 0, 103, 800, 61, 43, "center", label), "gearLabel")
    add(text("", 0, 158, 800, 198, 160, "center"), "gear")
    add(text("", 0, 326, 800, 61, 43, "center"), "rpm")
  elseif page == "road" then
    add(text("ROAD", 32, 12, 300, 44, 33, "left"))
    add(text("", 548, 15, 220, 38, 27, "right"), "map")
    for i, indicator in ipairs(roadIndicators) do
      local icon = text("", 276 + (i - 1) * 64, 8, 56, 52, 48, "center", indicator.color)
      icon.font = "/ui/ui-vue/src/assets/fonts/bngIcons/bngIcons.ttf"
      add(icon, indicator.signal)
    end
    add(box(510, 83, 1, 264, "#465058"))
    add(box(32, 362, 736, 2, line))
    add(text("", 32, 98, 440, 34, 23, "left", label), "unit")
    add(text("", 32, 122, 450, 180, 152, "left"), "speed")
    add(text("GEAR", 536, 101, 232, 33, 23, "left", label))
    add(text("", 536, 128, 232, 65, 52, "left"), "gear")
    add(text("RPM", 536, 232, 232, 33, 23, "left", label))
    add(text("", 536, 259, 232, 65, 52, "left"), "rpm")
    add(text("COOLANT_°C", 32, 371, 365, 34, 23, "left", label))
    add(text("FUEL_L", 412, 371, 350, 34, 23, "left", label))
    add(text("", 32, 397, 360, 62, 46, "left"), "coolant")
    add(text("", 412, 397, 350, 62, 46, "left"), "fuel")
  elseif page == "codriver" then
    add(box(402, 42, 2, 168, line))
    add(box(32, 242, 736, 2, line))
    add(text("", 32, 38, 340, 46, 32, "left", label), "unit")
    add(text("BOOST_bar", 434, 38, 190, 46, 32, "left", label))
    add(box(622, 35, 146, 48, black, 6), "mapBadge")
    add(text("", 622, 38, 146, 48, 36, "center", black), "map")
    add(text("", 28, 85, 354, 132, 108, "left"), "speed")
    add(text("", 430, 85, 350, 132, 108, "left", cyan), "boost")

    add(text("COOLANT_°C", 32, 280, 245, 44, 29, "left", label))
    add(text("OIL_°C", 298, 280, 212, 44, 29, "left", label))
    add(text("FUEL_L", 554, 280, 214, 44, 29, "left", label))
    add(text("", 29, 326, 245, 100, 79, "left"), "coolant")
    add(text("", 295, 326, 218, 100, 79, "left"), "oil")
    add(text("", 551, 326, 227, 100, 79, "left"), "fuel")
  elseif page == "brakes" then
    add(box(379, 42, 2, 392, line))
    add(text("DISC TEMP_°C", 32, 38, 350, 44, 29, "left", label))
    for i, corner in ipairs(discCorners) do
      local x = (i % 2 == 1) and 32 or 215
      local y = i <= 2 and 100 or 274
      add(text(corner, x, y, 158, 38, 26, "left", label))
      add(text("", x, y + 36, 170, 94, 64, "left"), corner)
    end
    for i, axle in ipairs({"front", "rear"}) do
      local y = i == 1 and 38 or 252
      add(text(string.upper(axle) .. " BRAKE PRESSURE", 400, y, pressureBarWidth, 44, 29, "left", label))
      add(box(400, y + 80, pressureBarWidth, 34, "#30383e"))
      add(box(400, y + 80, 0, 34, cyan), axle)
    end
  elseif page == "launch" then
    add(text("LAUNCH READY", 0, 2, 800, 64, 50, "center"))
    add(box(0, 134, 472, 264, black), "panel")
    add(box(472, 134, 2, 264, line))
    add(text("", 0, 170, 472, 195, 152, "center"), "preset")
    add(text("", 474, 153, 326, 94, 72, "center"), "als")
    add(text("", 474, 278, 326, 94, 72, "center"), "limit")
  elseif adjustmentTitles[page] then
    add(text(adjustmentTitles[page], 0, 2, 800, 64, 50, "center"))
    local value = text("", 8, 147, 784, 186, 152, "center")
    value.fit = "shrink"
    add(value, "value")
  end
  local template = {size = {800, 480}, maps = {"diffuse"}, root = {type = "group", children = c}}
  return {template = template, fields = fields}
end

function M.setLatencyTest(enabled)
  if latencyTest then
    local previous = be:getObjectByID(latencyTest.id)
    if previous then previous:queueLuaCommand('controller.getController("gauge").setLatencyTest(false)') end
    log("I", "astralDashProbe", string.format("Stop: %d submitted, %d rejected, peak PRE %.0f ms",
      latencyTest.frame, latencyTest.rejected, latencyTest.peak))
    latencyTest = nil
  end
  if not enabled then return end
  local vehicle = be:getPlayerVehicle(0)
  if not vehicle or vehicle.JBeam ~= "qlourie_astral_r" then
    log("W", "astralDashProbe", "Select the Astral before starting the dash test.")
    return
  end
  local clock = require("socket").gettime
  latencyTest = {id = vehicle:getID(), clock = clock, start = clock(), frame = 0, rejected = 0, peak = 0,
    hud = "ASTRAL DASH   Waiting for the first sample", pos = vec3(32, 120, 0),
    fg = ColorF(1, 1, 1, 1), bg = ColorI(0, 0, 0, 225),
    badge = box(20, 440, 350, 38, black), stamp = text("", 28, 442, 336, 38, 28, "left", cyan)}
  vehicle:queueLuaCommand('controller.getController("gauge").setLatencyTest(true)')
  log("I", "astralDashProbe", "Started. The driver screen and HUD show the same submission ID and time.")
end

function M.update(id, driver, codriver, sampledAt)
  if driver then
    driver.sampledAt = sampledAt
    if driver.mapPressedAt then driver.mapPressedAt = tonumber(driver.mapPressedAt) end
    pendingDriver[id] = driver
    if driver.mapPressedAt and latencyTest and id == latencyTest.id then
      log("I", "astralDashProbe", string.format("MAP %d: key to GE %.0f ms",
        driver.map, (latencyTest.clock() - driver.mapPressedAt) * 1000))
    end
  end
  if codriver then pendingCodriver[id] = codriver end
end

local function drawPending(pending, tag)
  for id, d in pairs(pending) do
    pending[id] = nil
    local vehicle = be:getObjectByID(id)
    if vehicle then
      local page = pages[d.page]
      if not page then
        page = build(d.page)
        pages[d.page] = page
      end
      local f = page.fields
      if f.map then
        f.map.text = d.map > 0 and "MAP " .. d.map or ""
        if f.mapBadge then
          f.mapBadge.color = d.map > 0 and "#" .. d.color or black
        else
          f.map.color = "#" .. d.color
        end
      end
      if f.speed then
        f.unit.text = d.imperial and "SPEED_mph" or "SPEED_km/h"
        f.speed.text = tostring(d.speed)
      end
      if d.page == "stage" or d.page == "road" then
        f.gear.text = d.gear < 0 and "R" or d.gear == 0 and "N" or tostring(d.gear)
        f.rpm.text = tostring(d.rpm)
        if d.page == "stage" then
          f.top.color = d.blue and cyan or "#00000000"
          f.bottom.color = f.top.color
          f.upper.color = d.yellow and yellow or "#00000000"
          f.lower.color = f.upper.color
          f.center.color = d.red and red or "#00000000"
          f.gearLabel.color = d.yellow and "#202428" or label
          f.rpm.color = d.yellow and "#202428" or white
        else
          for _, indicator in ipairs(roadIndicators) do
            f[indicator.signal].text = d[indicator.signal] and indicator.glyph or ""
          end
          f.coolant.text, f.fuel.text = tostring(d.coolant), d.fuel
        end
      elseif d.page == "codriver" then
        f.boost.text = d.boost
        f.coolant.text, f.oil.text = tostring(d.coolant or "--"), tostring(d.oil or "--")
        f.fuel.text = d.fuel or "--"
      elseif d.page == "brakes" then
        for _, corner in ipairs(discCorners) do
          f[corner].text = tostring(d[corner] or "--")
        end
        f.front.style.width = math.floor(d.frontPressure * pressureBarWidth + 0.5)
        f.rear.style.width = math.floor(math.min(d.rearPressure, 1) * pressureBarWidth + 0.5)
      elseif d.page == "launch" then
        f.panel.color = d.lit and red or black
        f.preset.text = "LC " .. d.preset
        f.als.text = d.als < 0 and "" or d.als == 0 and "ALS OFF" or "ALS " .. d.als
        f.limit.text = tostring(d.limit)
      elseif d.page == "map" then
        f.value.text = "MAP " .. d.map
      elseif d.page == "boost" then
        f.value.text = string.format("%d mBar", -d.trim)
      elseif d.page == "launchPreset" then
        f.value.text = "LC " .. d.preset
      end
      local probe = latencyTest
      if probe and id == probe.id and tag == "astraldash" and d.sampledAt then
        local children = page.template.root.children
        local n = #children
        local idTime = string.format("#%d  %.2f s", probe.frame + 1, probe.clock() - probe.start)
        probe.stamp.text = idTime
        children[n + 1], children[n + 2] = probe.badge, probe.stamp
        local payload = jsonEncode(page.template)
        children[n + 1], children[n + 2] = nil, nil
        local submitTime = probe.clock()
        if vehicle:renderLicensePlateSkia(payload, tag) then
          local pre = (submitTime - d.sampledAt) * 1000
          probe.frame = probe.frame + 1
          probe.peak = math.max(probe.peak, pre)
          probe.hud = string.format("ASTRAL DASH   SENT %s   PRE %.0f ms   PEAK %.0f ms", idTime, pre, probe.peak)
          if d.mapPressedAt then
            log("I", "astralDashProbe", string.format("MAP %d %s: key to submit %.0f ms, PRE %.0f ms",
              d.map, idTime, (submitTime - d.mapPressedAt) * 1000, pre))
          end
        else
          probe.rejected = probe.rejected + 1
          probe.hud = string.format("ASTRAL DASH   submission rejected (%d)", probe.rejected)
        end
      else
        vehicle:renderLicensePlateSkia(jsonEncode(page.template), tag)
      end
    end
  end
end

function M.onPreRender()
  drawPending(pendingDriver, "astraldash")
  drawPending(pendingCodriver, "astraldash2")
  if latencyTest then
    debugDrawer:drawTextAdvanced(latencyTest.pos, latencyTest.hud, latencyTest.fg, false, true, latencyTest.bg)
  end
end

local function logPhysicsMarker(state)
  if latencyTest then
    log("I", "astralDashProbe", string.format("Physics %s at %.2f s | %s",
      state, latencyTest.clock() - latencyTest.start, latencyTest.hud))
  end
end

function M.onPhysicsPaused() logPhysicsMarker("paused") end
function M.onPhysicsUnpaused() logPhysicsMarker("resumed") end

return M
