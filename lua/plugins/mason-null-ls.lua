---@type LazySpec
return {
  "jay-babu/mason-null-ls.nvim",
  opts = function(_, opts)
    opts.handlers = opts.handlers or {}
    opts.handlers.vale = function() end
  end,
}
