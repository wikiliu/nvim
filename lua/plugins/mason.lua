-- add any tools you want to have installed below
return {
    "williamboman/mason.nvim",
    opts = {
        ensure_installed = {
            "stylua",
            "shellcheck",
            "shfmt",
            "flake8",
        },
    }
}
