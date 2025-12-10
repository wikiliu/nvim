return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "murphy",
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        "<leader>uC",
        function()
          require("telescope.builtin").colorscheme({
            enable_preview = true,
            attach_mappings = function(prompt_bufnr, _)
              local actions = require("telescope.actions")
              actions.select_default:replace(function()
                local selection = require("telescope.actions.state").get_selected_entry()
                actions.close(prompt_bufnr)
                vim.cmd.colorscheme(selection.value)

                local config_file = vim.fn.stdpath("config") .. "/lua/plugins/colorscheme.lua"
                local lines = vim.fn.readfile(config_file)

                for i, line in ipairs(lines) do
                  if line:match("colorscheme%s*=") then
                    lines[i] = string.format('      colorscheme = "%s",', selection.value)
                    break
                  end
                end

                vim.fn.writefile(lines, config_file)
                vim.notify(
                  "Colorscheme set to: " .. selection.value .. "\nand saved to colorscheme.lua",
                  vim.log.levels.INFO
                )
              end)
              return true
            end,
          })
        end,
        desc = "Colorscheme with preview",
      },
    },
  },
}
