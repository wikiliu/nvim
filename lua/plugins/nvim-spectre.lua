return {
  "nvim-pack/nvim-spectre",
  dependencies = { "nvim-lua/plenary.nvim" },

  lazy = true,
  opts = function(_, opts)
    opts.previewWindow.border = "rounded"
    return opts
  end,
}
