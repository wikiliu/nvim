return {
  dir = vim.fn.stdpath("config") .. "/local-plugins/make_target",
  main = "make_target",
  lazy = true,
  cmd = {
    "CMakePickBuild",
    "CMakePickTarget",
    "CMakeConfigure",
    "MakeTargetScp",
    "MakeTargetLazyDocker",
  },
  opts = {
    scp = {
      enable = true,
      user = "rickliu",
      ip = "10.30.16.114",
      remote_dir = "/home/rickliu/driver",
      password = "1",
      prefer = "auto",
      depth_files = 6,
      keep_artifacts = 5,
      lemonade = true,
    },
    container_name = "source_gfx",
    run_in_docker = true,
    container_shell = "bash",
    jobs = 24,
    search_depth = 2,
    search_nested = false,
    terminal = { provider = "toggleterm", direction = "float", height = 15 },
    root_strategy = "outermost_git",
  },
  config = function(_, opts)
    require("make_target").setup(opts)
    pcall(function()
      require("make_target.scp").setup(opts.scp or {})
    end)
  end,
  keys = {
    { "<leader>fs", "<cmd>MakeTargetScp<cr>", desc = "SCP artifact" },
    { "<leader>cb", "<cmd>CMakePickBuild<cr>", desc = "Pick/create build dir" },
    { "<leader>ct", "<cmd>CMakePickTarget<cr>", desc = "Pick target" },
    { "<leader>cc", "<cmd>CMakeConfigure<cr>", desc = "Open shell in build dir" },
    { "<leader>lz", "<cmd>MakeTargetLazyDocker<cr>", desc = "lazydocker" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    { "akinsho/toggleterm.nvim", version = "*" },
  },
}
