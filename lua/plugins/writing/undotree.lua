return {
  "mbbill/undotree",
  cmd = "UndotreeToggle",
  keys = {
    { "<Leader>Wu", "<cmd>UndotreeToggle<cr>", desc = "Toggle undotree" },
  },
  config = function()
    vim.g.undotree_WindowLayout = 2
    vim.g.undotree_SetFocusWhenToggle = 1
  end,
}
