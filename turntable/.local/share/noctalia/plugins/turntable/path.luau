--!nonstrict
-- Nocturne path: the lock screen's top-left corner, in screenager.dev's voice.
--
--   ~  locked  since 1:24 pm
--
-- The site opens every page with its path typed in at the top left; the lock
-- screen does the same. "since" follows the clock's 12h / 24h choice. Hover it
-- and the tail swaps to the ISO week, the site's other quiet stamp.

local DIR = noctalia.pluginDir()
local MONO = noctalia.loadFont(DIR .. "/fonts/SiteJetBrainsMono.ttf") or "Site JetBrains Mono"

-- geometry (logical px) - keep in sync with tools/nocturne_layout.py
local W, H = 260, 20
local FS = 11
local CH = FS * 0.6 -- mono advance
local GAP = 2 -- characters between segments, like the site's nav spacing
local TYPE_AT, TYPE_MS = 200, 45
local FAST, IDLE = 33, 30000

local t0 = noctalia.nowMs()
local lastKey = ""
local interval = FAST
local hovered, hoverAt = false, -1e9

local function clamp01(x)
  return math.clamp(x, 0, 1)
end
local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end

local function setInterval(ms)
  if ms ~= interval then
    interval = ms
    noctalia.setUpdateInterval(ms)
  end
end

local function since()
  local prefs = noctalia.readFile((noctalia.pluginDataDir() or DIR) .. "/clock.txt") or ""
  if noctalia.string.trim(prefs) == "24" then
    return "since " .. noctalia.formatTime "{:%H:%M}"
  end
  local h = tonumber(noctalia.formatTime "{:%I}") or 12
  return string.format("since %d:%s %s", h, noctalia.formatTime "{:%M}", string.lower(noctalia.formatTime "{:%p}"))
end
local lockedAt = since()
local week = "week " .. tonumber(noctalia.formatTime "{:%V}")

local function sp(w, h)
  return ui.spacer({ width = math.max(0, w), height = math.max(0, h), flexGrow = 0 })
end

local function seg(x, text, color, opacity, key)
  return ui.column({ key = key, width = W, height = H, align = "start" }, {
    ui.row({ height = H, align = "center" }, {
      sp(x, 0),
      ui.label({ text = text, fontFamily = MONO, fontSize = FS, color = color, opacity = opacity }),
    }),
  })
end

local function render(now)
  local t = now - t0
  local head = { { "~", "on_surface_variant" }, { "locked", "on_surface" } }
  local tail = hovered and week or lockedAt
  local typed = math.floor(math.max(0, t - TYPE_AT) / TYPE_MS)
  local hv = easeOut((now - hoverAt) / 180)

  local key = table.concat({ math.min(typed, 64), tostring(hovered), math.floor(hv * 50) }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local layers, x, left = {}, 0, typed
  for i, s in ipairs(head) do
    local shown = string.sub(s[1], 1, math.max(left, 0))
    left -= #s[1] + GAP
    layers[#layers + 1] = seg(x * CH, shown, s[2], 1, "h" .. i)
    x += #s[1] + GAP
  end
  -- the tail types in once, then crossfades between lock time and week on hover
  local shown = string.sub(tail, 1, math.max(left, 0))
  layers[#layers + 1] = seg(x * CH, shown, "outline", (now - hoverAt < 200) and hv or 1, "tail")
  layers[#layers + 1] = ui.column({ key = "hit", width = W, height = H }, {
    ui.box({ width = (x + #tail) * CH, height = H, fill = "surface/0", onHover = "onPathHover" }),
  })

  desktopWidget.render(ui.row({ width = W, height = H, gap = -W, align = "start" }, layers))
end

local function tick()
  local now = noctalia.nowMs()
  render(now)
  local typing = now - t0 < TYPE_AT + TYPE_MS * 40
  setInterval((typing or now - hoverAt < 220) and FAST or IDLE)
end

function onPathHover(on)
  hovered, hoverAt = on == "true", noctalia.nowMs()
  tick()
end

function update()
  tick()
end

noctalia.setUpdateInterval(FAST)
render(t0)
