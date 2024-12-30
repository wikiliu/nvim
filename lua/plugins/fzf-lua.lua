return {
  "ibhagwan/fzf-lua",
  opts = function(_, opts)
    require("nvim-search-fzf-tele").setup()
    opts.fzf_opts["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history"
    opts.fzf_opts = { ["--cycle"] = true }
    vim.keymap.set("n", "<leader>f<CR>", function()
      require("fzf-lua").resume()
    end, { desc = "Resume previous search" })
  end,
}
