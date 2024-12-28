local uv = vim.loop
local flatten = vim.tbl_flatten
local M = {}
-- 之后可以加上cache到vim内存中
local project_root = vim.fn.getcwd()

M.save_unique_string = function(str)
  local newT = {}
  for _, v in ipairs(vim.g.dir_cache) do
    if v ~= str and type(v) == "string" and type(str) == "string" then
      table.insert(newT, v)
    end
  end
  table.insert(newT, str)
  if #newT > 20 then
    table.remove(newT, 1)
  end
  vim.g.dir_cache = newT
end

M.write_file = function(path, content)
  uv.fs_open(path, "w", 438, function(open_err, fd)
    assert(not open_err, open_err)
    uv.fs_write(fd, content, -1, function(write_err)
      assert(not write_err, write_err)
      uv.fs_close(fd, function(close_err)
        assert(not close_err, close_err)
      end)
    end)
  end)
end

local function ensure_cache_directory_exists()
  local cache_dir = vim.fn.expand("~/.cache")
  local dir_history_file = cache_dir .. "/dir_search_history_vim.json"

  -- 创建缓存文件夹
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
  end

  -- 创建缓存文件
  if vim.fn.filereadable(dir_history_file) == 0 then
    M.write_file(dir_history_file, "")
  end
end

M.save_dir = function()
  if vim.g.dir_cache == nil or #vim.g.dir_cache == 0 then
    return
  end
  ensure_cache_directory_exists()
  local dir_cache = vim.g.dir_cache
  local current_dir = vim.fn.getcwd()
  local cache_file = vim.fn.expand("~/.cache/dir_search_history_vim.json")

  local existing_data = {}

  local f = io.open(cache_file, "r")
  if f then
    local json_data = f:read("*a")
    f:close()
    if json_data ~= "" then
      local data = vim.json.decode(json_data)

      if data ~= nil then
        for _, entry in ipairs(data) do
          local entry_dir = entry.current_dir

          if current_dir ~= entry_dir then
            table.insert(existing_data, entry)
          end
        end
      else
        print("No directory history found for the current directory.")
      end
    else
      print("No directory history found.")
    end
  end

  local new_data = { current_dir = current_dir, dir_cache = vim.g.dir_cache }
  table.insert(existing_data, new_data)

  local json_data = vim.json.encode(existing_data)
  M.write_file(cache_file, json_data)
end

M.load_dir = function()
  ensure_cache_directory_exists()
  local current_dir = vim.fn.getcwd()
  local cache_file = vim.fn.expand("~/.cache/dir_search_history_vim.json")
  -- 读取文件内容
  vim.g.dir_cache = {}
  local f = io.open(cache_file, "r")
  if f then
    local json_data = f:read("*a")
    f:close()
    if json_data == "" then
      return
    end
    local data = vim.json.decode(json_data)

    if data ~= nil then
      for _, entry in ipairs(data) do
        local entry_dir = entry.current_dir

        if current_dir == entry_dir then
          vim.g.dir_cache = entry.dir_cache
          break
        end
      end
    else
      table.insert(vim.g.dir_cache, current_dir)
      print("No directory history found for the current directory.")
    end
  else
    print("No directory history found.")
  end
  if vim.g.dir_cache == nil then
    table.insert(vim.g.dir_cache, current_dir)
  end
  return vim.g.dir_cache[#vim.g.dir_cache]
end

local opts_in = {
  hidden = true,
  debug = false,
  no_ignore = false,
  show_preview = true,
}

local function run_find_command(opts)
  -- 构造 find 命令
  local find_command = nil
  if opts.find_command then
    if type(opts.find_command) == "function" then
      find_command = opts.find_command(opts)
    else
      find_command = opts.find_command
    end
  elseif vim.fn.executable("fd") == 1 then
    find_command = { "fd", "--type", "d", "--color", "never" }
  elseif vim.fn.executable("fdfind") == 1 then
    find_command = { "fdfind", "--type", "d", "--color", "never" }
  elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
    find_command = { "find", ".", "-type", "d" }
  end

  if not find_command then
    vim.notify("You need to install either `find` or `fd`/`fdfind`.", vim.log.levels.ERROR)
    return nil
  end

  -- 添加额外选项
  if opts.hidden and (find_command[1] == "fd" or find_command[1] == "fdfind") then
    table.insert(find_command, "--hidden")
  end
  if opts.no_ignore and (find_command[1] == "fd" or find_command[1] == "fdfind") then
    table.insert(find_command, "--no-ignore")
  end
  if opts.follow_symlinks and (find_command[1] == "fd" or find_command[1] == "fdfind") then
    table.insert(find_command, "--follow")
  end

  return find_command
end

M.fzf_get_dirs = function(opts, callback)
  opts = opts or {}

  if opts.debug then
    vim.notify("Starting directory search...", vim.log.levels.INFO)
  end

  local find_command = run_find_command(opts)
  if not find_command then
    return
  end

  -- 使用 `fzf-lua` 显示结果
  local job_id = vim.fn.jobstart(find_command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or vim.tbl_isempty(data) then
        vim.notify("No directories found.", vim.log.levels.WARN)
        return
      end

      -- 过滤掉 `.git` 目录
      local results = vim.tbl_filter(function(line)
        return not line:match("^%.git")
      end, data)

      if opts.debug then
        print("Directories found: " .. vim.inspect(results))
      end

      require("fzf-lua").fzf_exec(results, {
        prompt = "Select a Directory> ",
        actions = {
          ["default"] = function(selected)
            if not selected or vim.tbl_isempty(selected) then
              vim.notify("No directory selected.", vim.log.levels.WARN)
              return
            end

            if opts.debug then
              print("Selected directories: " .. vim.inspect(selected))
            end

            local root = vim.fn.getcwd()
            if #selected == 1 then
              vim.g.base_search_dir = root .. "/" .. selected[1]
            end
            M.save_unique_string(vim.g.base_search_dir)
            vim.notify(root .. "/" .. selected[1], "info", {
              title = "base seach dir",
            })
            if callback ~= nil then
              callback({ cwd = vim.g.base_search_dir })
            end
          end,
        },
      })
    end,
    on_stderr = function(_, err_data)
      vim.notify("Error during directory search: " .. vim.inspect(err_data), vim.log.levels.ERROR)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start find command.", vim.log.levels.ERROR)
  end
end

M.telescope_get_dirs = function()
  local find_command = (function()
    if opts_in.find_command then
      if type(opts_in.find_command) == "function" then
        return opts_in.find_command(opts_in)
      end
      return opts_in.find_command
    elseif 1 == vim.fn.executable("fd") then
      return { "fd", "--type", "d", "--color", "never" }
    elseif 1 == vim.fn.executable("fdfind") then
      return { "fdfind", "--type", "d", "--color", "never" }
    elseif 1 == vim.fn.executable("find") and vim.fn.has("win32") == 0 then
      return { "find", ".", "-type", "d" }
    end
  end)()

  if not find_command then
    vim.notify("dir-telescope", {
      msg = "You need to install either find, fd",
      level = vim.log.levels.ERROR,
    })
    return
  end

  local command = find_command[1]
  local hidden = opts_in.hidden
  local no_ignore = opts_in.no_ignore

  if opts_in.respect_gitignore then
    vim.notify("dir-telescope: respect_gitignore is deprecated, use no_ignore instead", vim.log.levels.ERROR)
  end

  if command == "fd" or command == "fdfind" or command == "rg" then
    if hidden then
      find_command[#find_command + 1] = "--hidden"
    end
    if no_ignore then
      find_command[#find_command + 1] = "--no-ignore"
    end
  elseif command == "find" then
    if not hidden then
      table.insert(find_command, { "-not", "-path", "*/.*" })
      find_command = flatten(find_command)
    end
    if no_ignore ~= nil then
      vim.notify("The `no_ignore` key is not available for the `find` command in `get_dirs`.", vim.log.levels.WARN)
    end
  else
    vim.notify("dir-telescope: You need to install either find or fd/fdfind", vim.log.levels.ERROR)
  end

  local getPreviewer = function()
    if opts_in.show_preview then
      local conf = require("telescope.config").values
      return conf.file_previewer(opts_in)
    else
      return nil
    end
  end
  vim.fn.jobstart(find_command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        require("telescope.pickers")
          .new(opts_in, {
            prompt_title = "Select a Directory",
            finder = require("telescope.finders").new_table({
              results = data,
              entry_maker = require("telescope.make_entry").gen_from_file(opts_in),
            }),
            previewer = getPreviewer(),
            sorter = conf.file_sorter(opts_in),
            attach_mappings = function(prompt_bufnr)
              local action_set = require("telescope.actions.set")
              local actions = require("telescope.actions")
              action_set.select:replace(function()
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                local dirs = {}
                local selections = current_picker:get_multi_selection()
                if vim.tbl_isempty(selections) then
                  table.insert(dirs, action_state.get_selected_entry().value)
                else
                  for _, selection in ipairs(selections) do
                    table.insert(dirs, selection.value)
                  end
                end
                actions._close(prompt_bufnr, current_picker.initial_mode == "insert")
                local root = vim.fn.getcwd()
                if #dirs == 1 then
                  vim.g.base_search_dir = root .. "/" .. dirs[1]
                end
                M.save_unique_string(vim.g.base_search_dir)
                vim.notify(root .. "/" .. dirs[1], "info", {
                  title = "base seach dir",
                })
              end)
              return true
            end,
          })
          :find()
      else
        vim.notify("No directories found", vim.log.levels.ERROR)
      end
    end,
  })
end

M.get_dirs = function()
  if LazyVim.pick.picker.name == "fzf" then
    M.fzf_get_dirs()
  elseif LazyVim.pick.picker.name == "telescope" then
    M.telescope_get_dirs()
  end
end

M.dir_history = function(opts)
  opts = opts or {}
  local dirlist = {}
  if vim.g.dir_cache ~= nil then
    for _, line in pairs(vim.g.dir_cache) do
      if type(line) == "string" then
        table.insert(dirlist, 1, line)
      end
    end
  else
    dirlist = nil
  end

  if LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").fzf_exec(dirlist, {
      prompt = "folder_history> ",
      actions = {
        ["default"] = function(selected)
          if not selected or selected[1] == "" then
            vim.g.base_search_dir = vim.fn.getcwd()
          else
            vim.g.base_search_dir = selected[1]
          end

          M.save_unique_string(vim.g.base_search_dir)

          vim.notify(vim.g.base_search_dir, "info", {
            title = "Base Search Dir",
          })
        end,
      },
    })
  elseif LazyVim.pick.picker.name == "telescope" then
    local actions = require("telescope.actions")
    local conf = require("telescope.config").values
    local picker = require("telescope.pickers")
      .new(opts, {
        prompt_title = "folder_history",
        finder = require("telescope.finders").new_table(dirlist),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            if selection == nil or selection.value == "" then
              vim.g.base_search_dir = vim.fn.getcwd()
            else
              vim.g.base_search_dir = selection.value
            end
            M.save_unique_string(vim.g.base_search_dir)
            vim.notify(vim.g.base_search_dir, "info", {
              title = "base seach dir",
            })
            actions.close(prompt_bufnr)
          end)
          return true
        end,
      })
      :find()
  end
end

M.move_prev = function()
  if vim.g.dir_stack_pt == nil then
    vim.g.dir_stack_pt = #vim.g.dir_cache
  end
  vim.g.dir_stack_pt = vim.g.dir_stack_pt - 1
  if vim.g.dir_stack_pt <= 0 then
    vim.g.dir_stack_pt = 1
    vim.g.base_search_dir = vim.g.dir_cache[1]
    vim.notify(vim.g.base_search_dir, "info", {
      title = "base seach dir",
    })
    return vim.g.dir_cache[1]
  else
    vim.g.base_search_dir = vim.g.dir_cache[vim.g.dir_stack_pt]
    vim.notify(vim.g.base_search_dir, "info", {
      title = "base seach dir",
    })
    return vim.g.dir_cache[vim.g.dir_stack_pt]
  end
end

M.move_next = function()
  if vim.g.dir_stack_pt == nil then
    vim.g.dir_stack_pt = #vim.g.dir_cache
  end
  vim.g.dir_stack_pt = vim.g.dir_stack_pt + 1
  if vim.g.dir_stack_pt > #vim.g.dir_cache then
    vim.g.dir_stack_pt = #vim.g.dir_cache
    vim.g.base_search_dir = vim.g.dir_cache[#vim.g.dir_cache]
    vim.notify(vim.g.base_search_dir, "info", {
      title = "base seach dir",
    })
    return vim.g.dir_cache[#vim.g.dir_cache]
  else
    vim.g.base_search_dir = vim.g.dir_cache[vim.g.dir_stack_pt]
    vim.notify(vim.g.base_search_dir, "info", {
      title = "base seach dir",
    })
    return vim.g.dir_cache[vim.g.dir_stack_pt]
  end
end

M.list_history_dir = function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = M.load_dir()
  end
  if base_search_dir ~= nil then
    vim.notify(base_search_dir, "info", {
      title = "base seach dir",
    })
  else
    vim.notify("Null", "info", {
      title = "base seach dir",
    })
  end
end

M.my_find_i = function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = M.load_dir()
  end

  local word_under_cursor = vim.fn.expand("<cword>")

  if LazyVim.pick.picker.name == "telescope" then
    require("telescope").extensions.live_grep_args.live_grep_args({
      default_text = word_under_cursor,
      search_dirs = { base_search_dir },
      postfix = "--fixed-strings",
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").live_grep({
      search = word_under_cursor,
      cwd = base_search_dir,
    })
  end
end

M.MY_FIND_I = function()
  local base_search_dir = vim.g.base_search_dir
  if base_search_dir == nil or base_search_dir == "" then
    base_search_dir = M.load_dir()
  end

  if LazyVim.pick.picker.name == "telescope" then
    require("telescope").extensions.live_grep_args.live_grep_args({
      search_dirs = { base_search_dir },
      postfix = "--fixed-strings",
    })
  elseif LazyVim.pick.picker.name == "fzf" then
    require("fzf-lua").live_grep({
      cwd = base_search_dir,
    })
  end
end

return M
