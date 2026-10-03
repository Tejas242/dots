--!nonstrict
-- Nocturne clock: the lock screen's left column as one typographic block.
--
--   ┌──────────┬─────────┐
--   │ 09  thin │ PM      │   hours: hairline condensed display face
--   │          │ SAT     │   minutes: the same face at its heaviest, in accent
--   │ 58  black│ 03      │   divider: doubles as a seconds meter (fills down)
--   │          │ OCT     │   rail: am/pm, a calendar block, a battery cell
--   │          │ ▯ 97%   │
--   └──────────┴─────────┘
--   welcome back, screenager   (typed)
--
-- Motion: staggered intro (digits rise, divider draws, rail fades in, battery
-- fills), per-digit odometer roll on change, and one soft beat per second
-- (seconds meter + charging pulse). The timer only runs fast while something
-- moves; otherwise it sleeps until the next second. No transforms exist in the
-- plugin UI, so motion is translate (spacer offsets) + opacity inside
-- fixed-size slots, keeping the widget's natural size constant.

local DIR = noctalia.pluginDir()
local function font(file, fallback)
  return noctalia.loadFont(DIR .. "/fonts/" .. file) or fallback
end
local THIN = font("NocturneDisplayLight.ttf", "Nocturne Display Light")
local BLACK = font("NocturneDisplayBlack.ttf", "Nocturne Display Black")
local LIGHT = font("NocturneSansLight.ttf", "Nocturne Sans Light")
local MONO = font("NocturneMono.ttf", "Nocturne Mono")

local greeting = noctalia.getConfig("greeting") or "welcome back, screenager"
local accent = noctalia.getConfig("accent") or "primary"

-- geometry (logical px), measured from the font at FS
local FS = 180
local INK_TOP = 69            -- first ink row below the label top (as Noctalia lays text out)
local INK_H = 144             -- cap height of the digits
local ROW = 158               -- row pitch: 14 px of air between the two rows of ink
local BLACK_W = 92            -- widest black digit, so the minutes row never reflows
local ROLL = 30               -- odometer travel
local DIV_X_GAP = 18
local RAIL_W = 92
local TIME_W = BLACK_W * 2
local W = TIME_W + DIV_X_GAP * 2 + 1 + RAIL_W
local DIV_H = ROW + INK_H -- hours ink top .. minutes ink bottom
local BLOCK_H = ROW + INK_TOP + INK_H + 10
local FAST, SLOW = 33, 1000

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = FAST

-- ── state ───────────────────────────────────────────────────────────────────
local rows = { {}, {} } -- hours, minutes: whole rows keep the font's own spacing
local lastSecond, secondAt, seconds = nil, t0, 0
local battery = { level = nil, status = "", eta = "" }
local batteryAt = -1e9
local batteryPath = nil

local function clamp01(x)
  return math.clamp(x, 0, 1)
end
local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end
local function spring(x) -- step response with a soft overshoot
  x = clamp01(x)
  return 1 - math.exp(-6 * x) * math.cos(9 * x)
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
  if now - batteryAt < 30000 then
    return
  end
  batteryAt = now
  if not batteryPath then
    for _, name in ipairs(noctalia.listDir("/sys/class/power_supply") or {}) do
      if string.match(name, "^BAT") then
        batteryPath = "/sys/class/power_supply/" .. name
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
  local energy, power = tonumber(read "energy_now"), tonumber(read "power_now")
  local full = tonumber(read "energy_full")
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

local function readClock(now)
  local values = { noctalia.formatTime "{:%I}", noctalia.formatTime "{:%M}" }
  for i = 1, 2 do
    local r = rows[i]
    if r.cur == nil then
      r.cur = values[i]
    elseif r.cur ~= values[i] then
      r.prev, r.cur, r.rollAt = r.cur, values[i], now
    end
  end
  local s = noctalia.formatTime "{:%S}"
  if s ~= lastSecond then
    lastSecond, secondAt, seconds = s, now, tonumber(s) or 0
  end
end

-- ── pieces ──────────────────────────────────────────────────────────────────
local function shifted(dy, h, child, key)
  return ui.column({ key = key, height = h, align = "start" }, {
    ui.spacer({ height = math.max(0, dy) }),
    child,
  })
end

-- one time row: the old value fades in place while the new one rises in (odometer)
local function timeRow(i, now, t, family, color, delay)
  local r = rows[i]
  local enter = spring(phase(t, delay, 750))
  local roll = r.rollAt and easeOut((now - r.rollAt) / 560) or 1
  local base = ROLL * (1 - enter)
  local layers = {}
  if r.prev and roll < 1 then
    layers[#layers + 1] = shifted(base, ROW, ui.label({ text = r.prev, fontFamily = family, fontSize = FS,
      color = color, width = TIME_W, opacity = (1 - roll) * enter }), "p" .. i)
  end
  layers[#layers + 1] = shifted(base + ROLL * (1 - roll), ROW, ui.label({ text = r.cur or "", fontFamily = family,
    fontSize = FS, color = color, width = TIME_W,
    opacity = enter * ((r.prev and roll < 1) and roll or 1) }), "c" .. i)
  return ui.row({ key = "row" .. i, width = TIME_W, height = ROW, gap = -TIME_W, align = "start" }, layers)
end

local function railText(text, size, color, opacity, family, key)
  return ui.label({ key = key, text = text, fontFamily = family or MONO, fontSize = size, color = color,
    opacity = opacity })
end

local function batteryCell(t, now)
  local level = battery.level or 0
  local fillIn = easeOut(phase(t, 1500, 1100))
  local low = level <= 20 and battery.status ~= "charging"
  local fillColor = low and "error" or accent
  local charging = battery.status == "charging"
  -- charging: the top of the fill breathes once per second with the clock
  local since = now - secondAt
  local pulse = (charging and since < 450) and math.sin(math.pi * since / 450) or 0

  local CELL_W, CELL_H, PAD = 22, 50, 3
  local inner = CELL_H - PAD * 2
  local fillH = math.max(inner * (level / 100) * fillIn, 0.01)
  local cell = ui.column({ key = "battery", width = CELL_W, height = CELL_H + 4, align = "center" }, {
    ui.box({ width = 8, height = 3, radius = 1, fill = "on_surface/0.45" }),
    ui.spacer({ height = 1 }),
    ui.column({ width = CELL_W, height = CELL_H, padding = PAD, radius = 5, border = "on_surface/0.45",
      borderWidth = 1.2, justify = "end", align = "center" }, {
      ui.box({ width = CELL_W - PAD * 2 - 2.4, height = fillH, radius = 2, fill = fillColor,
        opacity = 0.75 + 0.25 * pulse }),
    }),
  })
  local label = battery.level and string.format("%d%%", math.floor(level * fillIn + 0.5)) or "—"
  local sub = charging and (battery.eta ~= "" and ("+" .. battery.eta) or "charging")
    or (battery.eta ~= "" and battery.eta or battery.status)
  return ui.row({ key = "batt", gap = 10, align = "end" }, {
    cell,
    ui.column({ gap = 2, align = "start" }, {
      railText(label, 15, low and "error" or "on_surface", 1, MONO, "bl"),
      railText(sub, 10, "on_surface_variant", 0.85, MONO, "bs"),
    }),
  })
end

-- ── frame ───────────────────────────────────────────────────────────────────
local function render(now)
  local t = now - t0
  local since = now - secondAt
  local divIn = easeOut(phase(t, 900, 800))
  local secFill = (seconds + easeOut(since / 450)) / 60
  local a = {
    easeOut(phase(t, 1100, 500)), -- am/pm
    easeOut(phase(t, 1200, 500)), -- weekday
    spring(phase(t, 1300, 600)), -- day number
    easeOut(phase(t, 1400, 500)), -- month
    easeOut(phase(t, 1500, 600)), -- battery
  }
  local typed = math.floor(clamp01((t - 2100) / (30 * #greeting)) * #greeting + 0.5)
  local caretOn = t < 2100 + 30 * #greeting + 900 and (math.floor(now / 420) % 2 == 0)

  local q = function(x)
    return math.floor(x * 120)
  end
  local key = { q(divIn), q(secFill), typed, tostring(caretOn), battery.level or -1, battery.status, battery.eta }
  for i = 1, 5 do
    key[#key + 1] = q(a[i])
  end
  for i = 1, 2 do
    local r = rows[i]
    key[#key + 1] = (r.cur or "") .. ":" .. math.floor((r.rollAt and now - r.rollAt or 9999) / 33)
  end
  key[#key + 1] = math.min(math.floor(t / 33), 120)
  key[#key + 1] = since < 450 and math.floor(since / 33) or -1
  key = table.concat(key, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  -- time: hours in hairline, minutes in black + accent, rows overlapping their empty descent
  local hours = timeRow(1, now, t, THIN, "on_surface", 300)
  local minutes = timeRow(2, now, t, BLACK, accent, 480)
  local time = ui.column({ key = "time", width = TIME_W, height = BLOCK_H, align = "start" }, { hours, minutes })

  -- divider = seconds meter: a hairline track that fills top-down
  local trackH = DIV_H * divIn
  local filled = trackH * secFill
  local divider = ui.column({ key = "div", width = 1, height = BLOCK_H, align = "center" }, {
    ui.spacer({ height = INK_TOP }),
    ui.box({ width = 1.5, height = math.max(filled, 0.01), fill = accent }),
    ui.box({ width = 1, height = math.max(trackH - filled, 0.01), fill = "on_surface/0.16" }),
  })

  -- rail: every entry lives in a fixed-height row, so positions are exact:
  -- the calendar hangs from the hours' top edge, the battery sits on the
  -- minutes' baseline (cell is 54 px tall)
  local function fixed(h, child, key)
    return ui.row({ key = key, height = h, align = "start" }, { child })
  end
  local AMPM_Y, WD_Y, DAY_H, LINE = INK_TOP + 2, INK_TOP + 50, 72, 18
  local batteryY = ROW + INK_TOP + INK_H - 54
  local monthEnd = WD_Y + LINE + DAY_H + LINE
  local rail = ui.column({ key = "rail", width = RAIL_W, height = BLOCK_H, align = "start", justify = "start" }, {
    ui.spacer({ height = AMPM_Y }),
    fixed(LINE, railText(string.upper(noctalia.formatTime "{:%p}"), 13, accent, a[1], MONO, "ampm"), "r1"),
    ui.spacer({ height = WD_Y - AMPM_Y - LINE }),
    fixed(LINE, railText(string.upper(noctalia.formatTime "{:%a}"), 13, "on_surface_variant", a[2], MONO, "wd"), "r2"),
    fixed(DAY_H, shifted(10 * (1 - a[3]), DAY_H,
      railText(noctalia.formatTime "{:%d}", 56, "on_surface", clamp01(a[3]), BLACK, "dn")), "r3"),
    fixed(LINE, railText(string.upper(noctalia.formatTime "{:%b}"), 13, "on_surface_variant", a[4], MONO, "mo"), "r4"),
    ui.spacer({ height = math.max(0, batteryY - monthEnd) }),
    ui.column({ key = "battwrap", height = 54, opacity = a[5] }, { batteryCell(t, now) }),
  })

  local block = ui.row({ key = "block", height = BLOCK_H, gap = DIV_X_GAP, align = "start" }, { time, divider, rail })

  local greet = ui.row({ key = "greet", height = 26, align = "center" }, {
    ui.label({ text = string.sub(greeting, 1, typed), fontFamily = LIGHT, fontSize = 17, color = "on_surface" }),
    ui.box({ width = 2, height = 17, fill = accent, opacity = caretOn and 0.9 or 0 }),
  })

  desktopWidget.render(ui.column({ width = W, align = "start" }, {
    block,
    ui.spacer({ height = 12 }),
    greet,
  }))
end

local function animating(now)
  if now - t0 < 2100 + 30 * #greeting + 1300 then
    return true
  end
  for i = 1, 2 do
    if rows[i].rollAt and now - rows[i].rollAt < 600 then
      return true
    end
  end
  return now - secondAt < 480
end

function update()
  local now = noctalia.nowMs()
  readClock(now)
  readBattery(now)
  render(now)
  setInterval(animating(now) and FAST or math.max(40, 1000 - (now - secondAt) + 5))
end

readClock(t0)
for i = 1, 2 do
  rows[i].prev, rows[i].rollAt = nil, nil
end
readBattery(t0)
noctalia.setUpdateInterval(FAST)
render(t0)
