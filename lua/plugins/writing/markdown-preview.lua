return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
  build = "cd app && yarn install",
  ft = "markdown",
  keys = {
    { "<Leader>Wm", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview toggle" },
  },
  init = function()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 1
    vim.g.mkdp_theme = "dark"
  end,
}
