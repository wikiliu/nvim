return {
  "folke/snacks.nvim",
  opts = {
    styles = {
      terminal = {
        keys = {
          term_quit = {
            "<C-q>",
            function(self)
              local alt_win = vim.fn.win_getid(vim.fn.winnr("#"))

              self:hide()

              vim.schedule(function()
                if alt_win and vim.api.nvim_win_is_valid(alt_win) then
                  vim.api.nvim_set_current_win(alt_win)
                end
              end)
            end,
            mode = "t",
            desc = "Close terminal and focus last window",
          },
        },
        border = "double",
      },
    },
  },
}
