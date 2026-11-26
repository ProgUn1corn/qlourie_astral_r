-- Draws the cockpit screen with the vehicle Skia renderer, on its own per-vehicle texture tag.
local M = {}
local black, white, label, line = "#080a0c", "#f6f8fa", "#bcc5ca", "#596169"
local cyan, yellow, red = "#00ccff", "#fff68f", "#ff2701"
local font = "/ui/common/Overpass/static/Overpass-Bold.ttf"
local pages = {}
local pending = {}

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
  if page ~= "off" then add(box(32, 67, 736, 2, line)) end

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
  elseif page == "launch" then
    add(text("LAUNCH CONTROL", 0, 2, 800, 64, 50, "center"))
    add(box(0, 134, 472, 264, black), "panel")
    add(box(472, 134, 2, 264, line))
    add(text("", 0, 170, 472, 195, 152, "center"), "preset")
    add(text("", 474, 153, 326, 94, 72, "center"), "als")
    add(text("", 474, 278, 326, 94, 72, "center"), "limit")
  elseif page == "map" or page == "boost" then
    add(text(page == "map" and "ENGINE MAP" or "BOOST", 0, 2, 800, 64, 50, "center"))
    local value = text("", 8, 147, 784, 186, 152, "center")
    value.fit = "shrink"
    add(value, "value")
  end
  local template = {size = {800, 480}, maps = {"diffuse"}, root = {type = "group", children = c}}
  return {template = template, fields = fields}
end

function M.update(id, data)
  pending[id] = data
end

function M.onPreRender()
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
      if d.page == "stage" or d.page == "road" then
        f.map.text, f.map.color = "MAP " .. d.map, "#" .. d.color
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
      elseif d.page == "launch" then
        f.panel.color = d.lit and red or black
        f.preset.text = "LC " .. d.preset
        f.als.text = d.als < 0 and "" or d.als == 0 and "ALS OFF" or "ALS " .. d.als
        f.limit.text = tostring(d.limit)
      elseif d.page == "map" then
        f.value.text = "MAP " .. d.map
      elseif d.page == "boost" then
        f.value.text = -d.trim .. " mBar"
      end
      vehicle:renderLicensePlateSkia(jsonEncode(page.template), "astraldash")
    end
  end
end

return M
