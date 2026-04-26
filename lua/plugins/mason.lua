---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "ltex-ls",
        "vale-ls",
        "vale",
        "marksman",
        "stylua",
        "selene",
        "yq",
        "yaml-language-server",
      })
      return opts
    end,
  },
}
