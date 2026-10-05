--!nonstrict
-- Morphing digits for the Nocturne clock (frames from tools/make_digits.py).
--
-- A set is one font at one size in one colour role. It renders in the
-- background the first time it is asked for (and again when the palette
-- changes the role's colour); until then `ready()` is false and the clock
-- draws plain labels instead.
--
-- Every frame of a slot's next morph is mounted ahead of time at opacity 0 and
-- the morph only switches which one is visible, so a change of second never
-- waits on an image decode (the same trick the turntable uses to spin). Only
-- slots about to change carry those frames, which keeps the tree small.

local M = {}

local DIR = noctalia.pluginDir()
local CACHE = (noctalia.pluginDataDir() or DIR) .. "/digits"

function M.new(opts)
  local set = {
    font = opts.font,
    size = opts.size,
    role = opts.role,
    frames = opts.frames or 14,
    pixel = opts.pixel or 3,
    dir = nil,
    meta = nil,
    color = nil,
    busy = false,
  }

  function set.ready()
    return set.meta ~= nil
  end

  -- (re)render when the role's colour differs from the frames on disk
  function set.sync(onReady)
    local color = noctalia.getColor(set.role) or "#72dd71"
    if set.busy or color == set.color then
      return
    end
    set.busy = true
    noctalia.runAsync({ "python3", DIR .. "/tools/make_digits.py", DIR .. "/fonts/" .. set.font, tostring(set.size),
      color, CACHE, tostring(set.frames), tostring(set.pixel) }, function(r)
      set.busy = false
      if r.exitCode ~= 0 then
        noctalia.log("turntable: digit render failed: " .. (r.stderr or ""))
        return
      end
      local dir = noctalia.string.trim(r.stdout)
      local meta = noctalia.json.decode(noctalia.readFile(dir .. "/meta.json") or "")
      if type(meta) == "table" then
        set.dir, set.meta, set.color = dir, meta, color
        if onReady then
          onReady()
        end
      end
    end, 120000)
  end

  -- One slot: `from`/`to` digits, `p` in 0..1 through the morph (1 = at rest on
  -- `to`), `nextTo` the digit expected after `to`, whose frames are preloaded
  -- when `soon` says that change is near.
  function set.slot(key, from, to, p, nextTo, soon, opacity)
    local m = set.meta
    local morphing = from ~= nil and from ~= to and p < 1
    local a, b = morphing and from or to, morphing and to or nextTo
    local frame = morphing and math.clamp(math.floor(p * (m.frames - 1) + 0.5), 0, m.frames - 1) or -1
    local layers = {
      ui.image({ key = key .. "rest", path = string.format("%s/d%s.png", set.dir, to), width = m.w, height = m.h,
        opacity = morphing and 0 or opacity }),
    }
    if a ~= b and b ~= nil and (morphing or soon) then
      for i = 0, m.frames - 1 do
        layers[#layers + 1] = ui.image({ key = key .. "f" .. i, path = string.format("%s/%s%s/f%02d.png", set.dir, a, b, i),
          width = m.w, height = m.h, opacity = (i == frame) and opacity or 0 })
      end
    end
    return ui.row({ key = key, width = m.w, height = m.h, gap = -m.w, align = "start" }, layers)
  end

  return set
end

return M
