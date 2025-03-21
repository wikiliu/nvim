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
vim.keymap.set("n", "<leader>fi", function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = require("utils.select-dir").load_dir()
  end
  local word_under_cursor = vim.fn.expand("<cword>")
  require("telescope").extensions.live_grep_args.live_grep_args({
    default_text = word_under_cursor,
    search_dirs = { base_search_dir },
    postfix = "--fixed-strings",
  })
end, { desc = "Find cursor word in path folder" })
vim.keymap.set("n", "<leader>fI", function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = require("utils.select-dir").load_dir()
  end
  require("telescope").extensions.live_grep_args.live_grep_args({
    search_dirs = { base_search_dir },
    postfix = "--fixed-strings",
  })
end, { desc = "Find word in path folder" })
vim.keymap.set(
  "n",
  "<leader>fg",
  "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<cr>",
  { desc = "Grep args" }
)
vim.keymap.set("n", "<leader>fd", "<cmd>Telescope dir live_grep<CR>", { desc = "Grep in directory" })
vim.keymap.set("n", "<leader>fD", "<cmd>FileInDirectory<CR>", { desc = "File in directory" })
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
vim.keymap.set("n", "<F2>", function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = require("utils.select-dir").load_dir()
  end
  if base_search_dir ~= nil then
    vim.notify(base_search_dir, "info", {
      title = "base seach dir",
    })
  else
    vim.notify("Null", "info", {
      title = "base seach dir",
    })
  end
end, { desc = "show search base directory" })
vim.keymap.set("n", "<leader><F2>", function()
  require("utils.select-dir").get_dirs()
end, { desc = "modified search base directory" })
vim.keymap.set("n", "[<F2>", function()
  require("utils.select-dir").move_prev()
end, { desc = "Prev of search directory" })
vim.keymap.set("n", "]<F2>", function()
  require("utils.select-dir").move_next()
end, { desc = "Next of search directory" })
vim.keymap.set("n", "<leader>f<F2>", function()
  require("utils.select-dir").dir_history()
end, { desc = "History of search directory" })

vim.keymap.set("v", "<C-f>", function()
  local base_search_dir = vim.g.base_search_dir

  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = require("utils.select-dir").load_dir()
  end

  local _, ls, cs = unpack(vim.fn.getpos("v"))
  local _, le, ce = unpack(vim.fn.getpos("."))

  ls, le = math.min(ls, le), math.max(ls, le)
  cs, ce = math.min(cs, ce), math.max(cs, ce)
  local word_under_cursor = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})
  word_under_cursor = word_under_cursor[1] or ""
  require("telescope.builtin").live_grep({
    postfix = "  --regexp ",
    default_text = word_under_cursor,
    search_dirs = { base_search_dir },
  })
end, { desc = "Find visual word in path folder" })

vim.keymap.set("i", "jj", "<Esc>", { noremap = true })
vim.keymap.set("n", "<leader>f<CR>", function()
  require("telescope.builtin").resume()
end, { desc = "Resume previous search" })

vim.keymap.set({ "n", "i", "t" }, "<C-f>", function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = require("utils.select-dir").load_dir()
  end
  require("telescope").extensions.live_grep_args.live_grep_args({
    search_dirs = { base_search_dir },
    postfix = "--fixed-strings",
  })
end, { desc = "Find word in path folder" })
