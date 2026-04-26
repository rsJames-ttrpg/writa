local M = {}

local STRIPPABLE = { "%.md$", "%.markdown$", "%.fountain$" }

---Convert a project-relative path to an obsidian-style wikilink.
---@param relpath string  e.g. "characters/jack.md"
---@return string         e.g. "[[characters/jack]]"
function M.to_wikilink(relpath)
  if relpath:sub(1, 1) == "/" then
    error(("refs: expected project-relative path, got %q"):format(relpath))
  end
  local stem = relpath
  for _, pat in ipairs(STRIPPABLE) do
    stem = stem:gsub(pat, "")
  end
  return "[[" .. stem .. "]]"
end

return M
