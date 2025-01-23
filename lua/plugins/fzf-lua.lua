return {
  "ibhagwan/fzf-lua",
  opts = function(_, opts)
    require("nvim-search-fzf-tele").setup()
    opts.fzf_opts["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history"
    opts.fzf_opts = { ["--cycle"] = true }
    vim.keymap.set("n", "<leader>f<CR>", function()
      require("fzf-lua").resume()
    end, { desc = "Resume previous search" })
  end,
  config = function(_, opts)
    if opts[1] == "default-title" then
      -- use the same prompt for all pickers for profile `default-title` and
      -- profiles that use `default-title` as base profile
      local function fix(t)
        t.prompt = t.prompt ~= nil and " " or nil
        for _, v in pairs(t) do
          if type(v) == "table" then
            fix(v)
          end
        end
        return t
      end
      opts = vim.tbl_deep_extend("force", fix(require("fzf-lua.profiles.default-title")), opts)
      opts[1] = nil
    end
    opts.actions = {
      files = {
        ["enter"] = {
          fn = function(sel, o)
            require("fzf-lua").hide()
            require("fzf-lua.actions").file_edit_or_qf(sel, o)
          end,
          exec_silent = true,
        },
      },
    }
    opts.keymap = {
      builtin = {
        true,
        ["<Esc>"] = "hide",
      },
    }
    require("fzf-lua").setup(opts)
  end,
}
