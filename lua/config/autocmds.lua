-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Disable autoformat for lua files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "lua" },
  callback = function()
    vim.b.autoformat = true
  end,
})

vim.api.nvim_create_user_command("DiffFormatFile", function()
  -- 获取当前文件的完整路径
  local filepath = vim.fn.expand("%:p")

  -- 获取当前缓冲区的编号
  local bufnr = vim.api.nvim_get_current_buf()

  -- 执行git diff命令只针对当前文件
  local diff_cmd = "git diff --unified=0 " .. vim.fn.shellescape(filepath)

  local diff_output = vim.fn.system(diff_cmd)
  local lines = diff_output:gmatch("[^\n\r]+")
  local ranges = {}
  for line in lines do
    if line:find("^@@") then
      local line_nums = line:match("%+.- ")
      if line_nums:find(",") then
        local _, _, first, second = line_nums:find("(%d+),(%d+)")
        print(first)
        table.insert(ranges, {
          start = { tonumber(first), 0 },
          ["end"] = { tonumber(first) + tonumber(second), 0 },
        })
      else
        local first = tonumber(line_nums:match("%d+"))
        table.insert(ranges, {
          start = { first, 0 },
          ["end"] = { first + 1, 0 },
        })
      end
    end
  end
  local format = require("conform").format
  for _, range in pairs(ranges) do
    format({
      range = range,
    })
  end
end, { desc = "Format changed file" })

vim.api.nvim_create_user_command("DiffFormatFile", function()
  local tracked_files = vim.fn.systemlist("git ls-files")
  local diff_cmd = "git diff --unified=0 -- " .. table.concat(tracked_files, " ")
  local diff_output = vim.fn.system(diff_cmd)
  local lines = diff_output:gmatch("[^\n\r]+")
  local ranges = {}
  for line in lines do
    if line:find("^@@") then
      local line_nums = line:match("%+.- ")
      if line_nums:find(",") then
        local _, _, first, second = line_nums:find("(%d+),(%d+)")
        print(first)
        table.insert(ranges, {
          start = { tonumber(first), 0 },
          ["end"] = { tonumber(first) + tonumber(second), 0 },
        })
      else
        local first = tonumber(line_nums:match("%d+"))
        table.insert(ranges, {
          start = { first, 0 },
          ["end"] = { first + 1, 0 },
        })
      end
    end
  end
  local format = require("conform").format
  for _, range in pairs(ranges) do
    format({
      range = range,
    })
  end
end, { desc = "Format changed lines" })

-- 安全加载本地配置
local local_config = vim.fn.getcwd() .. "/.vscode/.nvim.lua"
if vim.fn.filereadable(local_config) == 1 then
  dofile(local_config)
end
