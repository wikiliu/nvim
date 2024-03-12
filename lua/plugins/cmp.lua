return {
  {
    "hrsh7th/nvim-cmp",
    opts = function(_,opts)
      local cmp = require "cmp"
        opts.window = {
          completion = cmp.config.window.bordered({
	border = "rounded",
	winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None"
	}),
	documentation = {
	border = "rounded",
	winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None"
        }
        }
    end,
  },
}
