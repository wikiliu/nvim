return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    { "nvim-telescope/telescope-fzf-native.nvim", enabled = vim.fn.executable("make") == 1, build = "make" },
    "nvim-telescope/telescope-live-grep-args.nvim",
  },
  cmd = "Telescope",
  opts = function(_, opts)
    require("telescope").load_extension("live_grep_args")
    require("telescope").load_extension("bookmarks")
    local actions = require("telescope.actions")
    opts.defaults = opts.defaults or {}
    opts.defaults.mappings = opts.defaults.mappings or {}
    opts.defaults.mappings.i = opts.defaults.mappings.i or {}
    opts.defaults.mappings.i["<A-g>"] = require("telescope-live-grep-args.actions").quote_prompt()
    opts.defaults.mappings.i["<A-i>"] =
      require("telescope-live-grep-args.actions").quote_prompt({ postfix = " --iglob " })

    opts.defaults = {
      git_worktrees = vim.g.git_worktrees,
      path_display = { "truncate" },
      sorting_strategy = "ascending",
      layout_config = {
        horizontal = { prompt_position = "top", preview_width = 0.55 },
        vertical = { mirror = false },
        width = 0.87,
        height = 0.80,
        preview_cutoff = 120,
      },
      mappings = {
        i = {
          ["<C-n>"] = actions.cycle_history_next,
          ["<C-p>"] = actions.cycle_history_prev,
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
        },
        n = { q = actions.close },
      },
    }
  end,
}
