local M = {}
local Path = require("plenary.path")
local scan = require("plenary.scandir")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local cfg = {}
local mounts_cache = nil

M.state = { last_build_dir_by_root = {} }

local function load_scp()
  local ok, mod = pcall(require, "make_target.scp")
  if ok then
    return mod
  end
  ok, mod = pcall(require, "scp")
  if ok then
    return mod
  end
  return nil
end

-- ===== history per project (stored in <root>/.vscode/make_target_history.json) =====
local hist_cache = {} -- key: root -> { build = { {path,ts}, ...}, targets = { [build_dir_real] = { {name,ts}, ... } } }

local function realpath(p)
  local rp = vim.loop.fs_realpath(p)
  if rp and rp ~= "" then
    return rp
  end
  return Path:new(p):absolute()
end

local function ensure_vscode_dir(root)
  local vs = Path:new(root, ".vscode").filename
  if vim.fn.isdirectory(vs) == 0 then
    vim.fn.mkdir(vs, "p")
  end
  return vs
end

local function hist_path(root)
  ensure_vscode_dir(root)
  return Path:new(root, ".vscode", "make_target_history.json").filename
end

local function load_history(root)
  if hist_cache[root] then
    return hist_cache[root]
  end
  local p = hist_path(root)
  local f = io.open(p, "r")
  if not f then
    hist_cache[root] = { build = {}, targets = {} }
    return hist_cache[root]
  end
  local s = f:read("*a")
  f:close()
  local ok, obj = pcall(vim.json.decode, s)
  if ok and type(obj) == "table" then
    hist_cache[root] = vim.tbl_deep_extend("force", { build = {}, targets = {} }, obj)
  else
    hist_cache[root] = { build = {}, targets = {} }
  end
  return hist_cache[root]
end

local function save_history(root)
  if cfg.history and cfg.history.persist == false then
    return
  end
  local p = hist_path(root)
  local data = hist_cache[root] or { build = {}, targets = {} }
  local ok, s = pcall(vim.json.encode, data)
  if not ok then
    return
  end
  local f = io.open(p, "w")
  if not f then
    return
  end
  f:write(s)
  f:close()
end

local function touch_build_dir(root, dir)
  local H = load_history(root)
  local keep = (cfg.history and cfg.history.keep_builds) or 3
  H.build = H.build or {}
  local arr, rp = {}, realpath(dir)
  table.insert(arr, { path = rp, ts = os.time() })
  for _, it in ipairs(H.build) do
    if realpath(it.path) ~= rp then
      table.insert(arr, it)
    end
  end
  while #arr > keep do
    table.remove(arr)
  end
  H.build = arr
  save_history(root)
end

local function recent_build_dirs(root)
  local H = load_history(root)
  local arr = H.build or {}
  table.sort(arr, function(a, b)
    return (a.ts or 0) > (b.ts or 0)
  end)
  local out, keep = {}, (cfg.history and cfg.history.keep_builds) or 3
  for i, it in ipairs(arr) do
    if i > keep then
      break
    end
    table.insert(out, realpath(it.path))
  end
  return out
end

local function touch_target(root, build_dir, target)
  local H = load_history(root)
  local keep = (cfg.history and cfg.history.keep_targets) or 3
  H.targets = H.targets or {}
  local key = realpath(build_dir)
  local arr = H.targets[key] or {}
  local new = { { name = target, ts = os.time() } }
  for _, it in ipairs(arr) do
    if it.name ~= target then
      table.insert(new, it)
    end
  end
  while #new > keep do
    table.remove(new)
  end
  H.targets[key] = new
  save_history(root)
end

local function recent_targets(root, build_dir)
  local H = load_history(root)
  local key = realpath(build_dir)
  local arr = (H.targets or {})[key] or {}
  table.sort(arr, function(a, b)
    return (a.ts or 0) > (b.ts or 0)
  end)
  local out, keep = {}, (cfg.history and cfg.history.keep_targets) or 3
  for i, it in ipairs(arr) do
    if i > keep then
      break
    end
    table.insert(out, it.name)
  end
  return out
end

-- ===== git root helpers =====
local function has_git(dir)
  if not dir or dir == "" then
    return false
  end
  return Path:new(dir, ".git"):exists()
end

local function parent(dir)
  return Path:new(dir):parent().filename
end

-- root_strategy: 'outermost_git' (default) or 'nearest_git'
local function find_project_root(start)
  local start_dir = start or vim.fn.expand("%:p:h")
  local dir = Path:new(start_dir):absolute()

  if cfg.root_strategy == "nearest_git" then
    local d = dir
    while d and d ~= "" do
      if has_git(d) and not has_git(parent(d)) then
        return d
      end
      local p = parent(d)
      if p == d then
        break
      end
      d = p
    end
    local top = vim.fn.systemlist("git -C " .. vim.fn.fnameescape(start_dir) .. " rev-parse --show-toplevel")[1]
    if top and top ~= "" and vim.v.shell_error == 0 then
      return top
    end
    return nil
  end

  local last_git, d = nil, dir
  while d and d ~= "" do
    if has_git(d) then
      last_git = d
    end
    local p = parent(d)
    if p == d then
      break
    end
    d = p
  end
  if last_git then
    return last_git
  end

  local top = vim.fn.systemlist("git -C " .. vim.fn.fnameescape(start_dir) .. " rev-parse --show-toplevel")[1]
  if top and top ~= "" and vim.v.shell_error == 0 then
    return top
  end
  return nil
end

-- ===== build dir discovery (root-only default) =====
local function dedupe_keep_order(list)
  local out, seen = {}, {}
  for _, p in ipairs(list) do
    local np = realpath(p)
    if not seen[np] then
      seen[np] = true
      table.insert(out, np)
    end
  end
  return out
end

local function find_build_dirs(root)
  local results = {}
  if cfg.search_nested then
    scan.scan_dir(root, {
      hidden = false,
      add_dirs = true,
      only_dirs = true,
      depth = cfg.search_depth or 2,
      on_insert = function(d)
        local name = vim.fn.fnamemodify(d, ":t")
        if name:match("^build") then
          table.insert(results, d)
        end
      end,
    })
  else
    local entries = scan.scan_dir(root, { hidden = false, add_dirs = true, only_dirs = true, depth = 1, silent = true })
    for _, d in ipairs(entries or {}) do
      local name = vim.fn.fnamemodify(d, ":t")
      if name:match("^build") then
        table.insert(results, d)
      end
    end
  end
  results = dedupe_keep_order(results)
  table.sort(results)
  return results
end

-- ===== docker + path map =====
local function ensure_container()
  if not cfg.run_in_docker then
    return true
  end
  local names = vim.fn.systemlist("docker ps --format '{{.Names}}'")
  if vim.v.shell_error ~= 0 then
    vim.notify("[make_target] docker not available", vim.log.levels.ERROR)
    return false
  end
  for _, n in ipairs(names) do
    if n == cfg.container_name then
      return true
    end
  end
  vim.notify(string.format("[make_target] container '%s' not running", cfg.container_name), vim.log.levels.ERROR)
  return false
end

local function load_mounts()
  if mounts_cache ~= nil then
    return mounts_cache
  end
  if not cfg.run_in_docker then
    mounts_cache = {}
    return mounts_cache
  end
  local out =
    vim.fn.system("docker inspect -f '{{json .Mounts}}' " .. vim.fn.shellescape(cfg.container_name) .. " 2>/dev/null")
  if vim.v.shell_error ~= 0 or not out or out == "" then
    mounts_cache = {}
    return mounts_cache
  end
  local ok, mounts = pcall(vim.fn.json_decode, out)
  if not ok or type(mounts) ~= "table" then
    mounts_cache = {}
    return mounts_cache
  end
  table.sort(mounts, function(a, b)
    return (#(a.Source or "") > #(b.Source or ""))
  end)
  mounts_cache = mounts
  return mounts_cache
end

local function auto_map_path(host)
  local mounts = load_mounts()
  for _, m in ipairs(mounts) do
    local src = m.Source or ""
    local dst = m.Destination or ""
    if src ~= "" and dst ~= "" and host:sub(1, #src) == src then
      local sub = host:sub(#src + 1)
      if sub == "" then
        return dst
      end
      if dst:sub(-1) == "/" then
        return dst .. sub:gsub("^/", "")
      end
      return dst .. sub
    end
  end
  return host
end

local function container_path(p)
  local f = cfg.host_to_container_path
  if type(f) == "function" then
    local ok, mapped = pcall(f, p)
    if ok and mapped and mapped ~= "" then
      return mapped
    end
  end
  return auto_map_path(p)
end

-- ===== terminal =====
local function ensure_toggleterm_loaded()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    pcall(lazy.load, { plugins = { "toggleterm.nvim" } })
  end
  local ok, tt = pcall(require, "toggleterm.terminal")
  if not ok then
    return false, nil
  end
  return true, tt
end

local function float_geom()
  local wr = (cfg.terminal and (cfg.terminal.float and cfg.terminal.float.width)) or 0.5
  local hr = (cfg.terminal and (cfg.terminal.float and cfg.terminal.float.height)) or 0.5
  local yr = (cfg.terminal and (cfg.terminal.float and cfg.terminal.float.row)) or 0.1
  local width = math.max(20, math.floor(vim.o.columns * wr))
  local height = math.max(5, math.floor(vim.o.lines * hr))
  local row = math.max(0, math.floor((vim.o.lines - height) * yr))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  return width, height, row, col
end

local function default_title()
  local cname = (cfg.container_name or "container"):gsub("_", "")
  return "in_docker_" .. cname
end
local function open_terminal_native(cmd, cwd, opts)
  local width, height, row, col = float_geom()
  local title = (opts and opts.title) or (cfg.terminal and cfg.terminal.title) or default_title()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  vim.api.nvim_buf_call(buf, function()
    vim.fn.termopen(cmd, {
      cwd = cwd,
      on_exit = function(_, code, _)
        if opts and type(opts.on_exit) == "function" then
          pcall(opts.on_exit, code)
        end
      end,
    })
    vim.cmd("startinsert")
  end)
  vim.schedule(function()
    pcall(vim.cmd, "startinsert")
  end)
end

local function open_terminal(cmd, cwd, opts)
  local provider = (cfg.terminal and cfg.terminal.provider) or "toggleterm"
  if provider == "toggleterm" then
    local ok, tt = ensure_toggleterm_loaded()
    if ok then
      local width, height, row, col = float_geom()
      local title = (opts and opts.title) or (cfg.terminal and cfg.terminal.title) or default_title()
      local term = tt.Terminal:new({
        cmd = cmd,
        dir = cwd,
        direction = "float",
        close_on_exit = false,
        start_in_insert = true,
        hidden = false,
        float_opts = {
          border = "rounded",
          width = width,
          height = height,
          row = row,
          col = col,
          title = title,
          title_pos = "center",
        },
        on_open = function(_)
          pcall(vim.cmd, "startinsert")
          vim.schedule(function()
            pcall(vim.cmd, "startinsert")
          end)
        end,
      })
      term:open()
      -- attach on-exit (TermClose) for toggleterm
      if opts and type(opts.on_exit) == "function" then
        local bufnr = term.bufnr
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_create_autocmd("TermClose", {
            buffer = bufnr,
            once = true,
            callback = function()
              local code = tonumber(vim.v.event.status) or 0
              pcall(opts.on_exit, code)
            end,
          })
        end
      end
      return
    else
      vim.notify("[make_target] toggleterm not available, falling back to native terminal", vim.log.levels.WARN)
    end
  end
  open_terminal_native(cmd, cwd, opts)
end

-- === post-build SCP prompt ===
local function prompt_scp_after_build()
  local scp_cfg = cfg.scp or {}
  if scp_cfg.enable == false then
    return
  end
  local default_ip = scp_cfg.default_ip or scp_cfg.ip
  local default_user = scp_cfg.user or "rickliu"
  local remote_dir = scp_cfg.remote_dir or "/tmp"
  local target_label = (default_ip and (default_user .. "@" .. default_ip .. ":" .. remote_dir)) or "<no IP address>"
  local ans = vim.fn.input(string.format("SCP to %s? [y/N/o]: ", target_label))
  if ans == "y" or ans == "Y" then
    if not default_ip or default_ip == "" then
      return vim.notify("[make_target] Default SCP IP not set", vim.log.levels.WARN)
    end

    local scp = load_scp()
    if scp then
      scp.setup({ user = default_user, remote_dir = remote_dir })
      scp.pick()
    else
      vim.notify("[make_target] Cannot find scp.lua module", vim.log.levels.ERROR)
    end
  elseif ans == "o" or ans == "O" then
    local ip = vim.fn.input("Enter target IP: ")
    if ip and ip ~= "" then
      local scp = load_scp()
      if scp then
        scp.setup({ user = default_user, ip = ip, remote_dir = remote_dir })
        scp.pick()
      else
        vim.notify("[make_target] Cannot find scp.lua module", vim.log.levels.ERROR)
      end
    end
  end
end

local function build_shell_cmd_inside(workdir, shell_cmd)
  if cfg.run_in_docker then
    local in_container = container_path(workdir)
    local shell = cfg.container_shell or "bash"
    return string.format("docker exec -it -w %q %s %s -lc %q", in_container, cfg.container_name, shell, shell_cmd)
  else
    return shell_cmd
  end
end

local function open_shell_in_build_dir(build_dir)
  if not ensure_container() then
    return
  end
  local cmd
  if cfg.run_in_docker then
    cmd = string.format(
      "docker exec -it -w %q %s %s",
      container_path(build_dir),
      cfg.container_name,
      cfg.container_shell or "bash"
    )
  else
    cmd = vim.o.shell
  end
  open_terminal(cmd, build_dir, { title = default_title() })
end

-- Wipe a build directory (rm -rf then recreate). Safe guards included.
local function clean_build_dir(dir, root)
  local abs_dir = realpath(dir)
  local abs_root = realpath(root or dir)
  local base = vim.fn.fnamemodify(abs_dir, ":t")
  if not base:match("^build") then
    return vim.notify(string.format("[make_target] refuse to clean non-build dir: %s", abs_dir), vim.log.levels.ERROR)
  end
  if abs_dir:sub(1, #abs_root) ~= abs_root then
    return vim.notify(string.format("[make_target] refuse to clean outside project: %s", abs_dir), vim.log.levels.ERROR)
  end
  local answer = vim.fn.input(string.format("Clean (rm -rf) %s ? [y/N]: ", abs_dir))
  if answer ~= "y" and answer ~= "Y" then
    return
  end

  local ok_del = (vim.fn.delete(abs_dir, "rf") == 0)
  local ok_mk = (vim.fn.mkdir(abs_dir, "p") == 1 or vim.fn.isdirectory(abs_dir) == 1)
  if ok_del and ok_mk then
    vim.notify(string.format("[make_target] cleaned: %s", abs_dir))
  else
    vim.notify(string.format("[make_target] failed to clean: %s", abs_dir), vim.log.levels.ERROR)
  end
end

-- ===== target discovery =====
local function parse_make_targets(lines)
  local targets, seen = {}, {}
  for _, line in ipairs(lines or {}) do
    local name = line:match("^%s*([%w%._%+%-/]+)%s*:%s*[^=]")
    if name and not name:match("^%.[A-Z]") and not name:match("%%") and not seen[name] then
      seen[name] = true
      table.insert(targets, name)
    end
  end
  table.sort(targets)
  return targets
end

local function parse_cmake_help_targets(lines)
  local targets, seen = {}, {}
  for _, line in ipairs(lines or {}) do
    local name = line:match("^%s*%.%.%.%s*([%w%._%+%-%/]+)")
    if name and name ~= "" and not seen[name] then
      seen[name] = true
      table.insert(targets, name)
    end
  end
  table.sort(targets)
  return targets
end

local function list_cmake_targets(build_dir, cb)
  local cmd
  if cfg.run_in_docker then
    cmd = string.format(
      "docker exec -i -w %q %s cmake --build . --target help 2>/dev/null",
      container_path(build_dir),
      cfg.container_name
    )
  else
    cmd = "cmake --build . --target help 2>/dev/null"
  end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or not out or #out == 0 then
    return cb(nil, "cmake help failed")
  end
  cb(parse_cmake_help_targets(out))
end

local function list_make_targets(build_dir, cb)
  if not ensure_container() then
    return
  end
  local cmd
  if cfg.run_in_docker then
    cmd = string.format(
      "docker exec -i -w %q %s sh -lc %q",
      container_path(build_dir),
      cfg.container_name,
      "make -qpRr 2>/dev/null"
    )
  else
    cmd = "make -qpRr 2>/dev/null"
  end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return cb(nil, "make -qpRr failed")
  end
  cb(parse_make_targets(out))
end

local function list_ninja_targets(build_dir, cb)
  if not ensure_container() then
    return
  end
  local cmd
  if cfg.run_in_docker then
    cmd = string.format(
      "docker exec -i -w %q %s ninja -t targets all 2>/dev/null",
      container_path(build_dir),
      cfg.container_name
    )
  else
    cmd = "ninja -t targets all 2>/dev/null"
  end
  local out = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or not out or #out == 0 then
    return cb(nil, "ninja targets failed")
  end
  local targets, seen = {}, {}
  for _, line in ipairs(out) do
    local name = line:match("^([^:]+):")
    if name and not seen[name] then
      seen[name] = true
      table.insert(targets, name)
    end
  end
  table.sort(targets)
  cb(targets)
end

-- === Precheck: Docker up? else launch lazydocker (manual) ===
local function _docker_up()
  if vim.fn.executable("docker") == 0 then
    return false
  end
  local out = vim.fn.systemlist("docker info --format '{{.ServerVersion}}' 2>/dev/null")
  return (vim.v.shell_error == 0) and out and out[1] and out[1] ~= ""
end

local function _ensure_docker_or_launch_lazydocker()
  if not cfg.run_in_docker then
    return true
  end

  if _docker_up() then
    return true
  end

  if vim.fn.executable("lazydocker") == 1 then
    vim.notify(
      "[make_target] Docker not running，already opened lazydocker，please start lazydocker manually",
      vim.log.levels.WARN
    )
    open_terminal("lazydocker", vim.loop.cwd() or "~", {
      title = "lazydocker",
      provider = "toggleterm",
      float = { width = 0.98, height = 0.96, row = 0.02 },
    })
  else
    vim.notify(
      "[make_target] Docker not running，and not detect lazydocker.please install lazydocker（https://github.com/jesseduffield/lazydocker）",
      vim.log.levels.ERROR
    )
  end
  return false
end

-- ===== runners =====
local function run_make_target(build_dir, target)
  if not _ensure_docker_or_launch_lazydocker() then
    return
  end
  if not ensure_container() then
    return
  end
  local root = find_project_root(build_dir)
  touch_target(root, build_dir, target)
  local title = string.format("%s:%s", vim.fn.fnamemodify(build_dir, ":t"), target)
  local jobs = cfg.jobs or 8
  local shell_cmd = string.format("cd %q && make -j%d %s", container_path(build_dir), jobs, target)
  open_terminal(build_shell_cmd_inside(build_dir, shell_cmd), build_dir, {
    title = title,
    on_exit = function(code)
      if tonumber(code) == 0 then
        prompt_scp_after_build()
      end
    end,
  })
end

local function run_ninja_target(build_dir, target)
  if not _ensure_docker_or_launch_lazydocker() then
    return
  end
  if not ensure_container() then
    return
  end
  local root = find_project_root(build_dir)
  touch_target(root, build_dir, target)
  local title = string.format("%s:%s", vim.fn.fnamemodify(build_dir, ":t"), target)
  local jobs = cfg.jobs or 8
  local shell_cmd = string.format("cd %q && ninja -j%d %s", container_path(build_dir), jobs, target)
  open_terminal(build_shell_cmd_inside(build_dir, shell_cmd), build_dir, {
    title = title,
    on_exit = function(code)
      if tonumber(code) == 0 then
        prompt_scp_after_build()
      end
    end,
  })
end

-- ===== pickers =====
local function reorder_with_recent(list, recents)
  if not recents or #recents == 0 then
    return list
  end
  local set, out = {}, {}
  for _, v in ipairs(list) do
    set[v] = true
  end
  for _, r in ipairs(recents) do
    if set[r] then
      table.insert(out, r)
      set[r] = nil
    end
  end
  for _, v in ipairs(list) do
    if set[v] then
      table.insert(out, v)
    end
  end
  return out
end

local function pick_targets_and_run(build_dir)
  local has_make = Path:new(build_dir, "Makefile"):exists()
  local has_ninja = Path:new(build_dir, "build.ninja"):exists()
  local has_cache = Path:new(build_dir, "CMakeCache.txt"):exists()
  if not has_make and not has_ninja and not has_cache then
    vim.notify("[make_target] no Makefile/build.ninja/CMakeCache.txt in build dir, opening shell", vim.log.levels.INFO)
    return open_shell_in_build_dir(build_dir)
  end

  local root = find_project_root(build_dir)
  local container = cfg.container_name or "container"
  local dirbase = vim.fn.fnamemodify(build_dir, ":t")
  local prompt_base = string.format("%s · %s — pick target", container, dirbase)

  local function picker_from(list, runner, toolname)
    if not list or #list == 0 then
      vim.notify(string.format("[make_target] no targets parsed from %s; opening shell", toolname), vim.log.levels.WARN)
      return open_shell_in_build_dir(build_dir)
    end
    list = reorder_with_recent(list, recent_targets(root, build_dir))
    pickers
      .new({}, {
        prompt_title = prompt_base,
        finder = finders.new_table(list),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            local line = action_state.get_current_line()
            actions.close(prompt_bufnr)
            local target = (entry and entry[1]) or line
            if not target or target == "" then
              return
            end
            runner(build_dir, target)
          end)
          return true
        end,
      })
      :find()
  end

  if has_cache then
    return list_cmake_targets(build_dir, function(ts, _)
      if ts and #ts > 0 then
        picker_from(ts, has_ninja and run_ninja_target or run_make_target, "cmake")
      else
        if has_ninja then
          list_ninja_targets(build_dir, function(ts2, _)
            picker_from(ts2, run_ninja_target, "ninja")
          end)
        elseif has_make then
          list_make_targets(build_dir, function(ts2, _)
            picker_from(ts2, run_make_target, "make")
          end)
        else
          open_shell_in_build_dir(build_dir)
        end
      end
    end)
  end
  if has_make and has_ninja then
    local ans = vim.fn.input("Both Makefile and build.ninja found. Use [make|ninja] (default: make): ")
    if ans == "ninja" then
      list_ninja_targets(build_dir, function(ts, _)
        picker_from(ts, run_ninja_target, "ninja")
      end)
    else
      list_make_targets(build_dir, function(ts, _)
        picker_from(ts, run_make_target, "make")
      end)
    end
  elseif has_make then
    list_make_targets(build_dir, function(ts, _)
      picker_from(ts, run_make_target, "make")
    end)
  else
    list_ninja_targets(build_dir, function(ts, _)
      picker_from(ts, run_ninja_target, "ninja")
    end)
  end
end

-- ===== build dir picker =====
local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 1 then
    return true
  end
  local answer = vim.fn.input(string.format("Directory does not exist: %s. Create? [y/N]: ", dir))
  if answer == "y" or answer == "Y" then
    vim.fn.mkdir(dir, "p")
    return true
  end
  return false
end

local function pick_build_dir(start_dir)
  local root = find_project_root(start_dir)
  if not root then
    vim.notify("[make_target] project root not found", vim.log.levels.ERROR)
    return
  end

  -- Compose the candidates (LRU first, default 'build' if missing, then others), then dedupe
  local existing = find_build_dirs(root)
  local default_new = Path:new(root, "build").filename

  local items = {}
  for _, r in ipairs(recent_build_dirs(root)) do
    table.insert(items, r)
  end
  if vim.fn.isdirectory(default_new) == 0 then
    table.insert(items, default_new)
  end
  for _, x in ipairs(existing) do
    table.insert(items, x)
  end
  items = dedupe_keep_order(items)

  local legend = "[Enter] select | [C-t] terminal | [C-c] clean | [C-d] delete | [C-X] make clean | [C-h] help"

  pickers
    .new({}, {
      prompt_title = "Pick or create build dir (type new name and <CR>)",
      results_title = legend,
      finder = finders.new_table(items),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        local function current_choice()
          local entry = action_state.get_selected_entry()
          local line = action_state.get_current_line()
          local choice = (entry and entry[1]) or line
          local dir = choice
          if not Path:new(dir):is_absolute() then
            dir = Path:new(root, choice).filename
          end
          return dir
        end
        -- Enter → original flow: ensure dir, record, then pick targets
        actions.select_default:replace(function()
          local dir = current_choice()
          actions.close(prompt_bufnr)
          if ensure_dir(dir) then
            local rp = realpath(dir)
            M.state.last_build_dir_by_root[root] = rp
            touch_build_dir(root, rp)
            pick_targets_and_run(rp)
          end
        end)

        local function do_help()
          local lines = {
            "Build dir actions",
            "  Enter   : select/create and then pick targets",
            "  Ctrl-T  : open interactive terminal in this dir (docker)",
            "  Ctrl-C  : clean directory (rm -rf && mkdir -p)",
            "  Ctrl-D  : delete directory",
            "  Ctrl-X  : run 'make clean' if Makefile exists",
            "  Esc     : cancel",
          }
          vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Shortcuts" })
        end

        local function do_terminal()
          local dir = current_choice()
          actions.close(prompt_bufnr)
          open_shell_in_build_dir(dir)
        end
        local function do_clean()
          local dir = current_choice()
          actions.close(prompt_bufnr)
          clean_build_dir(dir, root)
        end

        local function do_delete_dir()
          local dir = current_choice()
          local base = vim.fn.fnamemodify(dir, ":t")
          if not base:match("^build") then
            return vim.notify("[make_target] refuse to delete non-build dir", vim.log.levels.ERROR)
          end
          local ans = vim.fn.input(string.format("Delete directory %s ? [y/N]: ", dir))
          if ans ~= "y" and ans ~= "Y" then
            return
          end
          actions.close(prompt_bufnr)
          if vim.fn.delete(dir, "rf") == 0 then
            vim.notify(string.format("[make_target] deleted: %s", dir))
          else
            vim.notify(string.format("[make_target] failed to delete: %s", dir), vim.log.levels.ERROR)
          end
        end

        local function do_make_clean()
          local dir = current_choice()
          actions.close(prompt_bufnr)
          if Path:new(dir, "Makefile"):exists() then
            local shell_cmd = string.format("cd %q && make clean", container_path(dir))
            local cmd = string.format(
              "docker exec -it -w %q %s %s -lc %q",
              container_path(dir),
              cfg.container_name,
              cfg.container_shell or "bash",
              shell_cmd
            )
            open_terminal(cmd, dir, { title = string.format("%s:make clean", vim.fn.fnamemodify(dir, ":t")) })
          else
            vim.notify("[make_target] Makefile not found in this dir", vim.log.levels.WARN)
          end
        end

        -- Keymaps (insert + normal)
        map("i", "<C-h>", do_help)
        map("n", "<C-h>", do_help)
        map("i", "<C-t>", do_terminal)
        map("n", "<C-t>", do_terminal)
        map("i", "<C-c>", do_clean)
        map("n", "<C-c>", do_clean)
        map("i", "<C-d>", do_delete_dir)
        map("n", "<C-d>", do_delete_dir)
        map("i", "<C-x>", do_make_clean)
        map("n", "<C-x>", do_make_clean)

        return true
      end,
    })
    :find()
end

-- ===== debug =====
local function get_last_build_dir_for_cwd()
  local start = vim.fn.expand("%:p:h")
  local root = find_project_root(start)
  if not root then
    return nil, "project root not found"
  end
  local dir = M.state.last_build_dir_by_root[root]
  if dir and dir ~= "" then
    return dir
  end
  local recents = recent_build_dirs(root)
  if recents and recents[1] then
    return recents[1]
  end
  return nil, "no last build dir; run :CMakePickBuild first"
end

function M.probe_targets()
  local dir, err = get_last_build_dir_for_cwd()
  if not dir then
    return vim.notify("[make_target] " .. err, vim.log.levels.ERROR)
  end
  if not ensure_container() then
    return
  end
  local wd = container_path(dir)
  local script = table.concat({
    "set -e",
    "echo '=== pwd ==='; pwd",
    "echo '=== cmake --build . --target help | head ==='; cmake --build . --target help 2>/dev/null | sed -n '1,120p' || true",
    "echo '=== make -qpRr | head ==='; make -qpRr 2>/dev/null | sed -n '1,120p' || true",
    "echo '=== done; interactive shell ==='",
    "exec " .. (cfg.container_shell or "bash"),
  }, " && ")
  local cmd =
    string.format("docker exec -it -w %q %s %s -lc %q", wd, cfg.container_name, cfg.container_shell or "bash", script)
  open_terminal(cmd, dir, { title = default_title() })
end
-- ===== public =====
function M.pick_build()
  local start = vim.fn.expand("%:p:h")
  pick_build_dir(start)
end

function M.pick_target_in_last_build()
  local start = vim.fn.expand("%:p:h")
  local root = find_project_root(start)
  if not root then
    return vim.notify("[make_target] project root not found", vim.log.levels.ERROR)
  end
  local dir = M.state.last_build_dir_by_root[root]
  if not dir then
    local rec = recent_build_dirs(root)
    if rec and rec[1] then
      dir = rec[1]
      M.state.last_build_dir_by_root[root] = dir
    end
  end
  if not dir then
    return pick_build_dir(start)
  end
  pick_targets_and_run(dir)
end

function M.configure_here()
  local start = vim.fn.expand("%:p:h")
  local root = find_project_root(start)
  if not root then
    return vim.notify("[make_target] project root not found", vim.log.levels.ERROR)
  end
  local dir = M.state.last_build_dir_by_root[root]
  if not dir then
    local rec = recent_build_dirs(root)
    if rec and rec[1] then
      dir = rec[1]
      M.state.last_build_dir_by_root[root] = dir
    end
  end
  if not dir then
    return pick_build_dir(start)
  end
  open_shell_in_build_dir(dir)
end

function M.print_root()
  local start = vim.fn.expand("%:p:h")
  local root = find_project_root(start)
  print(root or "(none)")
end

M.setup = function(opts)
  cfg = vim.tbl_deep_extend("force", {
    container_name = "source_gfx",
    run_in_docker = true,
    container_shell = "bash",
    host_to_container_path = nil,
    search_depth = 2,
    search_nested = false,
    jobs = 16,
    terminal = {
      provider = "toggleterm",
      float = { width = 0.5, height = 0.5, row = 0.1 },
      title = nil, -- default: "in_docker_"..container_name:gsub('_','')
    },
    root_strategy = "outermost_git",
    history = { keep_builds = 3, keep_targets = 3, persist = true },
    scp = { enable = true, default_ip = nil, user = "rickliu", remote_dir = "/tmp" },
  }, opts or {})

  vim.api.nvim_create_user_command("CMakePickBuild", function()
    M.pick_build()
  end, {})

  vim.api.nvim_create_user_command("CMakePickTarget", function()
    M.pick_target_in_last_build()
  end, {})

  vim.api.nvim_create_user_command("CMakeConfigure", function()
    M.configure_here()
  end, {})

  vim.api.nvim_create_user_command("CMakePrintRoot", function()
    M.print_root()
  end, {})

  vim.api.nvim_create_user_command("CMakeProbeTargets", function()
    M.probe_targets()
  end, {})

  vim.api.nvim_create_user_command("MakeTargetScp", function()
    require("make_target.scp").pick()
  end, {})

  vim.api.nvim_create_user_command("MakeTargetLazyDocker", function()
    local ok, mt = pcall(require, "make_target")
    if ok and type(mt.lazydocker_quick) == "function" then
      mt.lazydocker_quick()
    else
      if vim.fn.executable("lazydocker") == 1 then
        vim.cmd("tabnew | term lazydocker")
      else
        vim.notify("[make_target] not detect lazydocker; install firstly", vim.log.levels.ERROR)
      end
    end
  end, {})
end

function M.lazydocker_quick()
  if vim.fn.executable("lazydocker") == 0 then
    return vim.notify("[make_target] not dectect lazydocker；please intstall firstly", vim.log.levels.ERROR)
  end

  open_terminal("lazydocker", vim.loop.cwd() or "~", {
    title = "lazydocker",
    provider = (cfg.terminal and cfg.terminal.provider) or "toggleterm", -- 也可改 "native"
  })

  vim.defer_fn(function()
    if vim.fn.executable("docker") == 1 then
      local out = vim.fn.systemlist("docker info --format '{{.ServerVersion}}' 2>/dev/null")
      local ok = (vim.v.shell_error == 0) and out and out[1] and out[1] ~= ""
      if not ok then
        vim.notify("[make_target] remain：Docker seem not running（No block lazydocker）", vim.log.levels.WARN)
      end
    end
  end, 300)
end

return M
