local get_path = function(state)
  local node = state.tree:get_node()
  if node.type == "directory" then
    return node.path
  end
  return node:get_parent_id()
end
local do_setcd = function(state)
  local p = get_path(state)
  print(p) -- show in command line
  vim.cmd(string.format('exec(":lcd %s")', p))
  return p
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "miversen33/netman.nvim",
  },
  opts = function(_, opts)
    opts.commands = {}

    opts.commands.copy_locate_path = function(state)
      local node = state.tree:get_node()
      local path = node:get_id()
      path = node.type == "directory" and path or vim.fn.fnamemodify(path, ":h")
      path = path .. "/"
      vim.fn.setreg("l", path)
      vim.g.base_search_dir = path
      require("select-dir").save_unique_string(vim.g.base_search_dir)
      vim.notify(path, "info", {
        title = "base seach dir",
      })

      path = vim.fn.fnamemodify(path, ":~:.:h")

      -- 设置寄存器
      local register = "l"
      vim.cmd("let @" .. register .. " = " .. vim.fn.string(path))
    end
    opts.commands.grep_in_path = function(state)
      local node = state.tree:get_node()
      local path = node:get_id()
      path = node.type == "directory" and path or vim.fn.fnamemodify(path, ":h")
      require("telescope.builtin").live_grep({ search_dirs = { path } })
    end
    opts.commands.spectre = function(state)
      local p = do_setcd(state)
      require("grug-far").grug_far({ prefills = { paths = p } })

      -- require("spectre").open({
      --   is_insert_mode = true,
      --   cwd = p,
      --   is_close = false, -- close an exists instance of spectre and open new
      -- })
    end

    opts.window.mappings.L = "copy_locate_path"
    opts.window.mappings.G = "grep_in_path"
    opts.window.mappings["<leader>r"] = "spectre"

    opts.window.mappings.uu = {
      function(state)
        vim.cmd("TransferUpload " .. state.tree:get_node().path)
      end,
      desc = "upload file or directory",
      nowait = true,
    }

    -- download (sync files)
    opts.window.mappings.ud = {
      function(state)
        vim.cmd("TransferDownload" .. state.tree:get_node().path)
      end,
      desc = "download file or directory",
      nowait = true,
    }

    -- diff directory with remote
    opts.window.mappings.uf = {
      function(state)
        local node = state.tree:get_node()
        local context_dir = node.path
        if node.type ~= "directory" then
          -- if not a directory
          -- one level up
          context_dir = context_dir:gsub("/[^/]*$", "")
        end
        vim.cmd("TransferDirDiff " .. context_dir)
        vim.cmd("Neotree close")
      end,
      desc = "diff with remote",
    }

    opts.commands.find_in_dir = function(state)
      local node = state.tree:get_node()
      local path = node.type == "file" and node:get_parent_id() or node:get_id()
      require("telescope.builtin").find_files({ cwd = path })
    end
    opts.window.mappings.F = "find_in_dir"

    local toggleterm_in_direction = function(state, direction)
      local node = state.tree:get_node()
      local path = node.type == "file" and node:get_parent_id() or node:get_id()
      require("toggleterm.terminal").Terminal:new({ dir = path, direction = direction }):toggle()
    end
    local prefix = "T"
    ---@diagnostic disable-next-line: assign-type-mismatch
    opts.window.mappings[prefix] =
      { "show_help", nowait = false, config = { title = "New Terminal", prefix_key = prefix } }
    for suffix, direction in pairs({ f = "float", h = "horizontal", v = "vertical" }) do
      local command = "toggleterm_" .. direction
      opts.commands[command] = function(state)
        toggleterm_in_direction(state, direction)
      end
      opts.window.mappings[prefix .. suffix] = command
    end

    opts.commands.parent_or_close = function(state)
      local node = state.tree:get_node()
      if (node.type == "directory" or node:has_children()) and node:is_expanded() then
        state.commands.toggle_node(state)
      else
        require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
      end
    end
    opts.window.mappings.h = "parent_or_close"
    opts.window.width = 30
  end,
}
