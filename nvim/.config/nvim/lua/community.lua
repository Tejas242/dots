-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  -- everforest is configured directly in plugins/user.lua with custom vim.g.* settings
  -- (no community colorscheme import needed)

  -- Language packs
  { import = "astrocommunity.pack.go" },
  -- C++ is configured explicitly in plugins/performance.lua. The community
  -- pack eagerly attaches a full CMake/DAP stack to every standalone .cpp
  -- file, which is the wrong trade-off for contest work.
}
