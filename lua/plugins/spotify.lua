return {
  "KadoBOT/nvim-spotify",
  dependencies = { "nvim-telescope/telescope.nvim" },
  build = "make",
  config = function()
    local spotify = require("nvim-spotify")
    vim.api.nvim_set_keymap("n", "<leader>sn", "<Plug>(SpotifySkip)", { silent = true }) -- Skip the current track
    vim.api.nvim_set_keymap("n", "<leader>sp", "<Plug>(SpotifyPause)", { silent = true }) -- Pause/Resume the current track
    vim.api.nvim_set_keymap("n", "<leader>ss", "<Plug>(SpotifySave)", { silent = true }) -- Add the current track to your library
    vim.api.nvim_set_keymap("n", "<leader>so", ":Spotify<CR>", { silent = true }) -- Open Spotify Search window
    vim.api.nvim_set_keymap("n", "<leader>sd", ":SpotifyDevices<CR>", { silent = true }) -- Open Spotify Devices window
    vim.api.nvim_set_keymap("n", "<leader>sb", "<Plug>(SpotifyPrev)", { silent = true }) -- Go back to the previous track
    vim.api.nvim_set_keymap("n", "<leader>sh", "<Plug>(SpotifyShuffle)", { silent = true }) -- Toggles shuffle mode

    spotify.setup({
      -- default opts
      status = {
        update_interval = 10000, -- interval (ms) to poll Spotify status
        format = "%s %t by %a", -- format like spotify-tui
      },
    })
  end,
  event = "VeryLazy", -- 可以按需更换加载时机，比如 "BufEnter"
}
