-- Aggregates all plugin specs in this directory into one LazySpec list.
-- Each file in this directory returns a single plugin spec (a table).
-- Future extraction to astrocommunity: this file becomes the pack entry point.
local M = {}

local files = {
  "ltex",
  "pencil",
  "zen-mode",
  "render-markdown",
  "img-clip",
  "undotree",
  "obsidian",
  "markdown-preview",
  "autolist",
  "fountain",
  "vimtex",
  "pomo",
  "translate",
  "thesaurus",
  "cmp-dictionary",
  "noice",
  "gen",
}

for _, name in ipairs(files) do
  local ok, spec = pcall(require, "plugins.writing." .. name)
  if ok and spec then
    table.insert(M, spec)
  end
end

return M
