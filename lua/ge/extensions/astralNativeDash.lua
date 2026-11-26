-- The driver and co-driver screens use separate per-vehicle Skia textures.
local M = {}
local black, white, label, line = "#080a0c", "#f6f8fa", "#bcc5ca", "#596169"
local cyan, yellow, red = "#00ccff", "#fff68f", "#ff2701"
local font = "/ui/common/Overpass/static/Overpass-Bold.ttf"
local adjustmentTitles = {map = "ENGINE MAP", boost = "BOOST", launchPreset = "LAUNCH CONTROL"}
local pages = {}
local pendingDriver, pendingCodriver = {}, {}

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
  if page ~= "off" and page ~= "codriver" then add(box(32, 67, 736, 2, line)) end

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
    add(text("RPM", 32, 38, 340, 46, 32, "left", label))
    add(text("BOOST_bar", 434, 38, 190, 46, 32, "left", label))
    add(box(622, 35, 146, 48, black, 6), "mapBadge")
    add(text("", 622, 38, 146, 48, 36, "center", black), "map")
    add(text("", 28, 85, 354, 132, 108, "left"), "rpm")
    add(text("", 430, 85, 350, 132, 108, "left", cyan), "boost")

    add(text("COOLANT_°C", 32, 280, 245, 44, 29, "left", label))
    add(text("OIL_°C", 298, 280, 212, 44, 29, "left", label))
    add(text("FUEL_L", 554, 280, 214, 44, 29, "left", label))
    add(text("", 29, 326, 245, 100, 79, "left"), "coolant")
    add(text("", 295, 326, 218, 100, 79, "left"), "oil")
    add(text("", 551, 326, 227, 100, 79, "left"), "fuel")
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

function M.update(id, driver, codriver)
  if driver then pendingDriver[id] = driver end
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
          f.unit.text = d.imperial and "SPEED_mph" or "SPEED_km/h"
          f.speed.text, f.coolant.text, f.fuel.text = tostring(d.speed), tostring(d.coolant), d.fuel
        end
      elseif d.page == "codriver" then
        f.rpm.text, f.boost.text = tostring(d.rpm), d.boost
        f.coolant.text, f.oil.text = tostring(d.coolant or "--"), tostring(d.oil or "--")
        f.fuel.text = d.fuel or "--"
      elseif d.page == "launch" then
        f.panel.color = d.lit and red or black
        f.preset.text = "LC " .. d.preset
        f.als.text = d.als < 0 and "" or d.als == 0 and "ALS OFF" or "ALS " .. d.als
        f.limit.text = tostring(d.limit)
      elseif d.page == "map" then
        f.value.text = "MAP " .. d.map
      elseif d.page == "boost" then
        f.value.text = -d.trim .. " mBar"
      elseif d.page == "launchPreset" then
        f.value.text = "LC " .. d.preset
      end
      vehicle:renderLicensePlateSkia(jsonEncode(page.template), tag)
    end
  end
end

function M.onPreRender()
  drawPending(pendingDriver, "astraldash")
  drawPending(pendingCodriver, "astraldash2")
end

return M
