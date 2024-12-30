-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Mapping data with "desc" stored directly by vim.keymap.set().
--
-- Please use this mappings table to set keyboard mapping since this is the
-- lower level configuration and more robust one. (which-key will
-- automatically pick-up stored data by this setting.)
vim.keymap.set("n", "<leader>cs", "<cmd>SymbolsOutline<cr>", { desc = "Symbols Outline" })
vim.keymap.set("n", "<F7>", '<Cmd>execute v:count . "ToggleTerm"<CR>', { desc = "Term with border" })
vim.keymap.set("t", "<F7>", "<Cmd>ToggleTerm<CR>", { desc = "Term with border" })
vim.keymap.set("i", "<F7>", "<Esc><Cmd>ToggleTerm<CR>", { desc = "Term with border" })
vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Overseer Run Task" })
vim.keymap.set("n", "<leader>df", "<cmd>DiffFormatFile<cr>", { desc = "Diff format File" })
vim.keymap.set("n", "<leader><F7>", "<cmd>ToggleTerm size= 10 direction=horizontal<cr>", { desc = "Term horizontal" })
vim.keymap.set("n", "<leader>fg", LazyVim.pick("live_grep"), { desc = "Grep args" })
vim.keymap.set("n", "<leader>fM", "<cmd>Telescope bookmarks list<CR>", { desc = "List bookmarks" })
vim.keymap.set(
  "n",
  "mm",
  "<cmd>lua require('bookmarks').bookmark_toggle()<cr>",
  { desc = "add or remove bookmark at current line" }
)
vim.keymap.set(
  "n",
  "mc",
  "<cmd>lua require('bookmarks').bookmark_clean()<cr>",
  { desc = "clean all marks in local buffer" }
)
vim.keymap.set(
  "n",
  "mi",
  "<cmd>lua require('bookmarks').bookmark_ann()<cr>",
  { desc = "add or edit mark annotation at current line" }
)
vim.keymap.set(
  "n",
  "mn",
  "<cmd>lua require('bookmarks').bookmark_next()<cr>",
  { desc = "jump to next mark in local buffer" }
)
vim.keymap.set(
  "n",
  "mp",
  "<cmd>lua require('bookmarks').bookmark_prev()<cr>",
  { desc = "jump to previous mark in local buffer" }
)
vim.keymap.set(
  "n",
  "ml",
  "<cmd>lua require('bookmarks').bookmark_list()<cr>",
  { desc = "show marked file list in quickfix window" }
)
-- vim.keymap.set("n", "<F8>", "<cmd>Tagbar<cr>", { desc = "Open/Close tagbar" ,noremap = true})

vim.keymap.set("i", "jj", "<Esc>", { noremap = true })
