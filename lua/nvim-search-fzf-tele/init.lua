local M = {}

-- 引入核心逻辑
local core = require("nvim-search-fzf-tele.core")

M.setup = function()
  vim.cmd([[autocmd VimEnter * lua require("nvim-search-fzf-tele").load_dir()]])
  vim.cmd([[autocmd VimLeave * lua require("nvim-search-fzf-tele").save_dir()]])

  vim.keymap.set("n", "<F2>", function()
    core.list_history_dir()
  end, { desc = "show search base directory" })
  vim.keymap.set("n", "<leader><F2>", function()
    core.deal_dirs()
  end, { desc = "modified search base directory" })
  vim.keymap.set("n", "[<F2>", function()
    core.move_prev()
  end, { desc = "Prev of search directory" })
  vim.keymap.set("n", "]<F2>", function()
    core.move_next()
  end, { desc = "Next of search directory" })
  vim.keymap.set("n", "<leader>f<F2>", function()
    core.dir_history()
  end, { desc = "History of search directory" })

  vim.keymap.set("v", "<C-f>", function()
    local base_search_dir = vim.g.base_search_dir

    if base_search_dir == nil or base_search_dir == "" then
      base_search_dir = core.load_dir()
    end

    local _, ls, cs = unpack(vim.fn.getpos("v"))
    local _, le, ce = unpack(vim.fn.getpos("."))

    ls, le = math.min(ls, le), math.max(ls, le)
    cs, ce = math.min(cs, ce), math.max(cs, ce)
    local under_cursor = vim.api.nvim_buf_get_text(0, ls - 1, cs - 1, le - 1, ce, {})

    local word_under_cursor = under_cursor[1] or ""

    require("fzf-lua").live_grep({
      search = word_under_cursor,
      cwd = base_search_dir,
    })
  end, { desc = "Find visual word in path folder" })

  vim.keymap.set({ "n", "i", "t" }, "<C-f>", function()
    local base_search_dir = vim.g.base_search_dir or vim.loop.cwd()
    if base_search_dir == nil or base_search_dir == "" then
      base_search_dir = core.load_dir()
    end

    vim.notify(
      "Find in: "
        .. (base_search_dir:sub(#vim.loop.cwd() + 2) ~= "" and base_search_dir:sub(#vim.loop.cwd() + 2) or "."),
      vim.log.levels.INFO
    )
    require("fzf-lua").live_grep({
      cwd = base_search_dir,
    })
  end, { desc = "Find word in path folder" })

  vim.keymap.set({ "n", "i", "t" }, "<C-A-f>", function()
    local base_search_dir = vim.g.base_search_dir or vim.loop.cwd()
    if base_search_dir == nil or base_search_dir == "" then
      base_search_dir = core.load_dir()
    end

    vim.notify(
      "Find in: "
        .. (base_search_dir:sub(#vim.loop.cwd() + 2) ~= "" and base_search_dir:sub(#vim.loop.cwd() + 2) or "."),
      vim.log.levels.INFO
    )
    require("fzf-lua").files({
      cwd = base_search_dir,
    })
  end, { desc = "Find word in path folder" })

  vim.keymap.set(
    "n",
    "<leader>fi",
    "<cmd> lua require('nvim-search-fzf-tele').my_find_i()<cr>",
    { desc = "Find cursor word in path folder" }
  )
  vim.keymap.set(
    "n",
    "<leader>fI",
    "<cmd> lua require('nvim-search-fzf-tele').MY_FIND_I()<cr>",
    { desc = "Find word in path folder" }
  )
  vim.keymap.set(
    "n",
    "<leader>fd",
    "<cmd>lua require('nvim-search-fzf-tele').deal_dirs(nil, 'grep')<CR>",
    { desc = "Grep in directory" }
  )
  vim.keymap.set(
    "n",
    "<leader>fD",
    "<cmd>lua require('nvim-search-fzf-tele').deal_dirs(nil, 'files')<CR>",
    { desc = "File in directory" }
  )
end

M.move_prev = core.move_prev
M.move_next = core.move_next
M.dir_history = core.dir_history
M.load_dir = core.load_dir
M.save_dir = core.save_dir
M.MY_FIND_I = core.MY_FIND_I
M.my_find_i = core.my_find_i
M.list_history_dir = core.list_history_dir
M.save_unique_string = core.save_unique_string
M.deal_dirs = core.deal_dirs
return M
