local M = {}

local Path = require("plenary.path")
local scan = require("plenary.scandir")

local cfg = {
  enable = true,
  user = "rickliu",
  ip = "127.0.0.1",
  remote_dir = "/tmp",
  password = nil, -- if nil/empty => use SSH key
  prefer = "auto", -- 'fzf' | 'telescope' | 'auto'
  depth_files = 6, -- recursive depth inside each build dir
  keep_artifacts = 5, -- LRU length per project
  lemonade = true, -- try 'lemonade copy <basename>'
}

local function realpath(p)
  local rp = vim.loop.fs_realpath(p)
  if rp and rp ~= "" then
    return rp
  end
  return Path:new(p):absolute()
end

-- ----- find project root (outermost .git) -----
local function has_git(dir)
  return Path:new(dir, ".git"):exists()
end
local function parent(dir)
  return Path:new(dir):parent().filename
end
local function find_project_root(start)
  local dir = Path:new(start or vim.fn.expand("%:p:h")):absolute()
  local last_git = nil
  while dir and dir ~= "" do
    if has_git(dir) then
      last_git = dir
    end
    local p = parent(dir)
    if p == dir then
      break
    end
    dir = p
  end
  if last_git then
    return last_git
  end
  local top = vim.fn.systemlist("git -C " .. vim.fn.fnameescape(start or ".") .. " rev-parse --show-toplevel")[1]
  if top and top ~= "" and vim.v.shell_error == 0 then
    return top
  end
  return nil
end

-- ----- load/save history in <root>/.vscode/make_target_history.json -----
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
  local p = hist_path(root)
  local f = io.open(p, "r")
  if not f then
    return { artifacts = {} }
  end
  local s = f:read("*a")
  f:close()
  local ok, obj = pcall(vim.json.decode, s)
  if ok and type(obj) == "table" then
    obj.artifacts = obj.artifacts or {}
    return obj
  end
  return { artifacts = {} }
end

local function save_history(root, H)
  local p = hist_path(root)
  local ok, s = pcall(vim.json.encode, H)
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
local function touch_artifact(root, relfile)
  local H = load_history(root)
  H.artifacts = H.artifacts or {}
  local arr, now = {}, os.time()
  table.insert(arr, { path = relfile, ts = now })
  for _, it in ipairs(H.artifacts) do
    if it.path ~= relfile then
      table.insert(arr, it)
    end
  end
  while #arr > (cfg.keep_artifacts or 5) do
    table.remove(arr)
  end
  H.artifacts = arr
  save_history(root, H)
end

local function recent_artifacts(root)
  local H = load_history(root)
  local arr = H.artifacts or {}
  table.sort(arr, function(a, b)
    return (a.ts or 0) > (b.ts or 0)
  end)
  local out = {}
  for i, it in ipairs(arr) do
    if i > (cfg.keep_artifacts or 5) then
      break
    end
    table.insert(out, it.path)
  end
  return out
end

-- ----- build dirs under root (root-only) -----
local function find_build_dirs(root)
  local entries = scan.scan_dir(root, { hidden = false, add_dirs = true, only_dirs = true, depth = 1, silent = true })
    or {}
  local res, seen = {}, {}
  for _, d in ipairs(entries) do
    local name = vim.fn.fnamemodify(d, ":t")
    if name:match("^build") then
      local rp = realpath(d)
      if not seen[rp] then
        seen[rp] = true
        table.insert(res, rp)
      end
    end
  end
  table.sort(res)
  return res
end

-- ----- artifact list inside build dirs -----
local function list_artifacts(root)
  local files, seen = {}, {}
  for _, bdir in ipairs(find_build_dirs(root)) do
    scan.scan_dir(bdir, {
      hidden = false,
      add_dirs = false,
      depth = cfg.depth_files or 6,
      silent = true,
      on_insert = function(f)
        if f:match("%.deb$") or f:match("%.so$") then
          local rp = realpath(f)
          if not seen[rp] then
            seen[rp] = true
            table.insert(files, rp)
          end
        end
      end,
    })
  end
  table.sort(files)
  -- Convert to relative to root
  local rel = {}
  for _, p in ipairs(files) do
    local r = p:sub(#root + 2)
    table.insert(rel, r)
  end
  -- Put recents to top
  local rec = recent_artifacts(root)
  if #rec > 0 then
    local set = {}
    for _, r in ipairs(rec) do
      set[r] = true
    end
    local out = {}
    for _, r in ipairs(rec) do
      table.insert(out, r)
    end
    for _, r in ipairs(rel) do
      if not set[r] then
        table.insert(out, r)
      end
    end
    rel = out
  end
  return rel
end

-- ----- remote commands -----
local function ssh_cmd(cmd)
  if cfg.password and cfg.password ~= "" then
    return string.format("sshpass -p %q ssh -o StrictHostKeyChecking=no %s@%s %q", cfg.password, cfg.user, cfg.ip, cmd)
  else
    return string.format("ssh -o BatchMode=yes -o StrictHostKeyChecking=no %s@%s %q", cfg.user, cfg.ip, cmd)
  end
end
local function scp_cmd(local_file)
  if cfg.password and cfg.password ~= "" then
    return string.format(
      "sshpass -p %q scp -o StrictHostKeyChecking=no %q %s@%s:%q",
      cfg.password,
      local_file,
      cfg.user,
      cfg.ip,
      cfg.remote_dir
    )
  else
    return string.format(
      "scp -o BatchMode=yes -o StrictHostKeyChecking=no %q %s@%s:%q",
      local_file,
      cfg.user,
      cfg.ip,
      cfg.remote_dir
    )
  end
end
local function ensure_remote_dir()
  local cmd = ssh_cmd(string.format("mkdir -p %q", cfg.remote_dir))
  vim.fn.system(cmd)
end

local function lemonade_copy(name)
  if not cfg.lemonade then
    return
  end
  if vim.fn.executable("lemonade") == 1 then
    os.execute("lemonade copy " .. name)
  end
end

-- ----- UI -----
local function pick_telescope(root, items, on_select)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  pickers
    .new({}, {
      prompt_title = string.format("SCP %s@%s:%s — pick file", cfg.user, cfg.ip, cfg.remote_dir),
      finder = finders.new_table(items),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          local line = action_state.get_current_line()
          actions.close(prompt_bufnr)
          local rel = (entry and entry[1]) or line
          if rel and rel ~= "" then
            on_select(rel)
          end
        end)
        return true
      end,
    })
    :find()
end

local function pick_fzf(items, on_select)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return false
  end
  fzf.fzf_exec(items, {
    prompt = "Select File to SCP > ",
    actions = {
      ["default"] = function(selected)
        if selected and #selected > 0 then
          on_select(selected[1])
        end
      end,
    },
  })
  return true
end
local function perform_scp(root, rel)
  ensure_remote_dir()
  local full = Path:new(root, rel).filename
  local cmd = scp_cmd(full)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify(string.format("[make_target][scp] failed: %s\n%s", rel, out), vim.log.levels.ERROR)
    return
  end
  lemonade_copy(vim.fn.fnamemodify(full, ":t"))
  touch_artifact(root, rel)
  vim.notify(string.format("[make_target][scp] transferred: %s -> %s@%s:%s", rel, cfg.user, cfg.ip, cfg.remote_dir))
end
-- ----- Public API -----
function M.pick()
  if not cfg.enable then
    return vim.notify("[make_target][scp] disabled in config", vim.log.levels.WARN)
  end
  local root = find_project_root(vim.fn.expand("%:p:h"))
  if not root then
    return vim.notify("[make_target][scp] project root not found", vim.log.levels.ERROR)
  end
  local items = list_artifacts(root)
  if #items == 0 then
    return vim.notify("[make_target][scp] no .deb or .so found under build* dirs", vim.log.levels.WARN)
  end
  local function on_select(rel)
    perform_scp(root, rel)
  end
  if cfg.prefer == "fzf" or (cfg.prefer == "auto" and pcall(require, "fzf-lua")) then
    if pick_fzf(items, on_select) then
      return
    end
  end
  pick_telescope(root, items, on_select)
end
function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  vim.api.nvim_create_user_command("MakeTargetScp", function()
    M.pick()
  end, {})
end
return M
