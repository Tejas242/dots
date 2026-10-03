--!nonstrict
-- Shared now-playing model for the Turntable entries.
--
-- Event-driven: one `busctl monitor` stream wakes us when any MPRIS player
-- changes, and only then do we run tools/nowplaying.sh. A slow fallback poll
-- (10 s) covers players that miss signals. Album-art label frames are rendered
-- once per track and size by tools/make_label.py and cached on disk.

local M = {}

local DIR = noctalia.pluginDir()
local LABELS = (noctalia.pluginDataDir()) .. "/labels"
local FALLBACK_MS = 10000
local DEBOUNCE_MS = 800 -- some players emit bursts; never poll more than ~1x/s

M.status = "None"
M.title = ""
M.artist = ""
M.lengthUs = 0
M.positionUs = 0
M.positionAt = 0
M.artUrl = nil

local listeners = {}
local labelSets = {} -- [key] = { size, frames, dir, url, busy }
local lastPoll = 0
local pollQueued = false
local streaming = false
local polled = false -- no label work until we know what is playing

local function emit()
  for _, fn in ipairs(listeners) do
    fn()
  end
end

local function field(meta, name)
  local v = meta and meta[name]
  return v and v.data
end

local function renderLabels(set)
  local url = M.artUrl
  local src = (url and url ~= "") and url or "-"
  if set.busy or set.url == src then
    return
  end
  set.busy = true
  noctalia.runAsync({ "python3", DIR .. "/tools/make_label.py", src, LABELS, tostring(set.frames),
    tostring(set.size), noctalia.getColor(set.accent or "primary") or "#7ad08a", set.style or "" }, function(r)
    set.busy = false
    if r.exitCode == 0 then
      set.url = src
      set.dir = noctalia.string.trim(r.stdout)
      emit()
    else
      noctalia.log("turntable: label render failed: " .. (r.stderr or ""))
    end
    renderLabels(set) -- art may have changed while rendering
  end, 30000)
end

function M.poll()
  lastPoll = noctalia.nowMs()
  noctalia.runAsync({ "sh", DIR .. "/tools/nowplaying.sh" }, function(r)
    if r.exitCode ~= 0 then
      return
    end
    local info = noctalia.json.decode(r.stdout)
    if type(info) ~= "table" then
      return
    end
    local meta = info.metadata and info.metadata.data
    M.status = info.status or "None"
    M.title = field(meta, "xesam:title") or ""
    local artists = field(meta, "xesam:artist")
    M.artist = type(artists) == "table" and table.concat(artists, ", ") or (artists or "")
    M.lengthUs = tonumber(field(meta, "mpris:length")) or 0
    M.positionUs = tonumber(info.position) or 0
    M.positionAt = noctalia.nowMs()
    M.artUrl = field(meta, "mpris:artUrl")
    M.player = info.player
    polled = true
    for _, set in pairs(labelSets) do
      renderLabels(set)
    end
    emit()
  end, 3000)
end

local function startStream()
  if streaming then
    return
  end
  streaming = noctalia.runStream(
    "exec busctl --user monitor --json=short --match "
      .. "\"type='signal',interface='org.freedesktop.DBus.Properties',"
      .. "member='PropertiesChanged',path='/org/mpris/MediaPlayer2'\" 2>/dev/null",
    function(_line)
      pollQueued = true
    end
  ) and true or false
end

-- Call from the entry's update(); cheap when nothing changed.
function M.tick()
  local now = noctalia.nowMs()
  if (pollQueued and now - lastPoll >= DEBOUNCE_MS) or now - lastPoll >= FALLBACK_MS then
    pollQueued = false
    M.poll()
  end
end

function M.progress()
  if M.lengthUs <= 0 then
    return 0
  end
  local pos = M.positionUs
  if M.status == "Playing" then
    pos += (noctalia.nowMs() - M.positionAt) * 1000
  end
  return math.clamp(pos / M.lengthUs, 0, 1)
end

-- Register a label-frame set (frames x size px); returns a getter for its dir.
function M.labels(key, size, frames, accent, style)
  local set = labelSets[key] or { size = size, frames = frames, accent = accent, style = style }
  labelSets[key] = set
  if polled then
    renderLabels(set)
  end
  -- only hand out frames that belong to the *current* track, so a stale set
  -- (e.g. the idle label finishing first) never flashes on screen
  return function()
    local want = (M.artUrl and M.artUrl ~= "") and M.artUrl or "-"
    if set.url == want then
      return set.dir
    end
    return nil
  end
end

-- Play/pause the active player. The state flips optimistically so the deck
-- reacts on the same frame; the next poll confirms (or corrects) it.
function M.toggle()
  if not M.player or M.status == "None" then
    return
  end
  M.status = M.status == "Playing" and "Paused" or "Playing"
  M.positionAt = noctalia.nowMs()
  emit()
  noctalia.runAsync({ "busctl", "--user", "call", M.player, "/org/mpris/MediaPlayer2",
    "org.mpris.MediaPlayer2.Player", "PlayPause" }, function()
    pollQueued = true
  end, 3000)
end

function M.subscribe(fn)
  listeners[#listeners + 1] = fn
end

function M.start()
  noctalia.mkdirAll(LABELS)
  startStream()
  M.poll()
end

return M
