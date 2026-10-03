-- A quiet, responsive start screen. The original Screenager mark stays central;
-- the supporting content appears only when the terminal has room for it.
local logo = table.concat({
  "╔═╗╔═╗╦═╗╔═╗╔═╗╔╗╔╔═╗╔═╗╔═╗╦═╗",
  "╚═╗║  ╠╦╝║╣ ║╣ ║║║╠═╣║ ╦║╣ ╠╦╝",
  "╚═╝╚═╝╩╚═╚═╝╚═╝╝╚╝╩ ╩╚═╝╚═╝╩╚═",
}, "\n")

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

local function greeting_section(dashboard)
  local buffer = vim.b[dashboard.buf]
  buffer.screenager_dashboard_greeting = buffer.screenager_dashboard_greeting or next_greeting()
  local user = vim.env.USER ~= "" and vim.env.USER or "screenager"

  return {
    align = "center",
    padding = 2,
    text = {
      { ("%s, %s."):format(salutation(), user), hl = "title" },
      { "\n" .. buffer.screenager_dashboard_greeting, hl = "footer" },
    },
  }
end

local function recent_work(dashboard)
  -- Do not crowd short terminals. This function is re-evaluated on resize.
  if dashboard._size.width < 70 or dashboard._size.height < 28 then return end

  local oldfiles = require("snacks.dashboard").oldfiles()
  local files = {}
  for file in oldfiles do
    files[#files + 1] = file
    if #files == 3 then break end
  end
  if #files == 0 then return end

  local items = {
    {
      align = "center",
      padding = 1,
      text = { { "recent work", hl = "footer" } },
    },
  }
  for index, file in ipairs(files) do
    local path = vim.fn.fnamemodify(file, ":~")
    if vim.api.nvim_strwidth(path) > 35 then path = vim.fn.pathshorten(path) end
    items[#items + 1] = {
      action = ":edit " .. vim.fn.fnameescape(file),
      align = "center",
      key = tostring(index),
      text = {
        { tostring(index), align = "right", hl = "key", width = 3 },
        { "  " .. path, align = "left", hl = "file", width = 37 },
      },
    }
  end
  items[#items].padding = 2
  return items
end

local function startup_stats()
  local ok, stats = pcall(function() return require("lazy.stats").stats() end)
  if not ok then return end
  local milliseconds = math.floor((stats.startuptime or 0) * 100 + 0.5) / 100
  return {
    align = "center",
    text = {
      { ("%d plugins"):format(stats.loaded or 0), hl = "footer" },
      { "  ·  ", hl = "footer" },
      { ("%sms"):format(milliseconds), hl = "special" },
    },
  }
end

---@type LazySpec
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      opts.dashboard.preset = opts.dashboard.preset or {}

      -- Keep AstroNvim's existing actions and keymaps; only alter their display.
      local keys = vim.deepcopy(opts.dashboard.preset.keys or {})
      for _, item in ipairs(keys) do
        local label = (item.desc or ""):gsub("%s+$", ""):lower()
        item.align = "center"
        item.text = {
          { item.key, align = "right", hl = "key", width = 3 },
          { "  " .. label, align = "left", hl = "desc", width = 20 },
        }
      end

      opts.dashboard.width = 44
      opts.dashboard.preset.header = logo
      opts.dashboard.preset.keys = keys
      opts.dashboard.sections = {
        { section = "header", padding = 1 },
        greeting_section,
        { section = "keys", gap = 0, padding = 1 },
        recent_work,
        startup_stats,
      }
    end,
  },
}
