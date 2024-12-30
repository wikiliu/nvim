return {
  "neovim/nvim-lspconfig",
  lazy = true,
  dependencies = {
    "jose-elias-alvarez/typescript.nvim",
    init = function()
      require("lazyvim.util").lsp.on_attach(function(_, buffer)
          -- stylua: ignore
        vim.keymap.set( "n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
        vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
      end)
    end,
  },
  opts = {
    setup = {
      clangd = function(_, opts)
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
    },
  },
}
