return {
  "folke/zen-mode.nvim",
  cmd = "ZenMode",
  keys = {
    { "<Leader>Wz", "<cmd>ZenMode<cr>", desc = "Toggle Zen mode" },
  },
  opts = {
    window = {
      width = 90,
      options = {
        number = false,
        relativenumber = false,
        signcolumn = "no",
      },
    },
    plugins = {
      options = { enabled = true, ruler = false, showcmd = false },
      gitsigns = { enabled = true },
      tmux = { enabled = false },
    },
  },
}
