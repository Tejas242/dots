--!nonstrict
-- Turntable: a vinyl record that spins the current track's album art.
--
-- Layers are stacked inside one row with a negative gap (flex places every child
-- at the same origin), so the static record body, the rotating label and the
-- tonearm overlap without separate widgets. Rotation uses pre-rendered frames
-- (tools/make_label.py) that are all loaded once and switched by opacity, so
-- spinning never decodes images. The player model is event-driven (mpris.luau);
-- the update timer runs at ~30 Hz only while something moves, 1 Hz otherwise.

local mpris = require("./mpris.luau")
local DIR = noctalia.pluginDir()

-- geometry (logical px) - keep in sync with tools/render_assets.py
local W, H = 440, 360
local BODY = 360
local LABEL = 124
local ARM_W, ARM_H, ARM_FRAMES = 220, 360, 10
local FRAMES = 48
local DEG_PER_SEC = 33.333 * 6 -- 33 1/3 rpm
local FAST, SLOW = 33, 1000

local showInfo = noctalia.getConfig("show_info") ~= false
local accent = noctalia.getConfig("accent") or "primary"

local sans = noctalia.loadFont(DIR .. "/fonts/NocturneSansLight.ttf") or "Nocturne Sans Light"
local mono = noctalia.loadFont(DIR .. "/fonts/NocturneMono.ttf") or "Nocturne Mono"

local labelDir = mpris.labels("lock", LABEL, FRAMES, accent)

-- motion model
local angle = 0 -- degrees
local speed = 0 -- 0..1 of 33 1/3 rpm
local arm = 0   -- 0 rest .. 1 on the record
local interval = SLOW
local lastStep = 0
local lastKey = ""
local primedDir = nil

-- Intro choreography (ms from lock): the platter drops in on a spring, the label
-- pops, the tonearm swings over once the record has landed, then the track info
-- rises. Textures are first created at full size (the reconciler only re-decodes
-- when an image grows past its first size), then scaled down and sprung back up.
local t0 = noctalia.nowMs()
local INTRO_END = 2900
local function intro()
  return noctalia.nowMs() - t0
end

local function clamp01(x)
  return math.clamp(x, 0, 1)
end

local function spring(x) -- step response with a soft overshoot
  x = clamp01(x)
  return 1 - math.exp(-5.5 * x) * math.cos(8.5 * x)
end

local function easeOut(x)
  x = clamp01(x)
  return 1 - (1 - x) ^ 3
end

local function phase(t, start, dur)
  return clamp01((t - start) / dur)
end

local function smooth(t)
  return t * t * (3 - 2 * t)
end

local function targets()
  local playing = mpris.status == "Playing"
  -- paused or stopped: the platter coasts down, then the arm lifts back to rest
  local armTarget = playing and 1 or 0
  if intro() < 1550 then
    armTarget = 0 -- the arm waits for the record to land
  end
  local spinTarget = (playing and arm > 0.98) and 1 or 0
  if playing and intro() < 1250 then
    spinTarget = 0.35 -- the platter idles round while it drops in
  end
  return armTarget, spinTarget
end

local function moving()
  local armTarget, spinTarget = targets()
  return intro() < INTRO_END or math.abs(arm - armTarget) > 0.001 or speed > 0 or spinTarget > 0
end

local function setInterval(ms)
  if ms ~= interval then
    interval = ms
    noctalia.setUpdateInterval(ms)
  end
end

local function render()
  local frame = math.floor((angle % 360) / (360 / FRAMES)) % FRAMES
  local armFrame = math.floor(smooth(arm) * (ARM_FRAMES - 1) + 0.5)
  local dir = labelDir()
  local live = mpris.status ~= "None" and mpris.title ~= ""
  local prog = math.floor(mpris.progress() * 400) / 400
  local t = intro()
  -- prime textures at 115% (invisible) the first time each set appears, so springs
  -- and overshoot only ever scale *down* from the decoded size (no re-decodes)
  local first = lastKey == ""
  local primeLabels = dir ~= nil and dir ~= primedDir
  primedDir = dir or primedDir
  local bodyS = first and 1.15 or (0.84 + 0.16 * spring(phase(t, 450, 1000)))
  local bodyA = first and 0 or easeOut(phase(t, 450, 450))
  local labelS = (first or primeLabels) and 1.15 or spring(phase(t, 900, 800))
  local armA = first and 0 or easeOut(phase(t, 1200, 400))
  local infoT = first and 0 or easeOut(phase(t, 1800, 700))
  local q = function(x) return math.floor(x * 200) end
  local key = table.concat({ frame, armFrame, dir or "", mpris.artUrl or "", prog, mpris.title, mpris.artist, tostring(live),
    q(bodyS), q(bodyA), q(labelS), q(armA), q(infoT), tostring(primeLabels) }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local labels = {}
  local art = mpris.artUrl and string.match(mpris.artUrl, "^file://(.+)$")
  if not dir and art then
    -- frames still rendering: show the art as a still label so the centre is never empty
    -- fixed size (growing would re-decode the cover every frame); it fades with the pop instead
    labels[1] = ui.image({ key = "still", path = noctalia.string.urlDecode(art), width = LABEL,
      height = LABEL, radius = LABEL / 2, fit = "cover", opacity = first and 0 or math.min(bodyA, labelS) })
  end
  if dir then
    for i = 0, FRAMES - 1 do
      labels[#labels + 1] = ui.image({
        key = "f" .. i,
        path = string.format("%s/f%02d.png", dir, i),
        width = math.max(LABEL * labelS, 1),
        height = math.max(LABEL * labelS, 1),
        opacity = (i == frame and not primeLabels) and (first and 0 or bodyA) or 0,
      })
    end
  end

  local arms = {}
  for i = 0, ARM_FRAMES - 1 do
    arms[#arms + 1] = ui.image({
      key = "a" .. i,
      path = string.format("assets/arm%02d.png", i),
      width = ARM_W,
      height = ARM_H,
      opacity = (i == armFrame) and armA or 0,
    })
  end

  -- the whole deck is a play/pause button
  local deck = ui.row({ key = "deck", gap = -BODY, align = "start", onClick = mpris.toggle }, {
    ui.column({ key = "bodyc", width = BODY, height = BODY, align = "center", justify = "center" }, {
      ui.image({ key = "body", path = "assets/body.png", width = BODY * bodyS, height = BODY * bodyS,
        opacity = bodyA }),
    }),
    ui.column({ key = "label", width = BODY, height = BODY, align = "center", justify = "center" }, {
      ui.row({ gap = -((not dir) and LABEL or math.max(LABEL * labelS, 1)) }, labels),
    }),
    ui.column({ key = "arm", width = W, height = H, align = "end", justify = "start" }, {
      ui.row({ gap = -ARM_W }, arms),
    }),
  })

  local children = { deck }
  if showInfo then
    children[#children + 1] = ui.column({ key = "info", width = BODY, height = 64, gap = 6, align = "center",
      opacity = infoT }, {
      ui.spacer({ height = 14 * (1 - infoT) }),
      ui.label({
        text = live and mpris.title or "silence",
        fontFamily = sans,
        fontSize = 19,
        color = live and "on_surface" or "on_surface/0.45",
        maxWidth = BODY - 20,
        maxLines = 1,
        textAlign = "center",
      }),
      ui.label({
        text = live and string.upper(mpris.artist) or "NOTHING ON THE PLATTER",
        fontFamily = mono,
        fontSize = 11,
        color = live and (accent .. "/0.9") or "on_surface/0.3",
        maxWidth = BODY - 40,
        maxLines = 1,
        textAlign = "center",
      }),
      ui.progress({
        progress = live and prog or 0,
        fill = accent,
        track = "on_surface/0.12",
        width = math.max(120 * infoT, 1),
        height = 2,
        radius = 1,
        opacity = live and 1 or 0,
      }),
    })
  end

  desktopWidget.render(ui.column({ gap = 4, align = "start" }, children))
end

local function step(dt)
  local armTarget, spinTarget = targets()
  -- tonearm: constant-rate travel, eased in render(); lifts only after the platter slows
  if armTarget < arm and speed > 0.05 then
    armTarget = arm
  end
  local d = dt / 0.9
  arm = armTarget > arm and math.min(armTarget, arm + d) or math.max(armTarget, arm - d)
  -- platter: exponential spin-up (~0.8 s) and a longer coast down (~1.6 s)
  local tau = spinTarget > speed and 0.28 or 0.55
  speed += (spinTarget - speed) * (1 - math.exp(-dt / tau))
  if spinTarget == 0 and speed < 0.003 then
    speed = 0
  end
  angle = (angle + DEG_PER_SEC * speed * dt) % 360
end

function update()
  local now = noctalia.nowMs()
  if interval == FAST then
    step(math.min(now - lastStep, 100) / 1000)
  end
  lastStep = now
  mpris.tick()
  render()
  setInterval(moving() and FAST or SLOW)
end

mpris.subscribe(function()
  lastStep = noctalia.nowMs()
  setInterval(moving() and FAST or SLOW)
  render()
end)
interval = FAST
noctalia.setUpdateInterval(FAST)
lastStep = t0
mpris.start()
render()
