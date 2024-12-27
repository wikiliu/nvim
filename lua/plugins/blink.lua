return {
  "Saghen/blink.cmp",
  opts = function(_, opts)
    opts.keymap = { preset = "super-tab" }
    opts.completion = {
      menu = { border = "single" },
      documentation = { window = { border = "single" } },
    }
    opts.signature = { window = { border = "single" } }
  end,
}
