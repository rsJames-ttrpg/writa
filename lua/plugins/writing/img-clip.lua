return {
  "HakonHarnes/img-clip.nvim",
  ft = { "markdown", "tex" },
  keys = {
    { "<Leader>Wi", "<cmd>PasteImage<cr>", desc = "Paste clipboard image" },
  },
  opts = {
    default = {
      dir_path = "assets",
      relative_to_current_file = true,
      prompt_for_file_name = true,
      insert_mode_after_paste = true,
    },
    filetypes = {
      markdown = { template = "![$CURSOR]($FILE_PATH)" },
      tex = { template = "\\includegraphics[width=0.8\\textwidth]{$FILE_PATH}" },
    },
  },
}
