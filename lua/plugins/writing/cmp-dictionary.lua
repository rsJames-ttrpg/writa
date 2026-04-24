local function existing_dict_paths()
  local candidates = {
    "/usr/share/dict/words",
    "/usr/share/dict/american-english",
    "/usr/share/dict/british-english",
  }
  local paths = {}
  for _, p in ipairs(candidates) do
    if vim.loop.fs_stat(p) then
      table.insert(paths, p)
    end
  end
  return paths
end

return {
  "uga-rosa/cmp-dictionary",
  event = "InsertEnter",
  dependencies = { "hrsh7th/nvim-cmp" },
  config = function()
    local dict = require("cmp_dictionary")
    dict.setup({
      paths = existing_dict_paths(),
      exact_length = 2,
      first_case_insensitive = true,
    })

    local cmp = require("cmp")
    cmp.setup.filetype({ "markdown", "text", "tex", "fountain" }, {
      sources = cmp.config.sources({
        { name = "dictionary", keyword_length = 2 },
        { name = "buffer" },
        { name = "path" },
      }),
    })
  end,
}
