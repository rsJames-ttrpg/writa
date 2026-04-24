---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 500, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = { update_in_insert = false },
    options = {
      opt = {
        spell = true,
        spelllang = "en_us",
        wrap = true,
        linebreak = true,
        breakindent = true,
        conceallevel = 2,
        concealcursor = "",
        relativenumber = true,
        number = true,
        signcolumn = "yes",
        scrolloff = 8,
        undofile = true,
        timeoutlen = 300,
      },
      g = {
        mapleader = " ",
        maplocalleader = ",",
      },
    },
    mappings = {
      n = {
        ["<Leader>W"] = { desc = "Writing" },
      },
    },
  },
}
