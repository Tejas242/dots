-- Nocturne start screen. The original Screenager mark stays central; it now
-- carries the desktop palette as a gradient and a light sweeps across it once
-- when the screen opens. Supporting content appears only when there is room.
--
-- Motion is done by re-colouring highlight groups (one per logo column chunk)
-- on a short timer, so the buffer is never re-rendered while it animates.
local logo = {
  "╔═╗╔═╗╦═╗╔═╗╔═╗╔╗╔╔═╗╔═╗╔═╗╦═╗",
  "╚═╗║  ╠╦╝║╣ ║╣ ║║║╠═╣║ ╦║╣ ╠╦╝",
  "╚═╝╚═╝╩╚═╚═╝╚═╝╝╚╝╩ ╩╚═╝╚═╝╩╚═",
}
local CHUNK = 3 -- columns per gradient step
local CHUNKS = math.ceil(vim.fn.strchars(logo[1]) / CHUNK)

-- The deck is shuffled once per cycle. A greeting is held for the lifetime of
-- a dashboard buffer, so resizing does not change it underneath the user.
local greetings = {
  "start with the file in front of you.",
  "make the next edit count.",
  "leave the code clearer than you found it.",
  "one focused pass is enough to begin.",
  "choose the smallest useful step.",
  "follow the thread.",
  "make the simple path obvious.",
  "begin before the plan feels complete.",
  "keep the surface area small.",
  "let the next line earn its place.",
  "read it once more, then move.",
  "make room for the important work.",
  "solve the problem that is actually here.",
  "write the version you would want to maintain.",
  "start clean; stay curious.",
  "find the sharp edge.",
  "make progress visible.",
  "prefer clarity over cleverness.",
  "turn the unknown into the next question.",
  "the cursor is ready.",
  "keep the feedback loop short.",
  "make the working path pleasant.",
  "one good decision at a time.",
  "reduce the moving parts.",
  "use the quiet moment well.",
  "make the useful thing first.",
  "start where the friction is.",
  "a careful first step changes the rest.",
  "keep the intent close to the code.",
  "write down what the future you needs.",
  "choose a direction and test it.",
  "make the next state simpler.",
  "focus is a feature.",
  "let the code explain itself.",
  "make something small and complete.",
  "take the direct route.",
  "build the part you can verify.",
  "make the ordinary path excellent.",
  "find the invariant.",
  "keep going until the shape is clear.",
  "move one ambiguity out of the way.",
  "turn a rough edge into a tool.",
  "give the hard part your fresh attention.",
  "do the kind thing for the next reader.",
  "measure before you optimize.",
  "keep the good constraints.",
  "finish the thought.",
  "make the next commit easy to explain.",
  "trust the small improvements.",
  "use the whole screen with intention.",
  "leave a useful trace.",
  "make the next review effortless.",
  "name the thing precisely.",
  "work from evidence.",
  "make the boundary explicit.",
  "keep the next action obvious.",
  "choose the boring solution when it wins.",
  "let the details line up.",
  "begin with the constraint that matters.",
  "make the common case calm.",
  "the next useful change is enough.",
  "simplify, then simplify once more.",
  "leave less to remember.",
  "make the future state easier to enter.",
  "notice what the code is asking for.",
  "follow the data.",
  "keep the promise small and clear.",
  "protect the working rhythm.",
  "make this session count.",
  "ship the understanding, not just the change.",
  "keep the tools out of the way.",
  "there is time for one careful improvement.",
}

local deck, deck_index = {}, 1
local random_state = tonumber((vim.uv or vim.loop).hrtime() % 2147483647)

local function random()
  random_state = (random_state * 48271) % 2147483647
  return random_state
end

local function refill_deck()
  deck = vim.deepcopy(greetings)
  for index = #deck, 2, -1 do
    local swap = (random() % index) + 1
    deck[index], deck[swap] = deck[swap], deck[index]
  end
  deck_index = 1
end

local function next_greeting()
  if deck_index > #deck then refill_deck() end
  local greeting = deck[deck_index]
  deck_index = deck_index + 1
  return greeting
end

local function salutation()
  local hour = tonumber(os.date "%H") or 12
  if hour < 5 then return "good night" end
  if hour < 12 then return "good morning" end
  if hour < 18 then return "good afternoon" end
  return "good evening"
end

-- ── logo: gradient + one light sweep ───────────────────────────────────────
local function logo_colors(sweep)
  local nocturne = require "nocturne"
  local p = nocturne.colors or nocturne.palette()
  for c = 1, CHUNKS do
    local base = nocturne.mix(p.primary, p.tertiary, (c - 1) / math.max(CHUNKS - 1, 1))
    local glow = sweep and math.exp(-((c - sweep) ^ 2) / 2.2) or 0
    vim.api.nvim_set_hl(0, "NocturneLogo" .. c, { fg = nocturne.mix(base, "#ffffff", 0.8 * glow), bold = true })
  end
end

local sweep_timer
local function play_sweep()
  if sweep_timer then sweep_timer:stop() end
  sweep_timer = (vim.uv or vim.loop).new_timer()
  local start = (vim.uv or vim.loop).now()
  local DURATION = 1300
  start = start + 180 -- let the first frame settle before the light moves
  sweep_timer:start(0, 16, vim.schedule_wrap(function()
    local t = math.max(0, ((vim.uv or vim.loop).now() - start) / DURATION)
    if t >= 1 or vim.bo.filetype ~= "snacks_dashboard" then
      sweep_timer:stop()
      logo_colors(nil)
      return
    end
    local eased = 1 - (1 - t) ^ 3
    logo_colors(-2 + eased * (CHUNKS + 4))
  end))
end

local function logo_section()
  local text = {}
  for row, line in ipairs(logo) do
    for c = 1, CHUNKS do
      text[#text + 1] = { vim.fn.strcharpart(line, (c - 1) * CHUNK, CHUNK), hl = "NocturneLogo" .. c }
    end
    if row < #logo then text[#text + 1] = { "\n" } end
  end
  return { align = "center", padding = 1, text = text }
end

-- ── live bits fetched off the UI thread ────────────────────────────────────
local live = { track = nil, branch = nil }
local nowplaying = vim.fn.expand "~/.local/share/noctalia/plugins/turntable/tools/nowplaying.sh"

local function refresh_live()
  if vim.fn.filereadable(nowplaying) == 1 then
    vim.system({ "sh", nowplaying }, { text = true }, function(r)
      local ok, info = pcall(vim.json.decode, r.stdout or "")
      local track
      if ok and type(info) == "table" and info.status == "Playing" then
        local meta = info.metadata and info.metadata.data or {}
        local title = meta["xesam:title"] and meta["xesam:title"].data
        local artist = meta["xesam:artist"] and meta["xesam:artist"].data
        if type(artist) == "table" then artist = table.concat(artist, ", ") end
        if title and title ~= "" then track = { title = title, artist = artist or "" } end
      end
      live.track = track
      vim.schedule(function() require("snacks").dashboard.update() end)
    end)
  end
  vim.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, { text = true, cwd = vim.fn.getcwd() }, function(r)
    live.branch = r.code == 0 and vim.trim(r.stdout) or nil
    vim.schedule(function() require("snacks").dashboard.update() end)
  end)
end

-- ── sections ────────────────────────────────────────────────────────────────
local RULE = string.rep("─", 12)

local function greeting_section(dashboard)
  local buffer = vim.b[dashboard.buf]
  buffer.screenager_dashboard_greeting = buffer.screenager_dashboard_greeting or next_greeting()
  local user = vim.env.USER ~= "" and vim.env.USER or "screenager"
  return {
    align = "center",
    padding = 2,
    text = {
      { RULE .. "  ", hl = "NocturneRule" },
      { "◆", hl = "NocturneAccent" },
      { "  " .. RULE, hl = "NocturneRule" },
      { "\n\n" },
      { ("%s, %s"):format(salutation(), user), hl = "NocturneTitle" },
      { "  ·  ", hl = "NocturneRule" },
      { os.date("%I:%M %p"):lower(), hl = "NocturneAccent" },
      { "\n" .. buffer.screenager_dashboard_greeting, hl = "NocturneDim" },
    },
  }
end

local function keys_section(keys)
  return function()
    local items = {}
    for _, item in ipairs(keys) do
      local label = (item.desc or ""):gsub("%s+$", ""):lower()
      items[#items + 1] = {
        key = item.key,
        action = item.action,
        align = "center",
        text = {
          { (item.icon or "•") .. " ", hl = "NocturneAccent", width = 3 },
          { label, hl = "NocturneText", width = 27 },
          { item.key, hl = "NocturneKey", width = 2, align = "right" },
        },
      }
    end
    items[#items].padding = 2
    return items
  end
end

local function recent_work(dashboard)
  if dashboard._size.width < 70 or dashboard._size.height < 30 then return end
  local files = {}
  for file in require("snacks.dashboard").oldfiles() do
    files[#files + 1] = file
    if #files == 3 then break end
  end
  if #files == 0 then return end

  local items = { { align = "center", padding = 1, text = { { "recent", hl = "NocturneMuted" } } } }
  local ok, icons = pcall(require, "mini.icons")
  for index, file in ipairs(files) do
    local path = vim.fn.fnamemodify(file, ":~")
    local dir, name = vim.fn.fnamemodify(path, ":h"), vim.fn.fnamemodify(path, ":t")
    if vim.api.nvim_strwidth(dir) > 22 then dir = vim.fn.pathshorten(dir) end
    local icon, icon_hl = "", "NocturneMuted"
    if ok then icon, icon_hl = icons.get("file", name) end
    local used = vim.api.nvim_strwidth(dir .. "/" .. name)
    if used > 27 then name, used = vim.fn.strcharpart(name, 0, 25 - vim.api.nvim_strwidth(dir)) .. "…", 27 end
    items[#items + 1] = {
      key = tostring(index),
      action = ":edit " .. vim.fn.fnameescape(file),
      align = "center",
      text = {
        { icon .. " ", hl = icon_hl, width = 3 },
        { dir .. "/", hl = "NocturneDim" },
        { name .. string.rep(" ", math.max(0, 27 - used)), hl = "NocturneText" },
        { tostring(index), hl = "NocturneKey", width = 2, align = "right" },
      },
    }
  end
  items[#items].padding = 2
  return items
end

local function footer()
  local text = {}
  if live.track then
    text[#text + 1] = { "♪  ", hl = "NocturneAccent" }
    text[#text + 1] = { live.track.title, hl = "NocturneText" }
    if live.track.artist ~= "" then text[#text + 1] = { "  ·  " .. live.track.artist:lower(), hl = "NocturneMuted" } end
    text[#text + 1] = { "\n" }
  end
  local ok, stats = pcall(function() return require("lazy.stats").stats() end)
  if ok then
    local ms = math.floor((stats.startuptime or 0) * 10 + 0.5) / 10
    text[#text + 1] = { ("%d plugins"):format(stats.loaded or 0), hl = "NocturneDim" }
    text[#text + 1] = { "  ·  ", hl = "NocturneRule" }
    text[#text + 1] = { ("%sms"):format(ms), hl = "NocturneAccent2" }
  end
  if live.branch then
    text[#text + 1] = { "  ·  ", hl = "NocturneRule" }
    text[#text + 1] = { " " .. live.branch, hl = "NocturneDim" }
  end
  return { align = "center", text = text }
end

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}
      local keys = vim.deepcopy(opts.dashboard.preset.keys or {})

      opts.dashboard.width = 50
      opts.dashboard.sections = {
        logo_section,
        greeting_section,
        keys_section(keys),
        recent_work,
        footer,
      }

      -- motion: smooth scrolling and an animated indent scope (both cheap)
      opts.scroll = { animate = { duration = { step = 12, total = 160 }, easing = "outQuad" } }
      opts.indent = opts.indent or {}
      opts.indent.animate = { enabled = true, style = "out", duration = { step = 18, total = 260 } }

      logo_colors(nil) -- define the gradient before the first draw
      local group = vim.api.nvim_create_augroup("nocturne_dashboard", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "SnacksDashboardOpened",
        callback = function()
          logo_colors(nil)
          play_sweep()
          refresh_live()
        end,
      })
      vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = function() logo_colors(nil) end })
    end,
  },
}
