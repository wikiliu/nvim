return {
  "stevearc/overseer.nvim",
  dependencies = {
    "akinsho/toggleterm.nvim",
  },
  cmd = "OverseerRun",
  lazy = true,
  config = function()
    require("overseer").setup({
      strategy = {
        "toggleterm",
        -- load your default shell before starting the task
        use_shell = true,
        -- overwrite the default toggleterm "direction" parameter
        direction = "horizontal",
        -- overwrite the default toggleterm "highlights" parameter
        highlights = table,
        -- overwrite the default toggleterm "auto_scroll" parameter
        auto_scroll = true,
        -- have the toggleterm window close and delete the terminal buffer
        -- automatically after the task exits
        close_on_exit = false,
        -- have the toggleterm window close without deleting the terminal buffer
        -- automatically after the task exits
        -- can be "never, "success", or "always". "success" will close the window
        -- only if the exit code is 0.
        quit_on_exit = "success",
        -- open the toggleterm window when a task starts
        open_on_start = true,
        -- mirrors the toggleterm "hidden" parameter, and keeps the task from
        -- being rendered in the toggleable window
        hidden = true,
        -- command to run when the terminal is created. Combine with `use_shell`
        -- to run a terminal command before starting the task
        on_create = nil,
      },
    })
  end,
}
