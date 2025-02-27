return {
  "ibhagwan/fzf-lua",
  opts = function(_, opts)
    local fzf = require("fzf-lua")
    opts.fzf_opts = {
      ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history",
      ["--cycle"] = true,
    }
    local config = fzf.config
    config.defaults.keymap.fzf["ctrl-f"] = "half-page-up"
    config.defaults.keymap.fzf["ctrl-b"] = "half-page-down"

    config.defaults.keymap.fzf["ctrl-u"] = "preview-page-down"
    config.defaults.keymap.fzf["ctrl-d"] = "preview-page-up"
    config.defaults.keymap.builtin["<c-d>"] = "preview-page-down"
    config.defaults.keymap.builtin["<c-u>"] = "preview-page-up"

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
