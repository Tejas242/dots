--!nonstrict
-- Nocturne clock: the lock screen's time column, with motion.
--
--   intro   staggered entrance (dot, weekday, digits rise one by one, hairline
--           draws, date, then the greeting types itself out with a caret)
--   minute  only the digits that change roll: old slides up and fades while the
--           new one rises in (odometer cross-fade)
--   second  the colon breathes and the hairline under the time fills per minute
--
-- No transforms exist in the plugin UI, so motion is translate (spacer offsets)
-- + opacity inside fixed-size slots: the widget's natural size never changes,
-- which keeps the lock-screen box fit stable. The timer runs at ~30 Hz only
-- while something animates (intro, rolls, the 450 ms colon fade each second).

local DIR = noctalia.pluginDir()
local THIN = noctalia.loadFont(DIR .. "/fonts/NocturneSansExtraLight.ttf") or "Nocturne Sans ExtraLight"
local LIGHT = noctalia.loadFont(DIR .. "/fonts/NocturneSansLight.ttf") or "Nocturne Sans Light"
local MONO = noctalia.loadFont(DIR .. "/fonts/NocturneMono.ttf") or "Nocturne Mono"

local greeting = noctalia.getConfig("greeting") or "welcome back, screenager"
local accent = noctalia.getConfig("accent") or "primary"

-- layout (logical px)
local W = 460
local FS = 132              -- time font size
local SLOT_W, COLON_W = 76, 34
local SLOT_H = 158
local ROLL = 34             -- roll travel
local FAST, SLOW = 33, 1000

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = SLOW

-- digit state: current text, previous text, roll start time per slot
local digits = { {}, {}, {}, {} }
local lastSecond = nil
local secondAt = t0
local seconds = 0

local function clamp01(x)
  return math.clamp(x, 0, 1)
end

local function easeOutCubic(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end

-- critically-ish damped spring step response with a little overshoot
local function spring(x)
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

local function shifted(dy, h, child, key)
  -- place `child` dy px below the slot top inside a fixed-height column
  return ui.column({ key = key, height = h, align = "start" }, {
    ui.spacer({ height = math.max(0, dy) }),
    child,
  })
end

local function digitSlot(i, now, t)
  local d = digits[i]
  local enter = spring(phase(t, 820 + (i - 1) * 90, 700)) -- intro stagger
  local roll = d.rollAt and easeOutCubic((now - d.rollAt) / 520) or 1
  local base = ROLL * (1 - enter)
  local layers = {}
  if d.prev and roll < 1 then
    layers[#layers + 1] = shifted(base + ROLL * 0.0, SLOT_H + ROLL,
      ui.label({ text = d.prev, fontFamily = THIN, fontSize = FS, color = "on_surface",
        width = SLOT_W, textAlign = "center", opacity = (1 - roll) * enter }), "p" .. i)
    -- the old digit lifts away: spacer can't go negative, so the new one does the travel
  end
  layers[#layers + 1] = shifted(base + ROLL * (1 - roll), SLOT_H + ROLL,
    ui.label({ text = d.cur or "", fontFamily = THIN, fontSize = FS, color = "on_surface",
      width = SLOT_W, textAlign = "center", opacity = enter * (d.prev and roll or 1) }), "c" .. i)
  return ui.row({ key = "slot" .. i, width = SLOT_W, gap = -SLOT_W, align = "start" }, layers)
end

local function render(now)
  local t = now - t0
  local sinceSecond = now - secondAt

  -- colon breathes: dips to 35% and back within the first 450 ms of every second
  local breathe = sinceSecond < 450 and (0.35 + 0.65 * (1 - math.sin(math.pi * sinceSecond / 450))) or 1
  local colonIn = easeOutCubic(phase(t, 1000, 500))

  local dotIn = spring(phase(t, 550, 500))
  local dayIn = easeOutCubic(phase(t, 630, 600))
  local lineIn = easeOutCubic(phase(t, 1300, 700))
  local dateIn = easeOutCubic(phase(t, 1450, 600))
  local typed = math.floor(clamp01((t - 1800) / (32 * #greeting)) * #greeting + 0.5)
  local caretOn = t < 1800 + 32 * #greeting + 900 and (math.floor(now / 420) % 2 == 0)
  local secFill = (seconds + clamp01(sinceSecond / 1000)) / 60

  local key = table.concat({
    math.floor(breathe * 50), math.floor(colonIn * 50), math.floor(dotIn * 60), math.floor(dayIn * 60),
    math.floor(lineIn * 80), math.floor(dateIn * 60), typed, tostring(caretOn), math.floor(secFill * 600),
    digits[1].cur or "", digits[2].cur or "", digits[3].cur or "", digits[4].cur or "",
    math.floor((digits[1].rollAt and now - digits[1].rollAt or 9999) / 33),
    math.floor((digits[2].rollAt and now - digits[2].rollAt or 9999) / 33),
    math.floor((digits[3].rollAt and now - digits[3].rollAt or 9999) / 33),
    math.floor((digits[4].rollAt and now - digits[4].rollAt or 9999) / 33),
    math.floor(t / 33) < 80 and math.floor(t / 33) or 80,
  }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local dot = 8 * dotIn
  local weekday = ui.row({ key = "day", height = 22, gap = 10, align = "center" }, {
    ui.column({ width = 8, height = 8, align = "center", justify = "center" }, {
      ui.box({ width = math.max(dot, 0.01), height = math.max(dot, 0.01), radius = dot / 2, fill = accent }),
    }),
    ui.row({ align = "center" }, {
      ui.spacer({ width = 14 * (1 - dayIn) }),
      ui.label({ text = noctalia.formatTime("{:%A}"), fontFamily = MONO, fontSize = 15, color = accent,
        opacity = dayIn }),
    }),
  })

  local time = ui.row({ key = "time", height = SLOT_H + ROLL, align = "start" }, {
    digitSlot(1, now, t), digitSlot(2, now, t),
    shifted(ROLL * (1 - colonIn), SLOT_H + ROLL,
      ui.label({ text = ":", fontFamily = THIN, fontSize = FS, color = "on_surface", width = COLON_W,
        textAlign = "center", opacity = colonIn * breathe }), "colon"),
    digitSlot(3, now, t), digitSlot(4, now, t),
  })

  local lineW = 300 * lineIn
  local hairline = ui.row({ key = "line", height = 2, gap = 0, align = "center" }, {
    ui.box({ width = math.max(lineW * secFill, 0.01), height = 2, radius = 1, fill = accent }),
    ui.box({ width = math.max(lineW * (1 - secFill), 0.01), height = 1, fill = "on_surface/0.14" }),
  })

  local date = ui.row({ key = "date", height = 20, align = "center" }, {
    ui.label({ text = noctalia.formatTime("{:%d %B %Y}  ·  {:%p}"), fontFamily = MONO, fontSize = 15,
      color = "on_surface_variant", opacity = dateIn }),
  })

  local shown = string.sub(greeting, 1, typed)
  local greet = ui.row({ key = "greet", height = 24, align = "center" }, {
    ui.label({ text = shown, fontFamily = LIGHT, fontSize = 17, color = "on_surface" }),
    ui.box({ width = 2, height = 17, fill = accent, opacity = caretOn and 0.9 or 0 }),
  })

  desktopWidget.render(ui.column({ width = W, gap = 0, align = "start" }, {
    weekday,
    ui.spacer({ height = 2 }),
    time,
    ui.spacer({ height = 2 }),
    hairline,
    ui.spacer({ height = 14 }),
    date,
    ui.spacer({ height = 34 }),
    greet,
  }))
end

local function readClock(now)
  local hm = noctalia.formatTime("{:%I%M}")
  for i = 1, 4 do
    local c = string.sub(hm, i, i)
    local d = digits[i]
    if d.cur == nil then
      d.cur = c
    elseif d.cur ~= c then
      d.prev, d.cur, d.rollAt = d.cur, c, now
    end
  end
  local s = noctalia.formatTime("{:%S}")
  if s ~= lastSecond then
    lastSecond = s
    secondAt = now
    seconds = tonumber(s) or 0
  end
end

local function animating(now)
  if now - t0 < 1800 + 32 * #greeting + 1200 then
    return true
  end
  for i = 1, 4 do
    if digits[i].rollAt and now - digits[i].rollAt < 560 then
      return true
    end
  end
  return now - secondAt < 480
end

function update()
  local now = noctalia.nowMs()
  readClock(now)
  render(now)
  setInterval(animating(now) and FAST or math.max(40, 1000 - (now - secondAt) + 5))
end

readClock(t0)
for i = 1, 4 do
  digits[i].prev, digits[i].rollAt = nil, nil
end
noctalia.setUpdateInterval(FAST)
interval = FAST
render(t0)
