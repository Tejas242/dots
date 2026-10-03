--!nonstrict
-- Bar companion of the lock-screen turntable: a tiny record whose label is the
-- current album art, spinning while music plays. Same frame-stack trick as
-- turntable.luau (all frames loaded once, switched by opacity). It only redraws
-- at ~13 fps while playing; idle it sleeps on the event-driven player model.

local mpris = require("./mpris.luau")

local SIZE = tonumber(noctalia.getConfig("size")) or 16
local RIM = 1 -- just a hairline of black vinyl around the art
local LABEL = SIZE - RIM * 2
local FRAMES = 24
local STEP_MS = 75               -- 24 frames at 33 1/3 rpm = one frame every 75 ms
local SLOW = 1000

local labelDir = mpris.labels("bar", LABEL * 3, FRAMES, "primary", "clean") -- 3x for crisp downsampling

local frame = 0
local speed = 0                  -- 0..1, eased so the disc winds up / coasts down
local acc = 0
local interval = SLOW
local lastStep = 0
local lastKey = ""

local function setInterval(ms)
  if ms ~= interval then
    interval = ms
    noctalia.setUpdateInterval(ms)
  end
end

local function render()
  local dir = labelDir()
  local live = mpris.status ~= "None"
  local key = table.concat({ frame, dir or "", tostring(live) }, "|")
  if key == lastKey then
    return
  end
  lastKey = key

  local labels = {}
  if dir then
    for i = 0, FRAMES - 1 do
      labels[#labels + 1] = ui.image({
        key = "f" .. i,
        path = string.format("%s/f%02d.png", dir, i),
        width = LABEL,
        height = LABEL,
        opacity = (i == frame) and 1 or 0,
      })
    end
  end

  barWidget.render(ui.column({
    width = SIZE,
    height = SIZE,
    padding = RIM,
    radius = SIZE / 2,
    fill = "#0c0d0c",
    align = "center",
    justify = "center",
  }, { ui.row({ gap = -LABEL }, labels) }))

  barWidget.setVisible(live) -- vanish together with the media widget
  local tip = live and (mpris.title .. (mpris.artist ~= "" and ("  ·  " .. mpris.artist) or "")) or "Nothing playing"
  barWidget.setTooltip(tip)
end

function update()
  local now = noctalia.nowMs()
  local dt = math.min(now - lastStep, 250)
  lastStep = now
  local target = mpris.status == "Playing" and 1 or 0
  speed += (target - speed) * (1 - math.exp(-dt / 350))
  if target == 0 and speed < 0.02 then
    speed = 0
  end
  acc += dt * speed
  while acc >= STEP_MS do
    acc -= STEP_MS
    frame = (frame + 1) % FRAMES
  end
  mpris.tick()
  render()
  setInterval((speed > 0 or target > 0) and STEP_MS / 2 or SLOW)
end

mpris.subscribe(function()
  lastStep = noctalia.nowMs()
  if mpris.status == "Playing" then
    setInterval(STEP_MS / 2)
  end
  render()
end)
noctalia.setUpdateInterval(SLOW)
mpris.start()
render()
