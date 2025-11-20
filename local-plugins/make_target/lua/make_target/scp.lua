local M = {}

local Path = require("plenary.path")
local scan = require("plenary.scandir")
local ui_select_sync

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

    local valid_artifacts = {}
    for _, item in ipairs(obj.artifacts) do
      if item.path and (vim.loop.fs_stat(item.path) or vim.loop.fs_stat(root .. "/" .. item.path)) then
        table.insert(valid_artifacts, item)
      end
    end

    if #valid_artifacts ~= #obj.artifacts then
      obj.artifacts = valid_artifacts

      local wf = io.open(p, "w")
      if wf then
        wf:write(vim.json.encode(obj))
        wf:close()
      end
    else
      obj.artifacts = valid_artifacts
    end

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
        if f:match("%.deb$") or f:match("%.so") then
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

local function ssh_root_cmd(cmd)
  if cfg.password and cfg.password ~= "" then
    return string.format("sshpass -p %q ssh -o StrictHostKeyChecking=no %s@%s %q", cfg.password, "root", cfg.ip, cmd)
  else
    return string.format("ssh -o BatchMode=yes -o StrictHostKeyChecking=no %s@%s %q", "root", cfg.ip, cmd)
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
      prompt_title = string.format("SCP %s@%s:%s — pick file (<C-t> for actions)", cfg.user, cfg.ip, cfg.remote_dir),
      finder = finders.new_table(items),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          local line = action_state.get_current_line()
          actions.close(prompt_bufnr)
          local rel = (entry and entry[1]) or line
          if rel and rel ~= "" then
            on_select(rel)
          end
        end)

        -- 添加到 telescope actions 菜单
        local edit_ssh = function()
          actions.close(prompt_bufnr)
          vim.schedule(function()
            M.edit_project_scp()
            pick_telescope(root, items, on_select)
          end)
        end

        local edit_cfg = function()
          actions.close(prompt_bufnr)
          vim.schedule(function()
            if M.edit_project_cfg then
              M.edit_project_cfg()
            else
              M.edit_project_scp()
            end
            pick_telescope(root, items, on_select)
          end)
        end

        -- 在 picker 内用 <C-t> 弹出一个输入框让用户输入数字或 q 取消（更直观，不会把按键当成 prompt 的输入）
        local function choose_action()
          local prompt = "Action: [1] Edit SSH  [2] Edit Config  [q] Cancel > "
          -- Use command-line input (vim.fn.input) here because floating ui input
          -- can be unfriendly inside Telescope in some terminals. vim.fn.input
          -- always reads from the command-line and is reliable.
          local ans = vim.fn.input(prompt) or ""
          ans = tostring(ans):gsub("^%s+", ""):gsub("%s+$", "")
          if ans == "" then
            return
          end
          local c = ans:sub(1, 1):lower()
          if c == "q" then
            return
          end
          if c == "1" or c == "e" then
            edit_ssh()
            return
          end
          if c == "2" or c == "c" then
            edit_cfg()
            return
          end
          -- fallback: if user typed the word
          if ans:match("edit%s*ssh") then
            edit_ssh()
          elseif ans:match("edit%s*config") or ans:match("edit%s*cfg") then
            edit_cfg()
          end
        end

        -- use the provided `map` helper (like in pick_build_dir) so mappings work inside Telescope
        map("i", "<C-t>", function()
          choose_action()
        end)
        map("n", "<C-t>", function()
          choose_action()
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

local function perform_scp_async(root, rel)
  ensure_remote_dir()
  local full = Path:new(root, rel).filename
  local cmd = scp_cmd(full)

  -- 1️⃣ 计算浮窗文本与位置（右上角）
  local text = "[make_target][scp] transferring: " .. rel .. " ..."
  local width = math.min(80, #text) -- 浮窗宽度（你可以调大一点）
  local height = 1

  local screen_width = vim.o.columns

  local col = screen_width - width - 2 -- 🟢 放在右上角
  local row = 1 -- 上边缘

  -- 2️⃣ 创建浮窗
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
  })

  -- 3️⃣ 异步执行 SCP
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        -- 关闭浮窗
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end

        -- SCP 失败
        if exit_code ~= 0 then
          vim.notify(string.format("[make_target][scp] failed: %s", rel), vim.log.levels.ERROR)
          return
        end

        -- 部署动作
        local function finish_deploy()
          lemonade_copy(vim.fn.fnamemodify(full, ":t"))
          touch_artifact(root, rel)
          vim.notify(
            string.format("[make_target][scp] transferred: %s -> %s@%s:%s", rel, cfg.user, cfg.ip, cfg.remote_dir)
          )
        end

        if vim.g.deploy == true then
          local filename = full:match("([^/]+)$")
          local root_cmd

          if filename:find("dri") then
            root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/x86_64-linux-gnu/dri/", cfg.remote_dir, filename))
          elseif filename:find("drm") then
            root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/x86_64-linux-gnu/", cfg.remote_dir, filename))
          elseif filename:find("drv") then
            root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/xorg/modules/drivers/", cfg.remote_dir, filename))
          end

          if root_cmd then
            vim.fn.jobstart(root_cmd, {
              on_exit = function(_, root_exit, _)
                vim.schedule(function()
                  if root_exit ~= 0 then
                    vim.notify(string.format("[make_target][scp] deploy failed: %s", rel), vim.log.levels.ERROR)
                    return
                  end
                  vim.g.deploy = false
                  finish_deploy()
                end)
              end,
            })
          end
        else
          finish_deploy()
        end
      end)
    end,
  })
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
  local deploy = ""
  if vim.g.deploy and vim.g.deploy == true then
    local filename = full:match("([^/]+)$")
    if filename:find("dri") then
      local root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/x86_64-linux-gnu/dri/", cfg.remote_dir, filename))
      out = vim.fn.system(root_cmd)
    elseif filename:find("drm") then
      local root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/x86_64-linux-gnu/", cfg.remote_dir, filename))
      out = vim.fn.system(root_cmd)
    elseif filename:find("drv") then
      local root_cmd = ssh_root_cmd(string.format("mv %s/%s /usr/lib/xorg/modules/drivers/", cfg.remote_dir, filename))
      out = vim.fn.system(root_cmd)
    end
    vim.g.deploy = false
    if vim.v.shell_error ~= 0 then
      vim.notify(string.format("[make_target][scp] failed: %s\n%s", rel, out), vim.log.levels.ERROR)
      return
    end
    deploy = "deploy"
  end
  lemonade_copy(vim.fn.fnamemodify(full, ":t"))
  touch_artifact(root, rel)
  vim.notify(
    string.format("[make_target][scp] transferred %s: %s -> %s@%s:%s", deploy, rel, cfg.user, cfg.ip, cfg.remote_dir)
  )
end

-- ----- Public API -----
local function prompt_scp_input(default)
  default = default or {}
  local config = {}

  -- 必填项
  config.user = vim.fn.input("SCP user: ", default.user or cfg.user or "")
  config.ip = vim.fn.input("SCP ip: ", default.ip or cfg.ip or "")
  config.remote_dir = vim.fn.input("remote_dir: ", default.remote_dir or cfg.remote_dir or "")

  -- 可选项，空密码表示使用SSH密钥
  local pwd = vim.fn.input("password (empty=SSH key): ", default.password or "")
  config.password = pwd ~= "" and pwd or nil

  local en = vim.fn.input("use lemonade (y/n): ", (cfg.enable and "y") or "y") or "y"
  config.lemonade = en:lower():sub(1, 1) == "y"

  -- 保持其他配置项不变
  config.prefer = default.prefer or cfg.prefer or "auto"
  config.depth_files = default.depth_files or cfg.depth_files or 6
  config.keep_artifacts = default.keep_artifacts or cfg.keep_artifacts or 5

  return config
end

-- global sync wrapper for vim.ui.input
function ui_input_sync(prompt, def)
  if vim.ui and vim.ui.input then
    local co = coroutine.running()
    if not co then
      return vim.fn.input(prompt, def or "")
    end
    local res
    vim.ui.input({ prompt = prompt, default = def or "" }, function(input)
      res = input
      if co then
        coroutine.resume(co)
      end
    end)
    coroutine.yield()
    return res
  else
    return vim.fn.input(prompt, def or "")
  end
end

-- sync wrapper for vim.ui.select (fallback to inputlist)
ui_select_sync = function(items, opts)
  opts = opts or {}
  if vim.ui and vim.ui.select then
    local co = coroutine.running()
    if not co then
      -- fall back to numbered inputlist when not running inside a coroutine
      local arr = { opts.prompt or "Select:" }
      for _, v in ipairs(items) do
        table.insert(arr, v)
      end
      local sel = vim.fn.inputlist(arr)
      if sel <= 0 then
        return nil
      end
      return items[sel - 1]
    end
    local res
    vim.ui.select(items, { prompt = opts.prompt or "Select:" }, function(choice)
      res = choice
      if co then
        coroutine.resume(co)
      end
    end)
    coroutine.yield()
    return res
  else
    -- fall back to numbered inputlist
    local arr = { opts.prompt or "Select:" }
    for _, v in ipairs(items) do
      table.insert(arr, v)
    end
    local sel = vim.fn.inputlist(arr)
    if sel <= 0 then
      return nil
    end
    return items[sel - 1]
  end
end

function M.edit_project_scp()
  local root = find_project_root(vim.fn.expand("%:p:h"))
  if not root then
    return vim.notify("[make_target][scp] project root not found", vim.log.levels.ERROR)
  end
  local H = load_history(root)
  H.scp = H.scp or {}

  local current = H.scp[1] or {}
  local edited = prompt_scp_input(current)
  if not edited.user or edited.user == "" or not edited.ip or edited.ip == "" then
    return vim.notify("[make_target][scp] User and IP are required", vim.log.levels.WARN)
  end

  H.scp = { vim.tbl_extend("force", { ts = os.time() }, edited) }
  cfg = vim.tbl_deep_extend("force", cfg, edited)
  save_history(root, H)
  vim.notify(
    string.format("[make_target][scp] Updated: %s@%s:%s", edited.user, edited.ip, edited.remote_dir),
    vim.log.levels.INFO
  )
end

function M.edit_project_cfg()
  local root = find_project_root(vim.fn.expand("%:p:h"))
  if not root then
    return vim.notify("[make_target][scp] project root not found", vim.log.levels.ERROR)
  end
  local H = load_history(root)
  H.scp = H.scp or {}
  local current = H.scp[1] or {}
  local edited = prompt_scp_input(current)
  if not edited.user or edited.user == "" or not edited.ip or edited.ip == "" then
    return vim.notify("[make_target][scp] User and IP are required", vim.log.levels.WARN)
  end

  local en = vim.fn.input("enable (y/n): ", (cfg.enable and "y") or "y") or "y"
  edited.enable = en:lower():sub(1, 1) == "y"
  H.scp = { vim.tbl_extend("force", { ts = os.time() }, edited) }
  save_history(root, H)
  cfg = vim.tbl_deep_extend("force", cfg, edited)
  vim.notify(
    string.format(
      "[make_target][scp] Updated cfg: %s@%s:%s (enable=%s)",
      edited.user,
      edited.ip,
      edited.remote_dir,
      edited.enable and "yes" or "no"
    ),
    vim.log.levels.INFO
  )
end

function M.pick()
  if not cfg.enable then
    return vim.notify("[make_target][scp] disabled in config", vim.log.levels.WARN)
  end
  local root = find_project_root(vim.fn.expand("%:p:h"))
  if not root then
    return vim.notify("[make_target][scp] project root not found", vim.log.levels.ERROR)
  end
  -- project-first: prefer last saved scp entry in project history
  -- Behavior changed per user request:
  -- * If the history file does NOT exist -> prompt to create one (same as before).
  -- * If the history file exists but does NOT contain `scp` field -> do NOT override `cfg` (keep opts defaults).
  -- * If the history file contains an `scp` array:
  --     - if empty array -> prompt to create one
  --     - if non-empty -> use last entry to override cfg
  local histfile = hist_path(root)
  local file_exists = vim.loop.fs_stat(histfile) ~= nil
  local H = load_history(root)
  if not file_exists then
    -- history file missing: prompt to create one (keep previous behavior)
    vim.notify("[make_target][scp] no ssh information found for this project; please create one", vim.log.levels.INFO)
    local new = prompt_scp_input()
    H.scp = { vim.tbl_extend("force", { ts = os.time() }, new) }
    save_history(root, H)
    cfg = vim.tbl_deep_extend("force", cfg, new)
  else
    -- history file exists
    if H.scp == nil then
      -- file exists but contains no `scp` entry: keep cfg from opts and do not prompt
      H.scp = H.scp or {}
    elseif #H.scp == 0 then
      -- scp present but empty array: prompt to create one
      vim.notify("[make_target][scp] no ssh information found; please create one", vim.log.levels.INFO)
      local new = prompt_scp_input()
      H.scp = { vim.tbl_extend("force", { ts = os.time() }, new) }
      save_history(root, H)
      cfg = vim.tbl_deep_extend("force", cfg, new)
    else
      -- scp present and non-empty: use the last saved entry
      local last = H.scp[#H.scp]
      if last then
        cfg = vim.tbl_deep_extend("force", cfg, last)
      end
    end
  end

  -- temporary buffer-local Alt-r to edit project SCP quickly
  pcall(function()
    vim.keymap.set("n", "<C-t>", function()
      M.edit_project_scp()
    end, { buffer = 0, noremap = true, silent = true })
  end)

  local items = list_artifacts(root)
  if #items == 0 then
    return vim.notify("[make_target][scp] no .deb or .so found under build* dirs", vim.log.levels.WARN)
  end
  local function on_select(rel)
    perform_scp_async(root, rel)
    -- cleanup mapping if present
    pcall(function()
      vim.keymap.del("n", "<C-t>", { buffer = 0 })
    end)
  end
  if cfg.prefer == "fzf" or (cfg.prefer == "auto" and pcall(require, "fzf-lua")) then
    if pick_fzf(items, on_select) then
      return
    end
  end
  pick_telescope(root, items, on_select)
end
function M.setup(opts)
  -- ignore scp fields coming from nvim config; prefer project-local history
  local filtered = vim.tbl_deep_extend("force", {}, opts or {})
  filtered.user = nil
  filtered.ip = nil
  filtered.remote_dir = nil
  filtered.password = nil
  filtered.prefer = nil
  filtered.depth_files = nil
  filtered.keep_artifacts = nil
  filtered.lemonade = nil
  cfg = vim.tbl_deep_extend("force", cfg, filtered)
  vim.api.nvim_create_user_command("MakeTargetScp", function()
    M.pick()
  end, {})

  vim.api.nvim_create_user_command("MakeTargetEditScp", function()
    M.edit_project_scp()
  end, {})

  vim.api.nvim_create_user_command("MakeTargetEditCfg", function()
    M.edit_project_cfg()
  end, {})
end
return M
