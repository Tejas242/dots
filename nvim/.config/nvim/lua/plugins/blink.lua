-- Completion: docs that appear on their own after a beat, and a
-- signature popup that stays out of the way.
---@type LazySpec
return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        menu = { scrollbar = false },
        documentation = { auto_show = true, auto_show_delay_ms = 250 },
        ghost_text = { enabled = true },
      },
      signature = {
        enabled = true,
        window = { border = "single", show_documentation = false },
      },
    },
  },
}
