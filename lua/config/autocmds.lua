-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here


-- Disable autoformat for lua files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "lua" ,"python"},
  callback = function()
    vim.b.autoformat = true
  end,
})



vim.api.nvim_create_user_command('DiffFormat', function()
  local lines = vim.fn.system('git diff --unified=0'):gmatch('[^\n\r]+')
  local ranges = {}
  for line in lines do
    if line:find('^@@') then
      local line_nums = line:match('%+.- ')
      if line_nums:find(',') then
        local _, _, first, second = line_nums:find('(%d+),(%d+)')
        table.insert(ranges, {
          start = { tonumber(first), 0 },
          ['end'] = { tonumber(first) + tonumber(second), 0 },
        })
      else
        local first = tonumber(line_nums:match('%d+'))
        table.insert(ranges, {
          start = { first, 0 },
          ['end'] = { first + 1, 0 },
        })
      end
    end
  end
  local format = require('conform').format
  for _, range in pairs(ranges) do
    format {
      range = range,
    }
  end
end, { desc = 'Format changed lines' })
