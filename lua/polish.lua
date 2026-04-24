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
    if args.match == "fountain" then
      vim.opt_local.textwidth = 80
    end
  end,
})
