-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
	vim.opt.shiftwidth=4
	vim.o.pumblend = 0
	vim.g.autoformat = false

	require("lazyvim.util").lsp.on_attach(function()
	  vim.opt.signcolumn = "yes"
	end)
	vim.cmd([[autocmd VimEnter * lua require('select-dir').load_dir()]])
	vim.cmd([[autocmd VimLeave * lua require('select-dir').save_dir()]])

