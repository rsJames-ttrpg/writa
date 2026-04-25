local format = require("plugins.writing.projects.format")
local refs = require("plugins.writing.projects.refs")
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

local function pick(items, prompt)
  local result
  vim.ui.select(items, { prompt = prompt }, function(choice) result = choice end)
  return result
end

local function multi_pick(items, prompt)
  local picked = {}
  while true do
    local remaining = {}
    for _, it in ipairs(items) do
      local already = false
      for _, p in ipairs(picked) do if p == it then already = true; break end end
      if not already then table.insert(remaining, it) end
    end
    if #remaining == 0 then break end
    table.insert(remaining, 1, "<done>")
    local choice = pick(remaining, prompt)
    if not choice or choice == "<done>" then break end
    table.insert(picked, choice)
  end
  return picked
end

local function prompt_field(field, ctx)
  local function input(prompt)
    local result
    vim.ui.input({ prompt = prompt }, function(v) result = v end)
    return result
  end

  if field.type == "string" then
    return input(field.name .. (field.required and " (required): " or ": "))
  end

  if field.type == "int" then
    local raw = input(field.name .. ": ")
    if raw == nil or raw == "" then return nil end
    local n = tonumber(raw)
    if not n then error(("entity: %q expected int, got %q"):format(field.name, raw)) end
    return n
  end

  if field.type == "list" then
    local raw = input(field.name .. " (comma-separated): ")
    if raw == nil or raw == "" then return nil end
    local out = {}
    for s in raw:gmatch("[^,]+") do
      table.insert(out, vim.trim(s))
    end
    return out
  end

  local ref_kind = field.type:match("^ref%(([%w_]+)%)$")
  if ref_kind then
    local glob_template = ctx.type_def.entities[ref_kind].filename
    local glob = M.glob_for_filename(glob_template)
    local matches = vim.fn.glob(ctx.project_root .. "/" .. glob, false, true)
    local relpaths = {}
    for _, abs in ipairs(matches) do
      table.insert(relpaths, abs:sub(#ctx.project_root + 2))
    end
    if #relpaths == 0 then
      vim.notify(("no %s entities exist yet — skipping ref"):format(ref_kind))
      return nil
    end
    local picked = pick(relpaths, ("%s (%s): "):format(field.name, ref_kind))
    return picked and refs.to_wikilink(picked) or nil
  end

  local list_kind = field.type:match("^list%(([%w_]+)%)$")
  if list_kind then
    local glob_template = ctx.type_def.entities[list_kind].filename
    local glob = M.glob_for_filename(glob_template)
    local matches = vim.fn.glob(ctx.project_root .. "/" .. glob, false, true)
    local relpaths = {}
    for _, abs in ipairs(matches) do
      table.insert(relpaths, abs:sub(#ctx.project_root + 2))
    end
    if #relpaths == 0 then return {} end
    local picked = multi_pick(relpaths, ("%s (%s): "):format(field.name, list_kind))
    local out = {}
    for _, p in ipairs(picked) do table.insert(out, refs.to_wikilink(p)) end
    return out
  end

  error(("entity: unknown field type %q"):format(field.type))
end

---Create one entity file. Uses vim.ui only for fields not in `values`.
---@param opts { project_root: string, project_meta: table, entity_def: table,
---              type_def: table?, values: table?, open_after: boolean? }
---@return { path: string }
function M.create(opts)
  local def = opts.entity_def
  local values = vim.deepcopy(opts.values or {})

  for _, field in ipairs(def.fields) do
    if values[field.name] == nil then
      local v = prompt_field(field, {
        project_root = opts.project_root,
        type_def = opts.type_def or { entities = { __dummy__ = def } },
      })
      if field.required and (v == nil or v == "") then
        error(("entity: required field %q not provided"):format(field.name))
      end
      if v ~= nil and v ~= "" then values[field.name] = v end
    end
  end

  local source_field = slug_mod.source_field(def.fields)
  if not source_field then
    error("entity: no slug-source field; entity type needs an explicit slug")
  end
  local slug = slug_mod.derive(tostring(values[source_field]))

  local ctx = vim.tbl_extend("force", {}, values)
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
