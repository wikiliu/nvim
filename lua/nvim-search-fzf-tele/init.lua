local M = {}

-- 引入核心逻辑
local core = require("nvim-search-fzf-tele.core")

M.setup = function()
  vim.cmd([[autocmd VimEnter * lua require("nvim-search-fzf-tele").load_dir()]])
  vim.cmd([[autocmd VimLeave * lua require("nvim-search-fzf-tele").save_dir()]])
end

M.get_dirs = core.git_dirs
M.move_prev = core.move_prev
M.move_next = core.move_next
M.dir_history = core.dir_history
M.load_dir = core.load_dir
M.MY_FIND_I = core.MY_FIND_I
M.my_find_i = core.my_find_i
M.list_history_dir = core.list_history_dir
M.save_unique_string = core.save_unique_string
M.fzf_get_dirs = core.fzf_get_dirs
return M
