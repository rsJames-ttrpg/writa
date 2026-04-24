return {
  "David-Kunz/gen.nvim",
  cmd = "Gen",
  keys = {
    { "<Leader>Wg", ":Gen<cr>", mode = { "n", "v" }, desc = "Gen (LLM) menu" },
  },
  opts = {
    model = "gemma4:26b",
    host = "localhost",
    port = "11434",
    display_mode = "float",
    show_prompt = false,
    show_model = true,
    no_auto_close = false,
  },
}
