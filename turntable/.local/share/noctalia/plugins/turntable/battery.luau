--!nonstrict
-- Nocturne battery: a quiet corner mark, where screenager.dev keeps "new night".
--
--                       2h 41m left  ·  73%  [▮▮▮▮▯]▏
--                       └ hover / click ┘          └ right edge = the widget's right edge
--
-- A horizontal cell that fills on lock, the level in lowercase mono, and (on hover,
-- or pinned with a click) the time left or time to full sliding in from the right. Charging pulses the
-- fill once per second and adds a bolt; low battery turns the cell to error.
-- Everything is right-anchored and sized from the mono advance (0.6 em), so the
-- mark never shifts when the text changes.

local DIR = noctalia.pluginDir()
local MONO = noctalia.loadFont(DIR .. "/fonts/SiteJetBrainsMono.ttf") or "Site JetBrains Mono"
local accent = noctalia.getConfig("accent") or "primary"

-- geometry (logical px) - keep in sync with tools/nocturne_layout.py
local W, H = 220, 20
local FS = 11
local CH = FS * 0.6 -- mono advance
local CELL_W, CELL_H, PAD, NUB_W, NUB_H = 22, 11, 2.2, 2, 5
local CELL_X = W - NUB_W - CELL_W
local CELL_Y = (H - CELL_H) / 2
local GAP = 8
local FAST, SLOW = 33, 1000

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = FAST
local battery = { level = nil, status = "", eta = "" }
local batteryAt = -1e9
local batteryPath = nil
local detailAt = nil -- when the detail last appeared or left
local pinned, hovered = false, false
local function showDetail()
  return pinned or hovered
end

local function clamp01(x)
  return math.clamp(x, 0, 1)
end
local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end
local function phase(t, start, dur)
  return clamp01((t - start) / dur)
end

local function setInterval(ms)
  if ms ~= interval then
    interval = ms
    noctalia.setUpdateInterval(ms)
  end
end

local function readBattery(now)
  if now - batteryAt < 20000 then
    return
  end
  batteryAt = now
  if not batteryPath then
    for _, n in ipairs(noctalia.listDir("/sys/class/power_supply") or {}) do
      if string.match(n, "^BAT") then
        batteryPath = "/sys/class/power_supply/" .. n
        break
      end
    end
  end
  if not batteryPath then
    return
  end
  local function read(f)
    local s = noctalia.readFile(batteryPath .. "/" .. f)
    return s and noctalia.string.trim(s) or nil
  end
  battery.level = tonumber(read "capacity")
  battery.status = string.lower(read "status" or "")
  local energy = tonumber(read "energy_now") or tonumber(read "charge_now")
  local power = tonumber(read "power_now") or tonumber(read "current_now")
  local full = tonumber(read "energy_full") or tonumber(read "charge_full")
  battery.eta = ""
  if energy and power and power > 0 then
    local hours
    if battery.status == "discharging" then
      hours = energy / power
    elseif battery.status == "charging" and full then
      hours = (full - energy) / power
    end
    if hours and hours < 48 then
      local h, m = math.floor(hours), math.floor((hours % 1) * 60)
      battery.eta = h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", m)
    end
  end
end

local function detailText()
  local s = battery.status
  if s == "charging" then
    return battery.eta ~= "" and ("full in " .. battery.eta) or "charging"
  elseif s == "discharging" then
    return battery.eta ~= "" and (battery.eta .. " left") or "on battery"
  elseif s == "full" then
    return "full"
  end
  return s ~= "" and s or "no battery"
end

local function sp(w, h)
  return ui.spacer({ width = math.max(0, w), height = math.max(0, h), flexGrow = 0 })
end

local function place(x, y, child, key)
  y = math.max(0, y)
  return ui.column({ key = key, width = W, height = H, align = "start" }, {
    sp(0, y),
    ui.row({ height = math.max(1, H - y), align = "start" }, { sp(x, 0), child }),
  })
end

-- mono text whose right edge sits at `right`, caps centred on the row
local function textAt(right, text, color, opacity, key)
  return place(right - CH * #text, 0, ui.column({ height = H, justify = "center" }, {
    ui.label({ text = text, fontFamily = MONO, fontSize = FS, color = color, opacity = opacity }),
  }), key)
end

local function render(now)
  local t = now - t0
  local level = battery.level or 0
  local charging = battery.status == "charging"
  local low = level <= 20 and not charging and battery.level ~= nil
  local fillIn = easeOut(phase(t, 1600, 1100))
  local markIn = easeOut(phase(t, 1500, 500))
  local beat = (now % 1000) / 1000
  local pulse = charging and math.sin(math.pi * clamp01(beat / 0.45)) or 0
  local d = detailAt and easeOut((now - detailAt) / 320) or 1
  local detailOpacity = showDetail() and d or (1 - d)

  local q = function(x)
    return math.floor(x * 100)
  end
  local key = table.concat({ level, battery.status, battery.eta, q(fillIn), q(markIn), q(pulse), q(detailOpacity),
    tostring(showDetail()) }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local layers = {}
  local stroke = "outline"
  local fillColor = low and "error" or accent

  -- cell + nub
  layers[#layers + 1] = place(CELL_X, CELL_Y, ui.box({ width = CELL_W, height = CELL_H, radius = 2,
    border = stroke, borderWidth = 1.2, fill = "surface/0" }), "cell")
  layers[#layers + 1] = place(W - NUB_W, (H - NUB_H) / 2, ui.box({ width = NUB_W, height = NUB_H,
    fill = stroke }), "nub")
  local innerW = CELL_W - PAD * 2
  layers[#layers + 1] = place(CELL_X + PAD, CELL_Y + PAD, ui.box({ width = math.max(innerW * level / 100 * fillIn,
    0.01), height = CELL_H - PAD * 2, fill = fillColor, opacity = 0.8 + 0.2 * pulse }), "fill")

  -- level, then (charging) a bolt, then (on click) the detail
  local pct = battery.level and string.format("%d%%", math.floor(level * fillIn + 0.5)) or "--"
  local right = CELL_X - GAP
  layers[#layers + 1] = textAt(right, pct, low and "error" or "on_surface_variant", markIn, "pct")
  right -= CH * #pct + 4
  if charging then
    layers[#layers + 1] = place(right - 10, (H - 10) / 2, ui.glyph({ name = "bolt-filled", size = 10,
      color = accent, opacity = markIn * (0.7 + 0.3 * pulse) }), "bolt")
    right -= 12
  end
  if detailOpacity > 0.001 then
    local text = detailText() .. "  ·"
    layers[#layers + 1] = textAt(right - 2 + 10 * (1 - detailOpacity), text, "outline",
      detailOpacity, "detail")
  end

  -- the whole mark is the toggle
  layers[#layers + 1] = place(0, 0, ui.box({ width = W, height = H, fill = "surface/0",
    onClick = "onBatteryClick", onHover = "onBatteryHover" }), "hit")

  desktopWidget.render(ui.row({ width = W, height = H, gap = -W, align = "start" }, layers))
end

local function tick()
  local now = noctalia.nowMs()
  readBattery(now)
  render(now)
  local moving = now - t0 < 2800 or (detailAt ~= nil and now - detailAt < 360)
  if not moving and battery.status == "charging" then
    -- one beat per second: run fast through the pulse, then sleep to the next one
    local beat = now % 1000
    setInterval(beat < 470 and FAST or (1000 - beat + 5))
    return
  end
  setInterval(moving and FAST or SLOW)
end

local function setDetail(fn)
  local was = showDetail()
  fn()
  if showDetail() ~= was then
    detailAt = noctalia.nowMs()
    batteryAt = -1e9 -- fresh numbers when asked
  end
  tick()
end

function onBatteryClick()
  setDetail(function()
    pinned = not pinned
  end)
end

function onBatteryHover(on)
  setDetail(function()
    hovered = on == "true"
  end)
end

function update()
  tick()
end

readBattery(t0)
noctalia.setUpdateInterval(FAST)
render(t0)
