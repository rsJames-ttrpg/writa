local M = {}

---Derive a URL-safe slug from a string per spec §Slug rule.
---@param input string
---@return string
function M.derive(input)
  if type(input) ~= "string" then return "" end
  local lower = input:lower()
  -- Replace any run of non-ASCII-alphanumeric with a single dash.
  -- %w in Lua is locale-aware in some builds; use an explicit class.
  local with_dashes = lower:gsub("[^a-z0-9]+", "-")
  local trimmed = with_dashes:gsub("^%-+", ""):gsub("%-+$", "")
  return trimmed
end

---Find the slug-source field for an entity type per spec §Slug rule:
---first required+string field among {title, name}, else first required+string.
---@param fields { name: string, type: string, required: boolean? }[]
---@return string? field_name
function M.source_field(fields)
  local function is_required_string(f)
    return f.type == "string" and f.required == true
  end

  for _, preferred in ipairs({ "title", "name" }) do
    for _, f in ipairs(fields) do
      if f.name == preferred and is_required_string(f) then
        return f.name
      end
    end
  end

  for _, f in ipairs(fields) do
    if is_required_string(f) then return f.name end
  end

  return nil
end

return M
