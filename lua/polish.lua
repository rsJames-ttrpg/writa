-- Silence AstroLSP's hover/signature deprecation warnings on LSP attach.
-- These are upstream compat-shim noise; remove this block once AstroLSP
-- stops calling the pre-Nvim-0.11 signatures.
local _deprecate = vim.deprecate
vim.deprecate = function(name, ...)
  if name == "vim.lsp.buf.hover" or name == "vim.lsp.buf.signature_help" then return end
  return _deprecate(name, ...)
end

local group = vim.api.nvim_create_augroup("writa_writing_mode", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "tex", "plaintex", "fountain", "text" },
  callback = function(args)
    vim.opt_local.spell = true
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = ""
    if args.match == "fountain" then vim.opt_local.textwidth = 80 end
  end,
})
