return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = function(_, opts)
    -- 支持中英文的星期对应 emoji
    local emojis = {
      ["Monday"] = "😪",
      ["星期一"] = "😪",
      ["Tuesday"] = "😐",
      ["星期二"] = "😐",
      ["Wednesday"] = "🤔",
      ["星期三"] = "🤔",
      ["Thursday"] = "😊",
      ["星期四"] = "😊",
      ["Friday"] = "🥳",
      ["星期五"] = "🥳",
      ["Saturday"] = "🎉",
      ["星期六"] = "🎉",
      ["Sunday"] = "😌",
      ["星期日"] = "😌",
    }
    local status = require("nvim-spotify").status
    status:start()
    table.insert(opts.sections.lualine_x, status.listen)

    local function get_weekday_emoji()
      local weekday = os.date("%A") -- 获取当前星期
      return emojis[weekday] or "😄" -- 兜底默认表情
    end

    table.insert(opts.sections.lualine_x, {
      function()
        return get_weekday_emoji()
      end,
    })
  end,
  -- "nvim-lualine/lualine.nvim",
  -- optional = true,
  -- opts = function(_, opts)
  -- local overseer = require("overseer")
  -- opts.sections = {
  --   lualine_x = {
  --     {
  --       label = "", -- Prefix for task counts
  --       colored = true, -- Color the task icons and counts
  --       symbols = {
  --         [overseer.STATUS.FAILURE] = "F:",
  --         [overseer.STATUS.CANCELED] = "C:",
  --         [overseer.STATUS.SUCCESS] = "S:",
  --         [overseer.STATUS.RUNNING] = "R:",
  --       },
  --       unique = false, -- Unique-ify non-running task count by name
  --       name = nil, -- List of task names to search for
  --       name_not = false, -- When true, invert the name search
  --       status = nil, -- List of task statuses to display
  --       status_not = false, -- When true, invert the status search
  --     },
  --   },
  -- }
  -- end,
}
