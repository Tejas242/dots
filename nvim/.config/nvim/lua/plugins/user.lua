-- You can also add or configure plugins by creating files in this `plugins/` folder
-- Here are all user plugins migrated from the old v5 config:

---@type LazySpec
return {

  -- == Third-party Plugins ==

  -- Required by matugen.lua: provides require('base16-colorscheme').setup(...)
  -- Loaded lazily; matugen.lua calls it on SIGUSR1 to swap colors at runtime.
  { "RRethy/nvim-base16", lazy = true },

  "andweeb/presence.nvim",
  {
    "xeluxee/competitest.nvim",
    -- This intentionally starts at launch so Competitive Companion can connect
    -- before the first CompetiTest key is pressed.
    lazy = false,
    dependencies = "MunifTanjim/nui.nvim",
    keys = {
      { "<leader>rr", "<cmd>CompetiTest run<cr>", desc = "Run Testcases" },
      { "<leader>ra", "<cmd>CompetiTest add_testcase<cr>", desc = "Add Testcase" },
      { "<leader>re", "<cmd>CompetiTest edit_testcase<cr>", desc = "Edit Testcase" },
      { "<leader>ri", "<cmd>CompetiTest receive problem<cr>", desc = "Receive Problem" },
      { "<leader>rc", "<cmd>CompetiTest receive contest<cr>", desc = "Receive Contest" },
      { "<leader>ru", "<cmd>CompetiTest show_ui<cr>", desc = "CompetiTest UI" },
    },
    config = function()
      local home = os.getenv "HOME"
      local competitest = require "competitest"
      local cpp_compile_args = {
        "-std=c++20",
        "-O2",
        "-Wall",
        "-I" .. home .. "/CP/lib",
        "$(FNAME)",
        "-o",
        "$(FNOEXT)",
      }
      -- Opt in to local-only code paths with: CP_LOCAL=1 nvim
      if vim.env.CP_LOCAL == "1" then table.insert(cpp_compile_args, 3, "-DLOCAL") end

      -- --- HELPER FUNCTIONS FOR 2156A / 2156/A.cpp STRUCTURE ---
      local function get_contest_id(task)
        local url = task.url
        if not url then return nil end
        local cf_id = url:match "codeforces%.com/contest/(%d+)"
        if not cf_id then cf_id = url:match "codeforces%.com/problemset/problem/(%d+)" end
        if cf_id then return cf_id end
        local ac_id = url:match "atcoder%.jp/contests/([^/]+)"
        if ac_id then return ac_id end
        return nil
      end

      local function get_problem_index(task)
        -- Competitive companion sends names like "A. Two Permutations".
        -- ^(%S+) would capture "A." (dot is non-whitespace) → double dot in filename.
        -- ^([%w]+) captures only alphanumeric chars → clean "A".
        local idx = task.name:match "^([%w]+)"
        return idx or task.name
      end
      -- ---------------------------------------------------------

      competitest.setup {
        local_config_file_name = ".competitest.lua",

        floating_border = "single",
        floating_border_highlight = "FloatBorder",

        picker_ui = {
          width = 0.2,
          height = 0.3,
          mappings = {
            focus_next = { "j", "<down>", "<Tab>" },
            focus_prev = { "k", "<up>", "<S-Tab>" },
            close = { "<esc>", "<C-c>", "q", "Q" },
            submit = "<cr>",
          },
        },
        editor_ui = {
          popup_width = 0.4,
          popup_height = 0.6,
          show_nu = true,
          show_rnu = false,
          normal_mode_mappings = {
            switch_window = { "<C-h>", "<C-l>", "<C-i>" },
            save_and_close = "<C-s>",
            cancel = { "q", "Q" },
          },
          insert_mode_mappings = {
            switch_window = { "<C-h>", "<C-l>", "<C-i>" },
            save_and_close = "<C-s>",
            cancel = "<C-q>",
          },
        },
        runner_ui = {
          interface = "popup",
          selector_show_nu = false,
          selector_show_rnu = false,
          show_nu = true,
          show_rnu = false,
          mappings = {
            run_again = "R",
            run_all_again = "<C-r>",
            kill = "K",
            kill_all = "<C-k>",
            view_input = { "i", "I" },
            view_output = { "a", "A" },
            view_stdout = { "o", "O" },
            view_stderr = { "e", "E" },
            toggle_diff = { "d", "D" },
            close = { "q", "Q", "<Esc>" },
          },
          viewer = {
            width = 0.5,
            height = 0.5,
            show_nu = true,
            show_rnu = false,
            open_when_compilation_fails = true,
          },
        },
        popup_ui = {
          total_width = 0.8,
          total_height = 0.8,
          layout = {
            { 4, "tc" },
            { 5, { { 1, "so" }, { 1, "si" } } },
            { 5, { { 1, "eo" }, { 1, "se" } } },
          },
        },
        split_ui = {
          position = "right",
          relative_to_editor = true,
          total_width = 0.3,
          vertical_layout = {
            { 1, "tc" },
            { 1, { { 1, "so" }, { 1, "eo" } } },
            { 1, { { 1, "si" }, { 1, "se" } } },
          },
          total_height = 0.4,
          horizontal_layout = {
            { 2, "tc" },
            { 3, { { 1, "so" }, { 1, "si" } } },
            { 3, { { 1, "eo" }, { 1, "se" } } },
          },
        },

        save_current_file = true,
        save_all_files = true,
        compile_directory = ".",
        compile_command = {
          cpp = {
            exec = "g++",
            args = cpp_compile_args,
          },
        },
        running_directory = ".",
        run_command = {
          cpp = { exec = "./$(FNOEXT)" },
        },

        multiple_testing = -1,
        maximum_time = 5000,
        output_compare_method = "squish",
        view_output_diff = false,

        testcases_directory = ".testcases",
        testcases_use_single_file = false,
        testcases_auto_detect_storage = true,
        testcases_single_file_format = "$(FNOEXT).testcases",
        testcases_input_file_format = "$(FNOEXT)_in_$(TCNUM).txt",
        testcases_output_file_format = "$(FNOEXT)_out_$(TCNUM).txt",

        companion_port = 27121,
        receive_print_message = true,
        start_receiving_persistently_on_setup = true,
        template_file = home .. "/CP/lib/template.cpp",
        evaluate_template_modifiers = true,
        date_format = "%c",
        received_files_extension = "cpp",

        -- Dynamic Path Logic
        received_problems_path = function(task, file_extension)
          local id = get_contest_id(task)
          local index = get_problem_index(task)
          if id then return string.format("%s/%s.%s", id, index, file_extension) end
          -- fallback: use contest/name structure; guard against nil contest
          local contest = task.contest or "unknown_contest"
          return string.format("%s/%s.%s", contest, task.name, file_extension)
        end,

        received_problems_prompt_path = false,
        received_contests_directory = "$(CWD)",
        received_contests_problems_path = function(task, file_extension)
          local id = get_contest_id(task)
          local index = get_problem_index(task)
          if id then return string.format("%s/%s.%s", id, index, file_extension) end
          -- fallback: guard against nil contest
          local contest = task.contest or "unknown_contest"
          return string.format("%s/%s.%s", contest, task.name, file_extension)
        end,
        received_contests_prompt_directory = false,
        received_contests_prompt_extension = false,
        open_received_problems = true,
        open_received_contests = true,
        replace_received_testcases = false,
      }
    end,
  },

  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000,
    config = function()
      -- Everforest owns the startup palette. Matugen deliberately replaces the
      -- full palette only after it sends SIGUSR1; see lua/polish.lua.
      vim.g.everforest_enable_italic = true
      vim.g.everforest_background = "hard"
      vim.g.everforest_transparent_background = 2
      vim.cmd.colorscheme "everforest"
    end,
  },

  -- == Overriding Default Plugins ==

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })

      -- include the default astronvim config that calls the setup call
      require "astronvim.plugins.configs.luasnip"(plugin, opts)
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
}
