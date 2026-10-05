--!nonstrict
-- Nocturne clock: the lock screen's time tower, set in screenager.dev's type.
--
--   ┌─────────┬───┬───────────┐
--   │  0  1   │ │ │ monday    │   hours: Figtree Light, one digit per tabular slot
--   │         │ │ │ october 5 │   rail: day and date hang from the hours' cap line
--   │         │ ■ │ week 41   │   divider: a seconds meter, a pixel walking down the hairline
--   │  4  8   │ │ │           │   minutes: Figtree Black, in the site's signal green
--   │         │ │ │ 2 7 pm    │   seconds sit on the minutes' baseline, with am/pm
--   └─────────┴───┴───────────┘
--
-- Every digit morphs into the next: the outlines interpolate, break into
-- dithered pixels halfway (the way the site's night is drawn) and resolve crisp
-- (digits.luau, tools/make_digits.py). Until the frames exist the digits fall
-- back to plain labels.
--
-- Hover the time and the am/pm slot previews the other mode; click to switch
-- 12h / 24h (remembered across locks).
--
-- Layout is absolute: every piece is a full-size layer (stacked with a negative
-- gap) offset by spacers. Noctalia centres a label's cap band in its box, so a
-- label inside a fixed-height frame has its caps at a known y. Spacers default
-- to flexGrow = 1, so every spacer here pins flexGrow = 0.

local Digits = require("./digits.luau")

local DIR = noctalia.pluginDir()
local function font(file, fallback)
  return noctalia.loadFont(DIR .. "/fonts/" .. file) or fallback
end
local LIGHT = font("SiteFigtreeLight.ttf", "Site Figtree Light")
local BLACK = font("SiteFigtreeBlack.ttf", "Site Figtree Black")
local SANS = font("SiteFigtreeRegular.ttf", "Site Figtree Regular")
local STRONG = font("SiteFigtreeSemiBold.ttf", "Site Figtree SemiBold")
local MONO = font("SiteJetBrainsMono.ttf", "Site JetBrains Mono")

local accent = noctalia.getConfig("accent") or "primary"

-- type metrics, as fractions of the font size (from the font files)
local SANS_CAP, MONO_CAP = 0.7, 0.73
local ADV = {
  [LIGHT] = { [0] = 0.638, 0.41, 0.551, 0.539, 0.616, 0.572, 0.56, 0.53, 0.615, 0.56 },
  [BLACK] = { [0] = 0.655, 0.43, 0.597, 0.567, 0.645, 0.587, 0.593, 0.573, 0.61, 0.593 },
}
local FRAME = 1.6 -- a frame this many em tall always holds a label's box

-- geometry (logical px)
local FS, SEC_FS = 168, 72
local CAP = FS * SANS_CAP -- 117.6
local SLOT = 112 -- one digit per slot; the widest black digit is 110
local SEC_SLOT = 46 -- the widest light digit at 72 px
local TIME_W = SLOT * 2
local TOP = math.ceil((FS * FRAME - CAP) / 2) -- hours cap line: room for a label's frame above it
local ROW = CAP + 14 -- row pitch: 14 px of air between the two rows of ink
local BASE = TOP + ROW + CAP -- minutes baseline
local DIV_X = TIME_W + 14
local RAIL_X = DIV_X + 1 + 14
local RAIL_W = 124
local W, H = RAIL_X + RAIL_W, math.ceil(BASE) + 10
local TEXT_FS, TEXT_LEAD, MONO_FS = 18, 26, 11
local ROLL = 22 -- intro rise
local MORPH_MS, SEC_MORPH_MS = 720, 540
local BEAD = 6
local FAST = 33

local PREFS = (noctalia.pluginDataDir() or DIR) .. "/clock.txt"
local use24 = noctalia.string.trim(noctalia.readFile(PREFS) or "") == "24"

-- morph frame sets: hours, minutes, seconds
local sets = {
  Digits.new({ font = "SiteFigtreeLight.ttf", size = FS, role = "on_surface", pixel = 6 }),
  Digits.new({ font = "SiteFigtreeBlack.ttf", size = FS, role = accent, pixel = 6 }),
  Digits.new({ font = "SiteFigtreeLight.ttf", size = SEC_FS, role = accent, pixel = 3 }),
}
local ROWS = {
  { family = LIGHT, size = FS, slot = SLOT, x = 0, color = "on_surface", morph = MORPH_MS, delay = 300 },
  { family = BLACK, size = FS, slot = SLOT, x = 0, color = accent, morph = MORPH_MS, delay = 480 },
  { family = LIGHT, size = SEC_FS, slot = SEC_SLOT, x = RAIL_X, color = accent, morph = SEC_MORPH_MS, delay = 1500 },
}
ROWS[1].capTop = TOP
ROWS[2].capTop = TOP + ROW
ROWS[3].capTop = BASE - SEC_FS * SANS_CAP

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = FAST
local syncAt = -1e9

-- ── state ───────────────────────────────────────────────────────────────────
local digits = { { {}, {} }, { {}, {} }, { {}, {} } } -- [row][slot] = { cur, prev, at, next }
local lastSecond, secondAt, seconds = nil, t0, 0
local modeAt = -1e9 -- last 12h/24h switch, for the rail's mode flash
local hovered, hoverAt = false, -1e9

local function clamp01(x)
  return math.clamp(x, 0, 1)
end
local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end
local function easeInOut(x)
  x = clamp01(x)
  return x < 0.5 and 4 * x * x * x or 1 - (-2 * x + 2) ^ 3 / 2
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

local function hourText(h)
  if use24 then
    return string.format("%02d", h)
  end
  local x = h % 12
  return string.format("%02d", x == 0 and 12 or x)
end
local function twoDigits(v)
  return string.format("%02d", v)
end

-- the first digit at `pos` that differs from now, walking forward through the cycle
local function nextDigit(value, period, fmt, pos)
  local d = string.sub(fmt(value), pos, pos)
  for k = 1, period do
    local c = string.sub(fmt((value + k) % period), pos, pos)
    if c ~= d then
      return c
    end
  end
  return d
end

local untilChange = { { 0, 0 }, { 0, 0 }, { 0, 0 } } -- [row][slot]: seconds until it can next change

local function readClock(now)
  local h = tonumber(noctalia.formatTime "{:%H}") or 0
  local m = tonumber(noctalia.formatTime "{:%M}") or 0
  local s = tonumber(noctalia.formatTime "{:%S}") or 0
  local toHour = (60 - m) * 60 - s
  untilChange = { { toHour, toHour }, { (10 - m % 10) * 60 - s, 60 - s }, { 10 - s % 10, 1 } }
  local units = { { h, 24, hourText }, { m, 60, twoDigits }, { s, 60, twoDigits } }
  for r = 1, 3 do
    local value, period, fmt = units[r][1], units[r][2], units[r][3]
    local text = fmt(value)
    for i = 1, 2 do
      local d = digits[r][i]
      local c = string.sub(text, i, i)
      if d.cur == nil then
        d.cur = c
      elseif d.cur ~= c then
        d.prev, d.cur, d.at = d.cur, c, now
      end
      d.next = nextDigit(value, period, fmt, i)
    end
  end
  if s ~= lastSecond then
    lastSecond, secondAt, seconds = s, now, s
  end
end

-- ── layout helpers ──────────────────────────────────────────────────────────
local function sp(w, h)
  return ui.spacer({ width = math.max(0, w), height = math.max(0, h), flexGrow = 0 })
end

-- a full-size layer with `child` at (x, y)
local function place(x, y, child, key)
  y = math.max(0, y)
  return ui.column({ key = key, width = W, height = H, align = "start" }, {
    sp(0, y),
    ui.row({ height = math.max(1, H - y), align = "start" }, { sp(x, 0), child }),
  })
end

-- a label whose caps start at y
local function capAt(x, y, size, capRatio, label, key)
  local frame = math.ceil(size * FRAME)
  return place(x, y - (frame - size * capRatio) / 2,
    ui.column({ height = frame, justify = "center", align = "start" }, { label }), key)
end

local function text(s, family, size, color, opacity)
  return ui.label({ text = s, fontFamily = family, fontSize = size, color = color, opacity = opacity })
end

-- ── pieces ──────────────────────────────────────────────────────────────────
local function digitLayers(out, r, now, t)
  local row, set = ROWS[r], sets[r]
  for i = 1, 2 do
    local d = digits[r][i]
    local enter = spring(phase(t, row.delay + (i - 1) * 70, 750))
    local p = d.at and easeInOut((now - d.at) / row.morph) or 1
    local capTop = row.capTop + ROLL * (1 - enter)
    local slotX = row.x + (i - 1) * row.slot
    local key = "d" .. r .. i
    if set.ready() then
      local m = set.meta
      out[#out + 1] = place(slotX + (row.slot - m.w) / 2, capTop - m.top,
        set.slot(key, d.prev, d.cur, p, d.next, untilChange[r][i] <= 2, clamp01(enter)), key)
    else -- frames still rendering: crossfade plain labels
      local function x(c)
        return slotX + (row.slot - ADV[row.family][tonumber(c) or 0] * row.size) / 2
      end
      if d.prev and p < 1 then
        out[#out + 1] = capAt(x(d.prev), capTop, row.size, SANS_CAP,
          text(d.prev, row.family, row.size, row.color, (1 - p) * enter), key .. "p")
      end
      out[#out + 1] = capAt(x(d.cur), capTop, row.size, SANS_CAP,
        text(d.cur, row.family, row.size, row.color, clamp01(enter) * ((d.prev and p < 1) and p or 1)), key)
    end
  end
end

-- ── frame ───────────────────────────────────────────────────────────────────
local function render(now)
  local t = now - t0
  local since = now - secondAt
  local divIn = easeOut(phase(t, 900, 800))
  local secFill = (seconds + easeOut(since / 450)) / 60
  local a = {
    easeOut(phase(t, 1100, 500)), -- weekday
    easeOut(phase(t, 1200, 500)), -- date
    easeOut(phase(t, 1300, 500)), -- week
    easeOut(phase(t, 1650, 500)), -- am/pm
  }
  local flash = now - modeAt < 1400
  local hv = easeOut((now - hoverAt) / 200)
  hv = hovered and hv or 1 - hv

  local q = function(x)
    return math.floor(x * 120)
  end
  local key = { q(divIn), q(secFill), tostring(use24), tostring(flash), tostring(hovered), q(hv) }
  for i = 1, 4 do
    key[#key + 1] = q(a[i])
  end
  for r = 1, 3 do
    key[#key + 1] = tostring(sets[r].ready())
    for i = 1, 2 do
      local d = digits[r][i]
      key[#key + 1] = (d.cur or "") .. (d.next or "") .. tostring(untilChange[r][i] <= 2) .. ":"
        .. math.floor((d.at and now - d.at or 9999) / 33)
    end
  end
  key[#key + 1] = math.min(math.floor(t / 33), 120)
  key = table.concat(key, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local layers = {}

  -- time: hours light, minutes black + signal, seconds light + signal on the rail
  for r = 1, 3 do
    digitLayers(layers, r, now, t)
  end

  -- divider = seconds meter: a hairline track, filled down to a square pixel
  local trackH = (BASE - TOP) * divIn
  local filled = trackH * secFill
  layers[#layers + 1] = place(DIV_X, TOP, ui.box({ width = 1, height = math.max(trackH, 0.01),
    fill = "on_surface/0.14" }), "track")
  layers[#layers + 1] = place(DIV_X - 0.25, TOP, ui.box({ width = 1.5, height = math.max(filled, 0.01),
    fill = accent .. "/0.85" }), "fill")
  local bead = BEAD + 2 * hv
  layers[#layers + 1] = place(DIV_X + 0.5 - bead / 2, TOP + filled - bead / 2, ui.box({ width = bead,
    height = bead, fill = accent, opacity = divIn }), "bead")

  -- rail, top: day and date hang from the hours' cap line, the week below in mono
  local textCap = TEXT_FS * SANS_CAP
  layers[#layers + 1] = capAt(RAIL_X, TOP + 6 * (1 - a[1]), TEXT_FS, SANS_CAP,
    text(string.lower(noctalia.formatTime "{:%A}"), STRONG, TEXT_FS, "on_surface", a[1]), "wd")
  local day = tonumber(noctalia.formatTime "{:%d}") or 1
  layers[#layers + 1] = capAt(RAIL_X, TOP + TEXT_LEAD + 6 * (1 - a[2]), TEXT_FS, SANS_CAP,
    text(string.lower(noctalia.formatTime "{:%B}") .. " " .. day, SANS, TEXT_FS, "on_surface_variant", a[2]), "date")
  layers[#layers + 1] = capAt(RAIL_X, TOP + TEXT_LEAD + textCap + 18 + 6 * (1 - a[3]), MONO_FS, MONO_CAP,
    text("week " .. tonumber(noctalia.formatTime "{:%V}"), MONO, MONO_FS, "outline", a[3]), "wk")

  -- rail, bottom: am/pm after the seconds, on the minutes' baseline. After a
  -- switch it names the new mode; while hovered it offers the other one.
  local suffix, suffixColor = use24 and "" or string.lower(noctalia.formatTime "{:%p}"), accent
  if flash then
    suffix, suffixColor = use24 and "24h" or "12h", "on_surface"
  elseif hovered then
    suffix, suffixColor = use24 and "12h" or "24h", "outline"
  end
  layers[#layers + 1] = capAt(RAIL_X + SEC_SLOT * 2 + 6, BASE - MONO_FS * MONO_CAP, MONO_FS, MONO_CAP,
    text(suffix, MONO, MONO_FS, suffixColor, a[4]), "ampm")

  -- the time itself is the 12h/24h switch
  layers[#layers + 1] = place(0, TOP, ui.box({ width = TIME_W, height = BASE - TOP, fill = "surface/0",
    onClick = "onClockClick", onHover = "onClockHover" }), "hit")

  desktopWidget.render(ui.row({ width = W, height = H, gap = -W, align = "start" }, layers))
end

local function animating(now)
  if now - t0 < 2400 or now - modeAt < 1500 or now - hoverAt < 260 then
    return true
  end
  for r = 1, 3 do
    for i = 1, 2 do
      local d = digits[r][i]
      if d.at and now - d.at < ROWS[r].morph + 40 then
        return true
      end
    end
  end
  return now - secondAt < 480
end

local function tick()
  local now = noctalia.nowMs()
  if now - syncAt > 30000 then -- frames follow the palette
    syncAt = now
    for _, set in ipairs(sets) do
      set.sync(function()
        lastKey = ""
      end)
    end
  end
  readClock(now)
  render(now)
  setInterval(animating(now) and FAST or math.max(40, 1000 - (now - secondAt) + 5))
end

function onClockClick()
  use24 = not use24
  modeAt = noctalia.nowMs()
  noctalia.writeFile(PREFS, use24 and "24" or "12")
  tick()
end

function onClockHover(on)
  hovered, hoverAt = on == "true", noctalia.nowMs()
  tick()
end

function update()
  tick()
end

readClock(t0)
noctalia.setUpdateInterval(FAST)
tick()
