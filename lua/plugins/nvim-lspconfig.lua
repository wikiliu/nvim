return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/typescript.nvim",
    },
    opts = {
      servers = {
        tsserver = {},
      },
      setup = {
        clangd = function(_, opts)
          opts.root_markers = {
            ".git",
            "compile_commands.json",
            "compile_flags.txt",
            "configure.ac", -- AutoTools
            "Makefile",
            "configure.ac",
            "configure.in",
            "config.h.in",
            "meson.build",
            "meson_options.txt",
            "build.ninja",
          }
          opts.capabilities.offsetEncoding = { "utf-16" }
          if not opts.cmd then
            opts.cmd = { "clangd" }
          end
          local function is_git_repo()
            local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
            if handle then
              local result = handle:read("*a")
              handle:close()
              if result then
                return result:match("true") ~= nil
              end
            end
            return false
          end
          if is_git_repo() then
            table.insert(opts.cmd, "--header-insertion=never")
          end
        end,
        tsserver = function(_, opts)
          require("typescript").setup({ server = opts })
          return true
        end,
      },
    },
    init = function()
      require("lazyvim.util").lsp.on_attach(function(_, buffer)
        vim.keymap.set("n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
        vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { buffer = buffer, desc = "Rename File" })
      end)
    end,
  },
}
