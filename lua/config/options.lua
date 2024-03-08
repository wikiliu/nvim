-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

	vim.cmd([[autocmd VimEnter * lua require('select-dir').load_dir()]])
	vim.cmd([[autocmd VimLeave * lua require('select-dir').save_dir()]])
