-- This runs after Lazy has resolved the configuration.
--
-- Everforest owns the startup palette. When Matugen rewrites matugen.lua, it
-- can request a full Base16 palette refresh with:
--   kill -SIGUSR1 <nvim-pid>
--
-- Keep this watcher in a long-lived module. The generated Matugen module only
-- defines colors, so reloading it cannot register duplicate signal handlers.
local M = {}

local function apply_matugen_palette()
  package.loaded.matugen = nil
  local ok, matugen = pcall(require, "matugen")
  if not ok then
    vim.notify("Unable to load the generated Matugen palette: " .. matugen, vim.log.levels.ERROR)
    return
  end
  matugen.setup()
end

M.matugen_signal = assert((vim.uv or vim.loop).new_signal())
M.matugen_signal:start("sigusr1", vim.schedule_wrap(apply_matugen_palette))

return M
