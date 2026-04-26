return {
  "epwalsh/pomo.nvim",
  version = "*",
  cmd = { "TimerStart", "TimerRepeat", "TimerSession" },
  keys = {
    { "<Leader>WP", "<cmd>TimerStart 25m write<cr>", desc = "Pomodoro start (25m)" },
    { "<Leader>WT", "<cmd>TimerStop<cr>",            desc = "Pomodoro stop" },
  },
  dependencies = { "rcarriga/nvim-notify" },
  opts = {},
}
