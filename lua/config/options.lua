-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_picker = "telescope"
-- vim.g.lazyvim_cmp = "nvim-cmp"
vim.g.lazyvim_check_order = false

vim.opt.shiftwidth = 4
vim.o.pumblend = 0
vim.g.autoformat = false
vim.o.clipboard = "unnamedplus"

require("lazyvim.util").lsp.on_attach(function()
  vim.opt.signcolumn = "yes"
end)
