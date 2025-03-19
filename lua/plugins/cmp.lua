return {
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = {
      "rcarriga/cmp-dap",
    },
    opts = function(_, opts)
      local ok, cmp = pcall(require, "cmp")
      if not ok then
        vim.notify("nvim-cmp not found! Skipping configuration.", vim.log.levels.WARN)
        return opts
      end

      opts.window = {
        completion = cmp.config.window.bordered({
          border = "rounded",
          winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None",
        }),
        documentation = {
          border = "rounded",
          winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None",
        },
      }

      opts.enabled = function()
        return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt" or require("cmp_dap").is_dap_buffer()
      end
      cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
        sources = {
          { name = "dap" },
        },
      })
    end,
  },
}
