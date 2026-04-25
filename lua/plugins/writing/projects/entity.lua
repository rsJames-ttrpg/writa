local format = require("plugins.writing.projects.format")
local slug_mod = require("plugins.writing.projects.slug")

local M = {}

local function emit_scalar(k, v)
  if type(v) == "number" or type(v) == "boolean" then
    return ("%s: %s"):format(k, tostring(v))
  end
  local s = tostring(v)
  if s:match("[:%[%]{}!&*%%@`]") or s:match("^%s") or s:match("%s$") then
    return ("%s: %q"):format(k, s)
  end
  return ("%s: %s"):format(k, s)
end

local function emit_list(k, list)
  local lines = { k .. ":" }
  for _, item in ipairs(list) do
    if type(item) == "string" and item:match("[:%[%]{}!&*%%@`]") then
      table.insert(lines, ("  - %q"):format(item))
    else
      table.insert(lines, ("  - %s"):format(tostring(item)))
    end
  end
  return table.concat(lines, "\n")
end

---Build a YAML frontmatter block from a flat table.
---Keys emitted in alphabetical order for determinism.
---@param values table<string, any>
---@return string
function M.frontmatter_yaml(values)
  local keys = vim.tbl_keys(values)
  table.sort(keys)
  local body = {}
  for _, k in ipairs(keys) do
    local v = values[k]
    if type(v) == "table" then
      table.insert(body, emit_list(k, v))
    else
      table.insert(body, emit_scalar(k, v))
    end
  end
  if #body == 0 then return "---\n---\n" end
  return "---\n" .. table.concat(body, "\n") .. "\n---\n"
end

---Replace every {token} segment in a filename template with `*`.
---@param filename_template string
---@return string
function M.glob_for_filename(filename_template)
  return (filename_template:gsub("{[^{}]*}", "*"))
end

---Create one entity file from fully-resolved field values.
---No UI prompting — the caller must collect values via continuation-chain
---before invoking this. Required fields missing from `values` are an error.
---@param opts { project_root: string, project_meta: table, entity_def: table, values: table, open_after: boolean? }
---@return { path: string }
function M.create(opts)
  local def = opts.entity_def
  local values = vim.deepcopy(opts.values or {})

  for _, field in ipairs(def.fields) do
    if field.required and (values[field.name] == nil or values[field.name] == "") then
      error(("entity: required field %q not provided"):format(field.name))
    end
  end

  local source_field = slug_mod.source_field(def.fields)
  if not source_field then
    error("entity: no slug-source field; entity type needs an explicit slug")
  end
  local slug = slug_mod.derive(tostring(values[source_field]))

  local ctx = vim.tbl_extend("force", {}, values)
  for _, field in ipairs(def.fields) do
    if ctx[field.name] == nil then ctx[field.name] = "" end
  end
  ctx.slug = slug
  ctx["project.title"]       = opts.project_meta.title
  ctx["project.slug"]        = slug_mod.derive(opts.project_meta.title or "")
  ctx["project.description"] = opts.project_meta.description or ""

  local rel = format.render(def.filename, ctx)
  local abs = opts.project_root .. "/" .. rel

  if vim.fn.filereadable(abs) == 1 then
    error(("entity: file already exists: %s"):format(abs))
  end

  local tmpl_path = opts.project_root .. "/" .. def.template
  if vim.fn.filereadable(tmpl_path) ~= 1 then
    error(("entity: template not found: %s"):format(tmpl_path))
  end
  local body_template = table.concat(vim.fn.readfile(tmpl_path), "\n")
  local body = format.render(body_template, ctx)

  local content = M.frontmatter_yaml(values) .. body

  vim.fn.mkdir(vim.fn.fnamemodify(abs, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), abs)

  if opts.open_after then vim.cmd.edit(abs) end
  return { path = abs }
end

return M
