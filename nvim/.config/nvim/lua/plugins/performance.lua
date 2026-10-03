-- Startup policy: a contest source file should reach an editable buffer before
-- project-only tooling is loaded. The AstroCommunity C++ pack attaches CMake
-- Tools (and its DAP/Mason/terminal stack) to every .cpp file, which is not
-- useful for a standalone solution.cpp.
--
-- CMake files still load it automatically. From any other buffer, invoking a
-- :CMake… command loads the exact same plugin and its integrations on demand.
---@type LazySpec
return {
  -- Retain the useful, lightweight parts of the C++ pack.
  {
    "AstroNvim/astrocore",
    init = function()
      -- Starting Tree-sitter for C-family parsers can block long enough to
      -- leave a blank terminal. Do it one scheduled tick after the first UI
      -- frame; every buffer opened after startup still gets it immediately.
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("screenager_deferred_c_treesitter", { clear = true }),
        once = true,
        callback = function()
          local buffer = vim.api.nvim_get_current_buf()
          vim.schedule(function()
            if
              vim.api.nvim_buf_is_valid(buffer)
              and ({ c = true, cpp = true, objc = true, cuda = true, proto = true })[vim.bo[buffer].filetype]
            then
              vim.b[buffer].screenager_treesitter_ready = true
              require("lazy").load { plugins = { "nvim-treesitter" } }
              vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buffer) then require("astrocore.treesitter").enable(buffer) end
              end)
            end
          end)
        end,
      })
    end,
    opts = function(_, opts)
      opts.treesitter.ensure_installed = require("astrocore").list_insert_unique(opts.treesitter.ensure_installed, {
        "cpp",
        "c",
        "objc",
        "cuda",
        "proto",
      })
      opts.treesitter.enabled = function(language, buffer)
        -- The initial C-family buffer is enabled by the VimEnter callback
        -- above. Once the UI exists, retain AstroNvim's normal immediate
        -- behavior for every buffer.
        return vim.v.vim_did_enter == 1
          or vim.b[buffer].screenager_treesitter_ready == true
          or not ({ c = true, cpp = true, objc = true, cuda = true, proto = true })[language]
      end
    end,
  },
  {
    "AstroNvim/astrolsp",
    opts = function(_, opts)
      opts.servers = require("astrocore").list_insert_unique(opts.servers, { "clangd" })
      opts.config = vim.tbl_deep_extend("keep", opts.config, {
        clangd = { capabilities = { offsetEncoding = "utf-8" } },
      })
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "clangd" })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "codelldb" })
    end,
  },
  {
    "andweeb/presence.nvim",
    event = "VeryLazy",
  },
  {
    "Civitasv/cmake-tools.nvim",
    opts = {},
    ft = { "cmake" },
    cmd = {
      "CMakeGenerate",
      "CMakeClean",
      "CMakeBuild",
      "CMakeQuickBuild",
      "CMakeInstall",
      "CMakeRun",
      "CMakeQuickRun",
      "CMakeRunCurrentFile",
      "CMakeBuildCurrentFile",
      "CMakeDebug",
      "CMakeQuickDebug",
      "CMakeDebugCurrentFile",
      "CMakeRunTest",
      "CMakeStopExecutor",
      "CMakeStopRunner",
      "CMakeCloseExecutor",
      "CMakeCloseRunner",
      "CMakeOpenExecutor",
      "CMakeOpenRunner",
      "CMakeOpenCache",
      "CMakeLaunchArgs",
      "CMakeSelectBuildType",
      "CMakeSelectKit",
      "CMakeSelectConfigurePreset",
      "CMakeSelectBuildPreset",
      "CMakeSelectTestPreset",
      "CMakeSelectBuildTarget",
      "CMakeSelectLaunchTarget",
      "CMakeTargetSettings",
      "CMakeSettings",
      "CMakeSelectCwd",
      "CMakeSelectBuildDir",
      "CMakeQuickStart",
      "CMakeShowTargetFiles",
    },
    dependencies = {
      {
        "jay-babu/mason-nvim-dap.nvim",
        opts = function(_, opts)
          opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, { "codelldb" })
        end,
      },
    },
  },
}
