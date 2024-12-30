return {
  "Saghen/blink.cmp",
  opts = function(_, opts)
    opts.keymap = {
      preset = "default",
      ["<S-k>"] = { "show", "show_documentation", "hide_documentation" },
      ["<enter>"] = { "select_and_accept" },
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
      ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      ["<C-d>"] = { "scroll_documentation_down", "fallback" },
      ["<A-Tab>"] = { "snippet_forward", "fallback" },
      ["<A-S-Tab>"] = { "snippet_backward", "fallback" },
    }
    opts.completion = {
      menu = { border = "single" },
      documentation = { window = { border = "single" } },
    }
    opts.signature = { window = { border = "single" } }
  end,
}
