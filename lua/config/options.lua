-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local dap = require("dap")
vim.g.lazyvim_picker = "telescope"
vim.g.lazyvim_cmp = "nvim-cmp"

dap.configurations.cpp = {
  {
    name = "Launch file",
    type = "cppdbg",
    request = "launch",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopAtEntry = true,
  },
  {
    MIMode = "gdb",
    miDebuggerServerAddress = "10.30.16.114:1234", -- 修改为你的gdbserver地址和端口
    miDebuggerPath = "/usr/bin/gdb", -- 修改为你的gdb路径
    setupCommands = {
      {
        description = "Enable pretty-printing for gdb",
        text = "-enable-pretty-printing",
        ignoreFailures = false,
      },
    },
  },
}

vim.opt.shiftwidth = 4
vim.o.pumblend = 0
vim.g.autoformat = false
vim.o.clipboard = "unnamedplus"

require("lazyvim.util").lsp.on_attach(function()
  vim.opt.signcolumn = "yes"
end)
vim.cmd([[autocmd VimEnter * lua require('utils.select-dir').load_dir()]])
vim.cmd([[autocmd VimLeave * lua require('utils.select-dir').save_dir()]])
