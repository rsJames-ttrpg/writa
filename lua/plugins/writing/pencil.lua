return {
  "preservim/vim-pencil",
  ft = { "markdown", "text", "tex", "fountain" },
  init = function()
    vim.g["pencil#wrapModeDefault"] = "soft"
    vim.g["pencil#textwidth"] = 80
    vim.g["pencil#conceallevel"] = 2
  end,
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("writa_pencil", { clear = true }),
      pattern = { "markdown", "text", "tex", "fountain" },
      callback = function() vim.fn["pencil#init"]() end,
    })
  end,
}
