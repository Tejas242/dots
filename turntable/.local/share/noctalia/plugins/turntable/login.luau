--!nonstrict
-- Nocturne key: dresses Noctalia's own password field as a key, in
-- screenager.dev's language.
--
--   good evening, screenager▌            greeting, typed in (Figtree, the name in semibold)
--     ▪                                  the key hangs from a pixel nail on a hairline cord
--     │
--   ┌─┴─┐
--   │ ☺ ├═┤ Password               │   bow: your site portrait in a square tile · neck · blade
--   └───┘                    ▮ ▮ ▮      three square bits hang under the tip
--
-- The stock login box sits on top of this widget; nocturne_layout.py places both
-- so the pill lands exactly on PILL_X/KEY_CY. Everything is outlined in the
-- focus-ring role (secondary) at its 2 px width, so bow, neck and pill read as
-- one stroke.
--
-- Hover the bow and it warms up; click it to flip it over: the back shows how
-- long the screen has been locked, then it flips home by itself.
-- The pill's corners come from the login box's input_radius (nocturne_layout.py).
--
-- The gap the cord spans is deliberate: Noctalia shows its status line (wrong
-- password, caps lock) just above the login box, right of the cord.

local DIR = noctalia.pluginDir()
local function font(file, fallback)
  return noctalia.loadFont(DIR .. "/fonts/" .. file) or fallback
end
local SANS = font("SiteFigtreeRegular.ttf", "Site Figtree Regular")
local STRONG = font("SiteFigtreeSemiBold.ttf", "Site Figtree SemiBold")
local MONO = font("SiteJetBrainsMono.ttf", "Site JetBrains Mono")
local PORTRAIT = "assets/avatar.png"

local name = noctalia.getConfig("name") or ""
if name == "" then
  name = noctalia.getenv("USER") or "friend"
end
local greetingSetting = noctalia.getConfig("greeting") or "auto"
local STROKE = "secondary" -- Noctalia's focus ring role: the pill's own outline
local LINE = 2 -- focus ring width
local RADIUS = 4 -- matches the login box's input_radius

-- geometry (logical px) - keep in sync with tools/nocturne_layout.py
local BOW = 46
local BOW_CX = BOW / 2
local PILL_X, PILL_W, PILL_H = 58, 314, 38
local W, H = PILL_X + PILL_W, 133
local KEY_CY = 100
local PILL_Y = KEY_CY - PILL_H / 2
local NECK_GAP = 8 -- air between the neck's two rails
local TIP = PILL_X + PILL_W
local TEETH = { { TIP - 46, 9 }, { TIP - 36, 5 }, { TIP - 26, 11 } } -- { x, depth }
local TOOTH_W = 6
local GREET_FS, GREET_Y = 16, 11 -- greeting caps start here
local BOW_PAD = 3 -- portrait inset inside the tile's stroke, like the site's frame
local NAIL_Y, NAIL = 42, 4
local CAP = 0.7

local FLIP, HOLD = 380, 3200
local FAST, IDLE = 33, 1000

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = FAST
local flipAt = nil
local hovered, hoverAt = false, -1e9

local function clamp01(x)
  return math.clamp(x, 0, 1)
end
local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end
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

-- { lead, name, tail }: the name is set strong, like the site's h1
local function greetingParts()
  if greetingSetting ~= "auto" then
    return { greetingSetting, "", "" }
  end
  local h = tonumber(noctalia.formatTime "{:%H}") or 12
  if h >= 5 and h < 12 then
    return { "good morning, ", name, "" }
  elseif h >= 12 and h < 17 then
    return { "good afternoon, ", name, "" }
  elseif h >= 17 and h < 23 then
    return { "good evening, ", name, "" }
  end
  return { "still up, ", name, "?" }
end
local parts = greetingParts()
local greeting = table.concat(parts)
local TYPE_AT, TYPE_MS = 900, 32
local typeEnd = TYPE_AT + TYPE_MS * #greeting

local function away(now)
  local m = math.floor((now - t0) / 60000)
  if m < 1 then
    return "now"
  elseif m < 60 then
    return m .. "m"
  end
  return string.format("%dh%02d", m // 60, m % 60)
end

-- bow face and squash (1 = round, 0 = edge-on) for the coin flip
local function bowState(now)
  if not flipAt then
    return false, 1
  end
  local e = now - flipAt
  if e < FLIP then
    local q = e / FLIP
    return q >= 0.5, math.abs(math.cos(math.pi * q))
  elseif e < FLIP + HOLD then
    return true, 1
  elseif e < FLIP * 2 + HOLD then
    local q = (e - FLIP - HOLD) / FLIP
    return q < 0.5, math.abs(math.cos(math.pi * q))
  end
  flipAt = nil
  return false, 1
end

-- ── layout helpers ──────────────────────────────────────────────────────────
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

-- ── frame ───────────────────────────────────────────────────────────────────
local function render(now)
  local t = now - t0
  local back, squash = bowState(now)
  local hv = easeOut((now - hoverAt) / 220)
  hv = hovered and hv or 1 - hv
  local bowIn = spring(phase(t, 250, 700))
  local cordIn = easeOut(phase(t, 120, 420))
  local neckIn = easeOut(phase(t, 600, 320))
  local typed = math.floor(clamp01((t - TYPE_AT) / (TYPE_MS * #greeting)) * #greeting + 0.5)
  local caretOn = t < typeEnd + 1100 and (math.floor(now / 420) % 2 == 0)
  local teeth = {}
  for i = 1, #TEETH do
    teeth[i] = easeOut(phase(t, 780 + (i - 1) * 90, 320))
  end

  local q = function(x)
    return math.floor(x * 100)
  end
  local key = table.concat({ q(cordIn), q(bowIn), q(neckIn), typed, tostring(caretOn), tostring(back), q(squash),
    back and away(now) or "", q(hv), q(teeth[1]), q(teeth[2]), q(teeth[3]) }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local layers = {}

  -- greeting, typed, with a caret that blinks out once it's done
  local frame = GREET_FS * 2
  local runs, left = {}, typed
  for i, part in ipairs(parts) do
    local shown = string.sub(part, 1, math.max(left, 0))
    left -= #part
    if shown ~= "" then
      runs[#runs + 1] = ui.label({ key = "g" .. i, text = shown, fontFamily = i == 2 and STRONG or SANS,
        fontSize = GREET_FS, color = i == 2 and "on_surface" or "on_surface_variant" })
    end
  end
  runs[#runs + 1] = ui.box({ key = "caret", width = 2, height = GREET_FS, fill = STROKE,
    opacity = caretOn and 0.9 or 0 })
  layers[#layers + 1] = place(0, GREET_Y - (frame - GREET_FS * CAP) / 2, ui.row({ height = frame,
    align = "center" }, runs), "greet")

  -- nail and cord: drawn down from the nail; the bow covers the cord's end
  local bowTop = KEY_CY - BOW / 2
  layers[#layers + 1] = place(BOW_CX - NAIL / 2, NAIL_Y - NAIL / 2, ui.box({ width = NAIL, height = NAIL,
    fill = "on_surface/0.45", opacity = cordIn }), "nail")
  layers[#layers + 1] = place(BOW_CX - 0.5, NAIL_Y, ui.box({ width = 1,
    height = math.max((bowTop + LINE - NAIL_Y) * cordIn, 0.01), fill = "on_surface/0.22" }), "cord")

  -- neck: two rails from the bow's rim into the pill's rounded end
  local size = BOW * (0.7 + 0.3 * bowIn) * (1 + 0.06 * hv)
  local bw = math.max(size * squash, 1)
  local neckX = BOW_CX + bw / 2 - 1
  local neckW = math.max((PILL_X + 1 - neckX) * neckIn, 0.01)
  for i, dy in ipairs({ -NECK_GAP / 2 - LINE, NECK_GAP / 2 }) do
    layers[#layers + 1] = place(neckX, KEY_CY + dy, ui.box({ width = neckW, height = LINE, fill = STROKE,
      opacity = neckIn }), "neck" .. i)
  end

  -- bits: hang from the pill's lower edge near the tip
  for i, tooth in ipairs(TEETH) do
    layers[#layers + 1] = place(tooth[1], PILL_Y + PILL_H - 1, ui.box({ width = TOOTH_W,
      height = math.max((tooth[2] + 1) * teeth[i], 0.01), fill = STROKE, opacity = teeth[i] }),
      "bit" .. i)
  end

  -- bow: a tile in the pill's stroke, your portrait on the front, time away on the back
  local inner = math.max(bw - (LINE + BOW_PAD) * 2, 1)
  local face = back and ui.label({ text = away(now), fontFamily = MONO, fontSize = 11, color = "on_surface" })
    or ui.image({ key = "portrait", path = PORTRAIT, width = inner, height = math.max(size - (LINE + BOW_PAD) * 2, 1),
      fit = "cover" })
  -- hover warms the bow: a tint under its glassy fill
  layers[#layers + 1] = place(BOW_CX - bw / 2, KEY_CY - size / 2, ui.box({ width = bw, height = size,
    radius = RADIUS, fill = STROKE, opacity = 0.3 * hv }), "tint")
  layers[#layers + 1] = place(BOW_CX - bw / 2, KEY_CY - size / 2, ui.column({ width = bw, height = size,
    radius = RADIUS, border = STROKE, borderWidth = LINE, fill = "surface/0.35",
    justify = "center", align = "center", opacity = clamp01(bowIn) }, {
    ui.column({ opacity = squash * squash }, { face }),
  }), "bow")
  layers[#layers + 1] = place(BOW_CX - BOW / 2, KEY_CY - BOW / 2, ui.box({ width = BOW, height = BOW,
    fill = "surface/0", onClick = "onBowClick", onHover = "onBowHover" }), "hit")

  desktopWidget.render(ui.row({ width = W, height = H, gap = -W, align = "start" }, layers))
end

local function tick()
  local now = noctalia.nowMs()
  render(now)
  local busy = now - t0 < typeEnd + 1200 or now - hoverAt < 280
    or (flipAt ~= nil and now - flipAt < FLIP * 2 + HOLD + 50)
  setInterval(busy and FAST or IDLE * 30)
end

function onBowClick()
  local now = noctalia.nowMs()
  if not flipAt then
    flipAt = now
  elseif now - flipAt >= FLIP and now - flipAt < FLIP + HOLD then
    flipAt = now - FLIP - HOLD -- already showing the back: flip home now
  end
  tick()
end

function onBowHover(on)
  hovered, hoverAt = on == "true", noctalia.nowMs()
  tick()
end

function update()
  tick()
end

noctalia.setUpdateInterval(FAST)
render(t0)
