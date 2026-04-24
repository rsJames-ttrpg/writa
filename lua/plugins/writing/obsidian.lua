return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  cmd = {
    "ObsidianOpen", "ObsidianNew", "ObsidianQuickSwitch", "ObsidianFollowLink",
    "ObsidianBacklinks", "ObsidianTags", "ObsidianToday", "ObsidianYesterday",
    "ObsidianTomorrow", "ObsidianTemplate", "ObsidianSearch", "ObsidianLink",
    "ObsidianLinkNew", "ObsidianWorkspace", "ObsidianPasteImg", "ObsidianRename",
  },
  keys = {
    { "<Leader>Wo", "<cmd>ObsidianQuickSwitch<cr>", desc = "Obsidian quick switch" },
    { "<Leader>Wn", "<cmd>ObsidianNew<cr>", desc = "Obsidian new note" },
    { "<Leader>Wd", "<cmd>ObsidianToday<cr>", desc = "Obsidian today" },
    { "<Leader>Wb", "<cmd>ObsidianBacklinks<cr>", desc = "Obsidian backlinks" },
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      { name = "notes", path = "~/notes" },
    },
    completion = { nvim_cmp = true, min_chars = 2 },
    notes_subdir = "inbox",
    daily_notes = { folder = "daily" },
    new_notes_location = "notes_subdir",
    ui = { enable = false },
  },
}
