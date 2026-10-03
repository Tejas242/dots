-- Nocturne: UI accents that follow the desktop palette.
--
-- Code keeps Everforest (its syntax colours are more distinct than the Matugen
-- palette, where strings and functions share a green). The *chrome* (dashboard,
-- float borders, cursor line number, indent scope) takes its accents from the
-- wallpaper palette Noctalia writes into lua/matugen.lua, so Neovim matches the
-- bar and lock screen. Re-applied on every ColorScheme and on Matugen's SIGUSR1.
local M = {}

local fallback = {
  base00 = "#0f150e", base03 = "#889484", base04 = "#becab8", base05 = "#dee5d8",
  base09 = "#9ccaff", base0B = "#72dd71", base0E = "#a5d29e",
}

-- Read the palette straight out of the generated file instead of executing it:
-- matugen.lua's setup() would apply a full base16 scheme, which we don't want here.
function M.palette()
  local path = vim.fn.stdpath "config" .. "/lua/matugen.lua"
  local colors = vim.deepcopy(fallback)
  local fd = io.open(path, "r")
  if fd then
    for key, hex in fd:read("*a"):gmatch "(base0%x)%s*=%s*'(#%x%x%x%x%x%x)'" do
      colors[key] = hex
    end
    fd:close()
  end
  return {
    bg = colors.base00,
    fg = colors.base05,
    muted = colors.base04,
    dim = colors.base03,
    primary = colors.base0B,
    secondary = colors.base0E,
    tertiary = colors.base09,
  }
end

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

function M.mix(a, b, t)
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  local function ch(x, y) return math.floor(x + (y - x) * t + 0.5) end
  return string.format("#%02x%02x%02x", ch(ar, br), ch(ag, bg), ch(ab, bb))
end

function M.apply()
  local p = M.palette()
  M.colors = p
  local set = vim.api.nvim_set_hl
  -- dashboard
  set(0, "NocturneTitle", { fg = p.fg, bold = true })
  set(0, "NocturneText", { fg = p.fg })
  set(0, "NocturneMuted", { fg = p.muted })
  set(0, "NocturneDim", { fg = p.dim, italic = true })
  set(0, "NocturneAccent", { fg = p.primary })
  set(0, "NocturneAccent2", { fg = p.tertiary })
  set(0, "NocturneRule", { fg = M.mix(p.bg, p.dim, 0.45) })
  set(0, "NocturneKey", { fg = p.primary, bold = true })
  -- chrome that should match the desktop rather than Everforest's orange
  set(0, "FloatBorder", { fg = M.mix(p.bg, p.primary, 0.55) })
  set(0, "SnacksIndentScope", { fg = p.primary })
  set(0, "CursorLineNr", { fg = p.primary, bold = true })
  set(0, "WinSeparator", { fg = M.mix(p.bg, p.dim, 0.35) })
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("nocturne_accents", { clear = true }),
    callback = M.apply,
  })
end

return M
