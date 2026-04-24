---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    opts.ensure_installed = opts.ensure_installed or {}
    vim.list_extend(opts.ensure_installed, {
      "markdown",
      "markdown_inline",
      "latex",
      "bibtex",
      "yaml",
      "toml",
    })
    return opts
  end,
}
