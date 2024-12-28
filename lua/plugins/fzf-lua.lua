return {
  "ibhagwan/fzf-lua",
  opts = function(_, opts)
    require("nvim-search-fzf-tele").setup()
    opts.fzf_opts["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history"
  end,
}
