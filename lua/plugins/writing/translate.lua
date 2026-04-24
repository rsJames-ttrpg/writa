return {
  "uga-rosa/translate.nvim",
  cmd = "Translate",
  keys = {
    { "<Leader>Wtf", "<cmd>Translate FR<cr>", mode = { "n", "v" }, desc = "Translate -> French" },
    { "<Leader>Wte", "<cmd>Translate EN<cr>", mode = { "n", "v" }, desc = "Translate -> English" },
  },
  opts = {
    default = { command = "google" },
  },
}
