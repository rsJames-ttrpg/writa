return {
  "epwalsh/pomo.nvim",
  version = "*",
  cmd = { "TimerStart", "TimerRepeat", "TimerSession" },
  keys = {
    { "<Leader>Wp", "<cmd>TimerStart 25m write<cr>", desc = "Pomodoro 25m" },
    { "<Leader>WP", "<cmd>TimerStop<cr>", desc = "Pomodoro stop" },
  },
  dependencies = { "rcarriga/nvim-notify" },
  opts = {},
}
