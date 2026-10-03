-- Use AstroNvim v6's native completion engine for signature help as well.
---@type LazySpec
return {
  {
    "saghen/blink.cmp",
    opts = {
      signature = {
        enabled = true,
        window = {
          border = "single",
          show_documentation = false,
        },
      },
    },
  },
}
