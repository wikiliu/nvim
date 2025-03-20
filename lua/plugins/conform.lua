return {
    "stevearc/conform.nvim",
    opts = function(_, opts)
        opts.formatters_by_ft.c = { "clang-format" }
        opts.formatters_by_ft.cpp = { "clang-format" }
    end,
}
