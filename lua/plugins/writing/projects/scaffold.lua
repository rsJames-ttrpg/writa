local entity = require("plugins.writing.projects.entity")
local format = require("plugins.writing.projects.format")
local slug_mod = require("plugins.writing.projects.slug")

local M = {}

local function dir_is_nonempty(path)
  if vim.fn.isdirectory(path) ~= 1 then return false end
  local entries = vim.fn.readdir(path)
  return #entries > 0
end

---@param opts {
---  type_loaded: { name: string, dir: string, definition: table },
---  title: string,
---  description: string?,
---  target_path: string,
---  open_after: boolean?,
---  confirmed: boolean?,
---}
function M.create(opts)
  local def = opts.type_loaded.definition
  local target = vim.fn.expand(opts.target_path)
  local description = opts.description or ""

  if dir_is_nonempty(target) and not opts.confirmed then
    error(("scaffold: target exists and is non-empty: %s"):format(target))
  end

  vim.fn.mkdir(target, "p")
  for _, sub in ipairs(def.directories or {}) do
    vim.fn.mkdir(target .. "/" .. sub, "p")
  end

  -- Marker file
  local marker_lines = {
    ("type: %s"):format(opts.type_loaded.name),
    ("title: %s"):format(opts.title),
    ("description: %s"):format(description),
    ("created: %s"):format(os.date("%Y-%m-%d")),
  }
  vim.fn.writefile(marker_lines, target .. "/.writa-project.yaml")

  -- Read templates from the type-bundle directory.
  local function read_template(rel_path)
    local abs = opts.type_loaded.dir .. "/" .. rel_path
    if vim.fn.filereadable(abs) ~= 1 then
      error(("scaffold: template not found: %s"):format(abs))
    end
    return table.concat(vim.fn.readfile(abs), "\n")
  end

  local project_slug = slug_mod.derive(opts.title)
  local project_ctx = {
    ["project.title"]       = opts.title,
    ["project.slug"]        = project_slug,
    ["project.description"] = description,
    slug                    = project_slug,
  }

  -- Root files
  for _, rf in ipairs(def.root_files or {}) do
    local body = format.render(read_template(rf.template), project_ctx)
    local out_path = target .. "/" .. rf.path
    vim.fn.mkdir(vim.fn.fnamemodify(out_path, ":h"), "p")
    vim.fn.writefile(vim.split(body, "\n", { plain = true }), out_path)
  end

  -- Initial entities. entity.create reads templates from the project root,
  -- so stage them temporarily into <target>/<def.template>.
  local first_entity_path
  for _, init in ipairs(def.initial or {}) do
    local ent_def = def.entities[init.entity]
    if not ent_def then
      error(("scaffold: initial[].entity refers to unknown type %q"):format(init.entity))
    end

    local body_template = read_template(ent_def.template)
    local stage_path = target .. "/" .. ent_def.template
    vim.fn.mkdir(vim.fn.fnamemodify(stage_path, ":h"), "p")
    vim.fn.writefile(vim.split(body_template, "\n", { plain = true }), stage_path)

    local result = entity.create({
      project_root = target,
      project_meta = {
        type = opts.type_loaded.name,
        title = opts.title,
        description = description,
      },
      entity_def = ent_def,
      type_def   = def,
      values     = vim.deepcopy(init.values or {}),
      open_after = false,
    })

    if not first_entity_path then first_entity_path = result.path end
  end

  -- Clean up staged templates (templates/ subdir is internal scaffolding).
  if vim.fn.isdirectory(target .. "/templates") == 1 then
    vim.fn.delete(target .. "/templates", "rf")
  end

  if opts.open_after then
    local to_open = first_entity_path
      or (vim.fn.filereadable(target .. "/README.md") == 1 and target .. "/README.md")
      or target
    vim.cmd.edit(to_open)
  end

  return { project_root = target, first_entity_path = first_entity_path }
end

return M
