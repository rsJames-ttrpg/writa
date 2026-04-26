local M = {}

---Locate the yq binary. Prefers Mason's Go yq install (the only flavor we support).
---Falls back to PATH yq if it appears to be Go yq (mikefarah/yq).
---@return string  absolute path to yq executable
local function find_yq()
  local mason_yq = vim.fn.stdpath("data") .. "/mason/bin/yq"
  if vim.fn.executable(mason_yq) == 1 then return mason_yq end

  local path_yq = vim.fn.exepath("yq")
  if path_yq ~= "" then
    -- Sniff version output to confirm it's Go yq, not Python yq.
    local probe = vim.system({ path_yq, "--version" }, { text = true }):wait()
    if probe.code == 0 and (probe.stdout or ""):match("mikefarah") then
      return path_yq
    end
  end

  error("loader: Go yq not found. Install via Mason: :MasonInstall yq")
end

---Run yq to convert a YAML file to JSON, then decode.
---@param path string
---@return table
function M.parse_yaml_file(path)
  if vim.fn.filereadable(path) ~= 1 then
    error(("loader: file not found: %s"):format(path))
  end
  local yq = find_yq()
  local result = vim.system({ yq, "-o=json", path }, { text = true }):wait()
  if result.code ~= 0 then
    error(("loader: yq failed on %s: %s"):format(path, result.stderr or ""))
  end
  local ok, decoded = pcall(vim.json.decode, result.stdout)
  if not ok then
    error(("loader: invalid JSON from yq for %s: %s"):format(path, decoded))
  end
  return decoded
end

local function check(cond, msg)
  if not cond then error("loader: " .. msg) end
end

---Validate a project-type table. Errors with a descriptive message on failure.
---@param def table
---@return boolean
function M.validate_type(def)
  check(type(def) == "table", "type definition must be a table")
  check(type(def.name) == "string", "missing or non-string 'name'")
  check(type(def.entities) == "table", "missing or non-table 'entities'")
  check(type(def.directories) == "table", "missing or non-table 'directories'")
  if def.root_files then
    check(type(def.root_files) == "table", "'root_files' must be a list")
  end
  if def.initial then
    check(type(def.initial) == "table", "'initial' must be a list")
  end

  for ent_name, ent in pairs(def.entities) do
    check(type(ent.filename) == "string",
      ("entity %q: missing or non-string 'filename'"):format(ent_name))
    check(type(ent.template) == "string",
      ("entity %q: missing or non-string 'template'"):format(ent_name))
    check(type(ent.fields) == "table",
      ("entity %q: missing or non-table 'fields'"):format(ent_name))

    for i, field in ipairs(ent.fields) do
      check(type(field.name) == "string",
        ("entity %q field %d: missing 'name'"):format(ent_name, i))
      check(type(field.type) == "string",
        ("entity %q field %d: missing 'type'"):format(ent_name, i))
      check(field.type:match("^string$")
         or field.type:match("^int$")
         or field.type:match("^list$")
         or field.type:match("^ref%([%w_]+%)$")
         or field.type:match("^list%([%w_]+%)$"),
        ("entity %q field %q: bad type %q"):format(ent_name, field.name, field.type))
    end
  end

  return true
end

---Load and validate a single project type by directory.
---Returns { name, dir, definition }.
---@param dir string  absolute path to the type directory
---@return table
function M.load_type(dir)
  local name = vim.fn.fnamemodify(dir, ":t")
  local yaml_path = dir .. "/" .. name .. ".yaml"
  local def = M.parse_yaml_file(yaml_path)
  M.validate_type(def)
  return { name = name, dir = dir, definition = def }
end

---Discover all project types under a project-types root directory.
---@param root string  e.g. ~/.config/writa/project-types
---@return table[] list of { name, dir, definition }
function M.discover_types(root)
  local expanded = vim.fn.expand(root)
  local out = {}
  if vim.fn.isdirectory(expanded) ~= 1 then return out end
  local entries = vim.fn.readdir(expanded)
  for _, name in ipairs(entries) do
    local sub = expanded .. "/" .. name
    if vim.fn.isdirectory(sub) == 1 then
      local yaml_path = sub .. "/" .. name .. ".yaml"
      if vim.fn.filereadable(yaml_path) == 1 then
        local ok, loaded = pcall(M.load_type, sub)
        if ok then
          table.insert(out, loaded)
        else
          vim.notify(
            ("writa-projects: failed to load type %q: %s"):format(name, loaded),
            vim.log.levels.WARN)
        end
      end
    end
  end
  return out
end

---Read a .writa-project.yaml marker file.
---@param path string
---@return { type: string, title: string, description: string?, created: string? }
function M.read_marker(path)
  local data = M.parse_yaml_file(path)
  return {
    type        = data.type,
    title       = data.title,
    description = data.description,
    created     = data.created,
  }
end

---Walk up from a directory to find an enclosing .writa-project.yaml.
---@param start_dir string  absolute path
---@return string? marker_path, string? project_root
function M.find_project_root(start_dir)
  local dir = vim.fn.fnamemodify(start_dir, ":p"):gsub("/$", "")
  while dir ~= "" and dir ~= "/" do
    local candidate = dir .. "/.writa-project.yaml"
    if vim.fn.filereadable(candidate) == 1 then
      return candidate, dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
  return nil, nil
end

return M
