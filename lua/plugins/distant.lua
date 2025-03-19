return {
  "chipsenkbeil/distant.nvim",
  branch = "v0.3",
  config = function()
    require("distant"):setup({
      servers = {
        ["*"] = {
          -- Put something in here to override defaults for all servers
        },

        ["rickliu@10.30.160.6"] = {
          -- Change the current working directory and specify
          -- a path to the distant binary on the remote machine
          cwd = "/home/rickliu/ourSourceCode/source_gfx/",
          launch = {
            bin = "/home/rickliu/.local/bin/distant",
          },
        },
      },
    })
  end,
}
