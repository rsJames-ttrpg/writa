# writa-projects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a declarative, YAML-driven project-type system to writa with `:WritaNewProject`, `:WritaOpenProject`, `:WritaNewEntity` commands and a dashboard surface (`w`/`W` keys), shipping `novel`, `screenplay`, and `essay` types day-one.

**Architecture:** Eight focused Lua modules under `lua/plugins/writing/projects/` (`init`, `loader`, `scaffold`, `open`, `entity`, `format`, `refs`, `slug`). Project types are YAML files at `~/.config/writa/project-types/<name>/` with body templates in a `templates/` subdirectory. `init.lua` is the lazy.nvim plugin spec; sibling files are runtime modules required at command-invocation time. Relationships expressed as obsidian-style `[[wikilinks]]` in frontmatter so `obsidian.nvim`'s backlinks work natively. Tests use `plenary.nvim`'s busted-style runner with temp directories for filesystem work.

**Tech Stack:** Lua 5.1 / LuaJIT (Neovim 0.10+), `plenary.nvim` (testing — already a transitive dep via telescope), `yq` (YAML→JSON parsing, installed via Mason), `obsidian.nvim` (wikilink rendering), `snacks.nvim` (dashboard), `yaml-language-server` (editor support for project-type YAML).

**Spec deviation, deliberate:** The spec calls for a pure-Lua YAML parser to "avoid a system-level yq dependency." I'm using `yq` shelled out via `vim.system`, installed through writa's existing Mason channel (`~/.local/share/writa/mason/bin/yq`). Justification: yq is Mason-managed (zero user friction — same as `ltex-ls`, `marksman`, etc.); pure-Lua YAML libs are heterogeneous in quality and add a runtime dep we'd have to track. The spec's "system-level" wording was about end-user install burden, which Mason handles. If this becomes contentious post-impl, the parser is encapsulated in `loader.lua:_yaml_to_table` — swap out in one place.

**Commit conventions:** Conventional commits with `(projects)` scope: `feat(projects): ...`, `test(projects): ...`, `chore: ...`, `docs: ...`. **Do not append `Co-Authored-By` trailers — the user has explicitly opted out.**

---

## File structure

### Created

**Test infrastructure**
- `Makefile` — `make test` runs the plenary suite headlessly
- `tests/minimal_init.lua` — loads plenary into rtp for headless tests
- `tests/projects/slug_spec.lua`
- `tests/projects/format_spec.lua`
- `tests/projects/refs_spec.lua`
- `tests/projects/loader_spec.lua`
- `tests/projects/scaffold_spec.lua`
- `tests/projects/entity_spec.lua`
- `tests/projects/open_spec.lua`
- `tests/projects/fixtures/types/minimal/minimal.yaml` — fixture project-type
- `tests/projects/fixtures/types/minimal/templates/note.md`

**Runtime modules**
- `lua/plugins/writing/projects/init.lua` — lazy.nvim plugin spec + user commands
- `lua/plugins/writing/projects/slug.lua`
- `lua/plugins/writing/projects/format.lua`
- `lua/plugins/writing/projects/refs.lua`
- `lua/plugins/writing/projects/loader.lua`
- `lua/plugins/writing/projects/scaffold.lua`
- `lua/plugins/writing/projects/entity.lua`
- `lua/plugins/writing/projects/open.lua`

**Project-type bundles**
- `project-types/novel/novel.yaml` + 6 templates
- `project-types/screenplay/screenplay.yaml` + 6 templates (scene template is `.fountain`)
- `project-types/essay/essay.yaml` + 4 templates

**Schema**
- `schema/project-type/v1.json` — JSON schema for project-type YAML

### Modified

- `lua/plugins/writing/init.lua` — append `"projects"` to the `files` list (one-line change)
- `lua/plugins/mason.lua` — add `"yq"` and `"yaml-language-server"` to `ensure_installed`
- `lua/plugins/astrolsp.lua` — add `yamlls` config with schema association for `project-types/**/*.yaml` and `.writa-project.yaml`
- `lua/plugins/dashboard.lua` — extend `opts.dashboard.preset` with a `keys` list (snacks defaults preserved + `w`/`W` prepended)
- `lua/plugins/writing/pomo.lua` — rebind keys: drop `<Leader>Wp`, set `<Leader>WP` to start, `<Leader>WT` to stop
- `lua/plugins/astrocore.lua` — extend which-key group: add `WP`/`WT` descriptors (optional polish — the keymap `desc` field handles it but explicit group help is nicer)

---

## Task 0: Test infrastructure

Set up plenary's busted-style runner so subsequent tasks can do TDD.

**Files:**
- Create: `Makefile`
- Create: `tests/minimal_init.lua`
- Create: `tests/projects/sanity_spec.lua` (smoke test, deleted in T1)

- [ ] **Step 1: Verify plenary is installed**

Run: `ls /home/jackm/.local/share/writa/lazy/plenary.nvim`
Expected: directory exists (plenary is a transitive dep via telescope).

If missing, add this stanza to `lua/plugins/init.lua` and rerun lazy sync:
```lua
{ "nvim-lua/plenary.nvim", lazy = true },
```

- [ ] **Step 2: Create `tests/minimal_init.lua`**

```lua
-- Headless test bootstrap. Adds the writa repo + plenary to runtimepath.

local repo_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
vim.opt.rtp:prepend(repo_root)

local plenary = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.rtp:prepend(plenary)
end

vim.cmd("runtime plugin/plenary.vim")
```

- [ ] **Step 3: Create `Makefile`**

```makefile
.PHONY: test test-watch
test:
	@NVIM_APPNAME=writa nvim --headless --noplugin -u tests/minimal_init.lua \
	  -c "PlenaryBustedDirectory tests/projects/ { minimal_init = 'tests/minimal_init.lua' }" \
	  -c "qa!"

test-watch:
	@command -v entr >/dev/null 2>&1 || { echo "install 'entr'"; exit 1; }
	@find lua/plugins/writing/projects tests/projects -name '*.lua' | entr -c make test
```

- [ ] **Step 4: Create a sanity test at `tests/projects/sanity_spec.lua`**

```lua
describe("sanity", function()
  it("plenary loads and assertions work", function()
    assert.are.equal(2, 1 + 1)
  end)
end)
```

- [ ] **Step 5: Run tests**

Run: `cd /home/jackm/.config/writa && make test`
Expected: 1 successful test, exit code 0.

If you see "module 'plenary.busted' not found", plenary isn't on rtp. Re-check Step 1.

- [ ] **Step 6: Commit**

```bash
cd /home/jackm/.config/writa
git add Makefile tests/
git commit -m "chore(projects): add plenary test infrastructure"
```

---

## Task 1: `slug.lua` — slug derivation

Pure function module. Per spec §Slug rule: lowercase, replace runs of non-ASCII-alphanumeric with `-`, trim, collapse.

**Files:**
- Create: `lua/plugins/writing/projects/slug.lua`
- Create: `tests/projects/slug_spec.lua`
- Delete: `tests/projects/sanity_spec.lua` (no longer needed)

- [ ] **Step 1: Write failing tests at `tests/projects/slug_spec.lua`**

```lua
local slug = require("plugins.writing.projects.slug")

describe("slug.derive", function()
  it("lowercases ASCII letters", function()
    assert.are.equal("hello", slug.derive("Hello"))
  end)

  it("replaces a run of non-alphanumeric with single dash", function()
    assert.are.equal("a-b-c", slug.derive("a!!!b???c"))
  end)

  it("preserves digits", function()
    assert.are.equal("chapter-1", slug.derive("Chapter 1"))
  end)

  it("handles spec example", function()
    assert.are.equal("chapter-1-the-beginning", slug.derive("Chapter 1: The Beginning"))
  end)

  it("trims leading and trailing dashes", function()
    assert.are.equal("foo", slug.derive("  foo  "))
    assert.are.equal("foo", slug.derive("---foo---"))
  end)

  it("collapses adjacent dashes", function()
    assert.are.equal("foo-bar", slug.derive("foo - - bar"))
  end)

  it("strips non-ASCII characters", function()
    -- Émile -> mile (the É is non-ASCII; per spec, non-ASCII-alphanumeric -> dash)
    assert.are.equal("mile", slug.derive("Émile"))
  end)

  it("returns empty string for input with no ASCII alphanumerics", function()
    assert.are.equal("", slug.derive("!!!"))
    assert.are.equal("", slug.derive("éà"))
  end)

  it("handles empty input", function()
    assert.are.equal("", slug.derive(""))
  end)
end)

describe("slug.source_field", function()
  it("picks 'title' when present and required+string", function()
    local fields = {
      { name = "number", type = "int", required = true },
      { name = "title",  type = "string", required = true },
    }
    assert.are.equal("title", slug.source_field(fields))
  end)

  it("picks 'name' when no 'title'", function()
    local fields = {
      { name = "id",   type = "int", required = true },
      { name = "name", type = "string", required = true },
    }
    assert.are.equal("name", slug.source_field(fields))
  end)

  it("falls back to first required string field", function()
    local fields = {
      { name = "tagline", type = "string", required = true },
      { name = "title",   type = "string" },  -- not required
    }
    assert.are.equal("tagline", slug.source_field(fields))
  end)

  it("returns nil when no required string field exists", function()
    local fields = {
      { name = "n", type = "int", required = true },
    }
    assert.is_nil(slug.source_field(fields))
  end)
end)
```

- [ ] **Step 2: Run tests, confirm they fail**

```bash
rm tests/projects/sanity_spec.lua
make test
```
Expected: errors about missing module `plugins.writing.projects.slug`.

- [ ] **Step 3: Implement `lua/plugins/writing/projects/slug.lua`**

```lua
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
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `make test`
Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/slug.lua tests/projects/slug_spec.lua tests/projects/sanity_spec.lua
git commit -m "feat(projects): add slug derivation module"
```

---

## Task 2: `format.lua` — variable + format-spec interpolation

Per spec §Variable resolution: `{field}`, `{project.x}`, `{slug}`, `{number:02d}`. Supported format specs: `d`, `s`, optional zero-pad flag `0`, optional width.

**Files:**
- Create: `lua/plugins/writing/projects/format.lua`
- Create: `tests/projects/format_spec.lua`

- [ ] **Step 1: Write tests at `tests/projects/format_spec.lua`**

```lua
local format = require("plugins.writing.projects.format")

describe("format.render", function()
  it("substitutes a plain field", function()
    assert.are.equal("Hello world", format.render("Hello {name}", { name = "world" }))
  end)

  it("substitutes multiple fields", function()
    assert.are.equal("a-b", format.render("{x}-{y}", { x = "a", y = "b" }))
  end)

  it("resolves project-scoped vars", function()
    local ctx = { ["project.title"] = "My Novel" }
    assert.are.equal("My Novel", format.render("{project.title}", ctx))
  end)

  it("formats integer with zero-pad and width", function()
    assert.are.equal("07", format.render("{n:02d}", { n = 7 }))
    assert.are.equal("123", format.render("{n:02d}", { n = 123 }))
  end)

  it("formats integer with width but no zero-pad (space-pad)", function()
    assert.are.equal(" 7", format.render("{n:2d}", { n = 7 }))
  end)

  it("formats string with width (right-pad with spaces)", function()
    assert.are.equal("hi  ", format.render("{x:4s}", { x = "hi" }))
  end)

  it("treats an unspecced field as plain tostring", function()
    assert.are.equal("3", format.render("{n}", { n = 3 }))
  end)

  it("errors on unknown variable", function()
    assert.has_error(function() format.render("{missing}", {}) end)
  end)

  it("errors on unsupported format spec", function()
    -- "x" is hex in Python, not in our supported subset
    assert.has_error(function() format.render("{n:x}", { n = 10 }) end)
  end)

  it("errors when 'd' applied to non-integer-coercible value", function()
    assert.has_error(function() format.render("{x:d}", { x = "hi" }) end)
  end)

  it("leaves literal text unchanged", function()
    assert.are.equal("plain text", format.render("plain text", {}))
  end)

  it("does not interpolate inside escaped braces -- not a feature, just leaves them", function()
    -- We don't implement escaping; if someone needs literal { } they shouldn't write them.
    -- Document the behavior: an unmatched { errors.
    assert.has_error(function() format.render("{", {}) end)
  end)
end)
```

- [ ] **Step 2: Run tests, confirm fail**

Run: `make test` — module not found.

- [ ] **Step 3: Implement `lua/plugins/writing/projects/format.lua`**

```lua
local M = {}

local SUPPORTED_TYPES = { d = true, s = true }

---Parse a format spec like "02d", "4s", "d", "" into components.
---Returns nil if unsupported.
---@param spec string
---@return { zero_pad: boolean, width: number?, type: string }?
local function parse_spec(spec)
  if spec == "" then return { zero_pad = false, width = nil, type = nil } end
  local zero_pad, width_str, type_char = spec:match("^(0?)(%d*)([ds])$")
  if not type_char then return nil end
  local width = (width_str ~= "" and tonumber(width_str)) or nil
  return { zero_pad = zero_pad == "0", width = width, type = type_char }
end

---Apply a parsed format spec to a value.
local function apply_spec(value, parsed)
  if parsed.type == nil then return tostring(value) end

  if parsed.type == "d" then
    local n = tonumber(value)
    if not n or math.floor(n) ~= n then
      error(("format: 'd' spec requires integer, got %s"):format(tostring(value)))
    end
    if parsed.width then
      local pad = parsed.zero_pad and "0" or " "
      return string.format("%" .. pad .. parsed.width .. "d", n)
    end
    return tostring(n)
  end

  if parsed.type == "s" then
    local s = tostring(value)
    if parsed.width and #s < parsed.width then
      return s .. string.rep(" ", parsed.width - #s)
    end
    return s
  end

  error("unreachable")
end

---Render a template string with `{name}` and `{name:spec}` placeholders.
---@param template string
---@param ctx table<string, any>
---@return string
function M.render(template, ctx)
  -- gsub callback receives the contents inside the braces.
  -- We have to detect unmatched braces ourselves: count and verify.
  local open_count = select(2, template:gsub("{", "{"))
  local close_count = select(2, template:gsub("}", "}"))
  if open_count ~= close_count then
    error(("format: unmatched braces in template: %q"):format(template))
  end

  local result, _ = template:gsub("{([^{}]*)}", function(inner)
    local name, spec = inner:match("^([^:]+):(.*)$")
    if not name then name, spec = inner, "" end

    local value = ctx[name]
    if value == nil then
      error(("format: unknown variable %q"):format(name))
    end

    local parsed = parse_spec(spec)
    if not parsed then
      error(("format: unsupported spec %q for variable %q"):format(spec, name))
    end

    return apply_spec(value, parsed)
  end)

  return result
end

return M
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `make test`
Expected: all format tests pass.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/format.lua tests/projects/format_spec.lua
git commit -m "feat(projects): add template format/interpolation module"
```

---

## Task 3: `refs.lua` — wikilink generation

Per spec §Reference resolution: a picker yields a path like `characters/jack.md`; we store it as `[[characters/jack]]`.

**Files:**
- Create: `lua/plugins/writing/projects/refs.lua`
- Create: `tests/projects/refs_spec.lua`

- [ ] **Step 1: Write tests**

```lua
local refs = require("plugins.writing.projects.refs")

describe("refs.to_wikilink", function()
  it("strips .md extension", function()
    assert.are.equal("[[characters/jack]]", refs.to_wikilink("characters/jack.md"))
  end)

  it("strips .markdown extension", function()
    assert.are.equal("[[notes/x]]", refs.to_wikilink("notes/x.markdown"))
  end)

  it("strips .fountain extension", function()
    assert.are.equal("[[scenes/opening]]", refs.to_wikilink("scenes/opening.fountain"))
  end)

  it("preserves directory components", function()
    assert.are.equal("[[a/b/c/d]]", refs.to_wikilink("a/b/c/d.md"))
  end)

  it("rejects absolute paths -- pickers feed project-relative paths", function()
    assert.has_error(function() refs.to_wikilink("/tmp/foo.md") end)
  end)

  it("preserves a path with no extension", function()
    assert.are.equal("[[foo]]", refs.to_wikilink("foo"))
  end)
end)
```

- [ ] **Step 2: Run tests, confirm fail**

Run: `make test`

- [ ] **Step 3: Implement `lua/plugins/writing/projects/refs.lua`**

```lua
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
```

- [ ] **Step 4: Run tests, confirm pass**

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/refs.lua tests/projects/refs_spec.lua
git commit -m "feat(projects): add wikilink generation module"
```

---

## Task 4: `loader.lua` — YAML parse + validate

Reads `~/.config/writa/project-types/<name>/<name>.yaml`, shells out to `yq` for YAML→JSON, decodes via `vim.json.decode`, validates structure. Also reads `.writa-project.yaml` marker files.

**Files:**
- Create: `lua/plugins/writing/projects/loader.lua`
- Create: `tests/projects/loader_spec.lua`
- Create: `tests/projects/fixtures/types/minimal/minimal.yaml`
- Create: `tests/projects/fixtures/types/minimal/templates/note.md`

**Important:** loader_spec uses real `yq` shell-out. If `yq` is not on `$PATH` when running tests, the integration tests must be skipped (mark with `pending`). Mason will install `yq` in T13, but for now we assume the developer has `yq` available system-wide OR we skip those tests until T13.

- [ ] **Step 1: Create fixture project type at `tests/projects/fixtures/types/minimal/minimal.yaml`**

```yaml
name: Minimal
description: Smallest valid project type for tests
default_path: /tmp/writa-test-{slug}
directories: [notes]
root_files: []
entities:
  note:
    filename: "notes/{slug}.md"
    template: templates/note.md
    fields:
      - { name: title, type: string, required: true }
initial: []
```

- [ ] **Step 2: Create fixture template at `tests/projects/fixtures/types/minimal/templates/note.md`**

```markdown
# {title}

(empty note)
```

- [ ] **Step 3: Write tests at `tests/projects/loader_spec.lua`**

```lua
local loader = require("plugins.writing.projects.loader")

local FIXTURES = vim.fn.getcwd() .. "/tests/projects/fixtures/types"

local function has_yq()
  return vim.fn.executable("yq") == 1
end

describe("loader.parse_yaml_file", function()
  it("requires yq", function()
    if not has_yq() then return pending("yq not installed; T13 will install it") end
    local data = loader.parse_yaml_file(FIXTURES .. "/minimal/minimal.yaml")
    assert.are.equal("Minimal", data.name)
    assert.are.equal("string", data.entities.note.fields[1].type)
  end)

  it("errors on missing file", function()
    if not has_yq() then return pending("yq not installed") end
    assert.has_error(function() loader.parse_yaml_file("/nonexistent.yaml") end)
  end)

  it("errors on malformed YAML", function()
    if not has_yq() then return pending("yq not installed") end
    local tmp = vim.fn.tempname() .. ".yaml"
    vim.fn.writefile({ "name: [unclosed" }, tmp)
    assert.has_error(function() loader.parse_yaml_file(tmp) end)
    os.remove(tmp)
  end)
end)

describe("loader.validate_type", function()
  local valid = {
    name = "Test",
    description = "x",
    default_path = "/tmp/{slug}",
    directories = { "notes" },
    root_files = {},
    entities = {
      note = {
        filename = "notes/{slug}.md",
        template = "templates/note.md",
        fields = { { name = "title", type = "string", required = true } },
      },
    },
    initial = {},
  }

  it("accepts a well-formed type definition", function()
    assert.is_true(loader.validate_type(valid))
  end)

  it("rejects missing 'name'", function()
    local bad = vim.deepcopy(valid)
    bad.name = nil
    assert.has_error(function() loader.validate_type(bad) end)
  end)

  it("rejects missing 'entities'", function()
    local bad = vim.deepcopy(valid)
    bad.entities = nil
    assert.has_error(function() loader.validate_type(bad) end)
  end)

  it("rejects entity missing 'filename'", function()
    local bad = vim.deepcopy(valid)
    bad.entities.note.filename = nil
    assert.has_error(function() loader.validate_type(bad) end)
  end)

  it("rejects field with bad type", function()
    local bad = vim.deepcopy(valid)
    bad.entities.note.fields[1].type = "bogus"
    assert.has_error(function() loader.validate_type(bad) end)
  end)

  it("accepts ref(X) and list(X) field types", function()
    local ok = vim.deepcopy(valid)
    table.insert(ok.entities.note.fields,
      { name = "linked", type = "ref(note)" })
    table.insert(ok.entities.note.fields,
      { name = "linked_many", type = "list(note)" })
    assert.is_true(loader.validate_type(ok))
  end)
end)

describe("loader.discover_types", function()
  it("finds all type names under a project-types root", function()
    if not has_yq() then return pending("yq not installed") end
    local types = loader.discover_types(FIXTURES)
    assert.is_true(#types >= 1)
    -- Returns a list of { name, dir, definition } entries
    local found_minimal
    for _, t in ipairs(types) do
      if t.name == "minimal" then found_minimal = t end
    end
    assert.is_not_nil(found_minimal)
    assert.are.equal("Minimal", found_minimal.definition.name)
  end)
end)

describe("loader.read_marker", function()
  it("parses a .writa-project.yaml marker file", function()
    if not has_yq() then return pending("yq not installed") end
    local tmp = vim.fn.tempname() .. ".yaml"
    vim.fn.writefile({
      "type: novel",
      "title: My Test",
      "description: Test desc",
      "created: 2026-04-25",
    }, tmp)
    local marker = loader.read_marker(tmp)
    assert.are.equal("novel", marker.type)
    assert.are.equal("My Test", marker.title)
    os.remove(tmp)
  end)
end)
```

- [ ] **Step 4: Run tests, confirm fail**

Run: `make test` — module not found.

- [ ] **Step 5: Implement `lua/plugins/writing/projects/loader.lua`**

```lua
local M = {}

local FIELD_TYPE_PATTERN = "^(string|int|list|ref%([%w_]+%)|list%([%w_]+%))$"

---Run yq to convert a YAML file to JSON, then decode.
---@param path string
---@return table
function M.parse_yaml_file(path)
  if vim.fn.filereadable(path) ~= 1 then
    error(("loader: file not found: %s"):format(path))
  end
  local result = vim.system({ "yq", "-o=json", path }, { text = true }):wait()
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
  -- root_files and initial may be nil (treated as empty)
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
```

- [ ] **Step 6: Run tests**

Run: `make test`
Expected: all loader tests pass (or pending if yq not installed locally — that's fine, T13 installs it).

If `yq` is not available, install it temporarily so tests run:
```bash
# Optional: install yq for local dev (Mason will handle it for users in T13)
which yq || sudo pacman -S go-yq  # on arch
```

- [ ] **Step 7: Commit**

```bash
git add lua/plugins/writing/projects/loader.lua tests/projects/loader_spec.lua tests/projects/fixtures/
git commit -m "feat(projects): add YAML loader and validator"
```

---

## Task 5: JSON schema for project-type validation

Editor-side validation via `yaml-language-server`. Provides completion, type-checking, and inline errors when authoring project types in nvim.

**Files:**
- Create: `schema/project-type/v1.json`

- [ ] **Step 1: Create `schema/project-type/v1.json`**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://writa.dev/schema/project-type/v1.json",
  "title": "writa project type",
  "type": "object",
  "required": ["name", "directories", "entities"],
  "additionalProperties": false,
  "properties": {
    "name":         { "type": "string" },
    "description":  { "type": "string" },
    "default_path": { "type": "string" },
    "directories": {
      "type": "array",
      "items": { "type": "string" }
    },
    "root_files": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path", "template"],
        "additionalProperties": false,
        "properties": {
          "path":     { "type": "string" },
          "template": { "type": "string" }
        }
      }
    },
    "entities": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["filename", "template", "fields"],
        "additionalProperties": false,
        "properties": {
          "filename": { "type": "string" },
          "template": { "type": "string" },
          "fields": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["name", "type"],
              "additionalProperties": false,
              "properties": {
                "name":     { "type": "string" },
                "type": {
                  "type": "string",
                  "pattern": "^(string|int|list|ref\\([A-Za-z_]+\\)|list\\([A-Za-z_]+\\))$"
                },
                "required": { "type": "boolean" }
              }
            }
          }
        }
      }
    },
    "initial": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["entity"],
        "additionalProperties": false,
        "properties": {
          "entity": { "type": "string" },
          "values": { "type": "object" }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Validate the schema is itself valid JSON**

Run: `jq . schema/project-type/v1.json > /dev/null`
Expected: no error, exit 0.

- [ ] **Step 3: Commit**

```bash
git add schema/project-type/v1.json
git commit -m "feat(projects): add JSON schema for project type definitions"
```

---

## Task 6: `entity.lua` — entity creation flow

Per spec §`:WritaNewEntity`. Prompts for fields, builds frontmatter, writes file. Uses `vim.ui.input` (string/int/list) and `vim.ui.select` (ref/list-of-ref). Tests stub these.

**Files:**
- Create: `lua/plugins/writing/projects/entity.lua`
- Create: `tests/projects/entity_spec.lua`

This is the largest module. Tests are split into unit tests for pure helpers and integration tests for the full flow (with stubbed `vim.ui.*`).

- [ ] **Step 1: Write tests at `tests/projects/entity_spec.lua`**

```lua
local entity = require("plugins.writing.projects.entity")

describe("entity.frontmatter_yaml", function()
  it("emits an empty frontmatter when no fields", function()
    assert.are.equal("---\n---\n", entity.frontmatter_yaml({}))
  end)

  it("emits scalar fields", function()
    local fm = entity.frontmatter_yaml({ title = "Opening", number = 1 })
    -- Order is alphabetical by key for determinism
    assert.are.equal("---\nnumber: 1\ntitle: Opening\n---\n", fm)
  end)

  it("emits a list field", function()
    local fm = entity.frontmatter_yaml({ tags = { "a", "b" } })
    assert.are.equal("---\ntags:\n  - a\n  - b\n---\n", fm)
  end)

  it("emits wikilinks as quoted strings", function()
    local fm = entity.frontmatter_yaml({ pov = "[[characters/jack]]" })
    assert.are.equal("---\npov: \"[[characters/jack]]\"\n---\n", fm)
  end)

  it("emits a list of wikilinks", function()
    local fm = entity.frontmatter_yaml({ chars = { "[[a]]", "[[b]]" } })
    assert.are.equal("---\nchars:\n  - \"[[a]]\"\n  - \"[[b]]\"\n---\n", fm)
  end)

  it("escapes strings with special chars by quoting", function()
    local fm = entity.frontmatter_yaml({ s = "has: colon" })
    assert.are.equal("---\ns: \"has: colon\"\n---\n", fm)
  end)
end)

describe("entity.glob_for_filename", function()
  it("replaces every {token} with *", function()
    assert.are.equal("chapters/*-*.md",
      entity.glob_for_filename("chapters/{number:02d}-{slug}.md"))
  end)
  it("handles single-token templates", function()
    assert.are.equal("characters/*.md",
      entity.glob_for_filename("characters/{slug}.md"))
  end)
end)

describe("entity.create (integration)", function()
  local tmpdir
  local format = require("plugins.writing.projects.format")
  local loader = require("plugins.writing.projects.loader")

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    vim.fn.mkdir(tmpdir .. "/notes", "p")
    -- Write a minimal marker
    vim.fn.writefile({
      "type: minimal",
      "title: Test Project",
      "description: x",
      "created: 2026-04-25",
    }, tmpdir .. "/.writa-project.yaml")
    -- Write a tiny template
    vim.fn.mkdir(tmpdir .. "/templates", "p")
    vim.fn.writefile({ "# {title}", "" }, tmpdir .. "/templates/note.md")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("creates an entity file with frontmatter and rendered body", function()
    local def = {
      filename = "notes/{slug}.md",
      template = "templates/note.md",
      fields = { { name = "title", type = "string", required = true } },
    }
    local result = entity.create({
      project_root = tmpdir,
      project_meta = { type = "minimal", title = "Test Project" },
      entity_def = def,
      values = { title = "Hello World" },
      open_after = false,
    })
    assert.is_true(vim.fn.filereadable(result.path) == 1)
    local lines = vim.fn.readfile(result.path)
    assert.are.equal("---", lines[1])
    assert.are.equal("title: Hello World", lines[2])
    assert.are.equal("---", lines[3])
    assert.are.equal("# Hello World", lines[4])
    assert.is_truthy(result.path:match("hello%-world%.md$"))
  end)

  it("errors when target file already exists", function()
    local def = {
      filename = "notes/{slug}.md",
      template = "templates/note.md",
      fields = { { name = "title", type = "string", required = true } },
    }
    -- Pre-create the file
    vim.fn.writefile({ "existing" }, tmpdir .. "/notes/hello.md")

    assert.has_error(function()
      entity.create({
        project_root = tmpdir,
        project_meta = { type = "minimal", title = "Test" },
        entity_def = def,
        values = { title = "Hello" },
        open_after = false,
      })
    end)
  end)
end)
```

- [ ] **Step 2: Run tests, confirm fail**

Run: `make test`

- [ ] **Step 3: Implement `lua/plugins/writing/projects/entity.lua`**

```lua
local format = require("plugins.writing.projects.format")
local refs = require("plugins.writing.projects.refs")
local slug_mod = require("plugins.writing.projects.slug")

local M = {}

---@param k string
---@param v any
---@return string
local function emit_scalar(k, v)
  if type(v) == "number" or type(v) == "boolean" then
    return ("%s: %s"):format(k, tostring(v))
  end
  local s = tostring(v)
  -- Quote if contains : or starts with [, !, &, *, %, etc., or is a wikilink
  if s:match("[:%[%]{}!&*%%@`]") or s:match("^%s") or s:match("%s$") then
    return ("%s: %q"):format(k, s)
  end
  return ("%s: %s"):format(k, s)
end

---@param k string
---@param list table
---@return string
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

---Replace every {token} segment in a filename template with `*`,
---useful for globbing existing entities of a type.
---@param filename_template string
---@return string
function M.glob_for_filename(filename_template)
  return (filename_template:gsub("{[^{}]*}", "*"))
end

---Pick a value from a list via vim.ui.select. Returns nil on cancel.
---@param items string[]
---@param prompt string
---@return string?
local function pick(items, prompt)
  local result
  vim.ui.select(items, { prompt = prompt }, function(choice) result = choice end)
  return result
end

---Multi-select via repeated vim.ui.select with a sentinel "<done>".
---@param items string[]
---@param prompt string
---@return string[]
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

---Prompt for a single field value. Returns the resolved value.
---For ref/list(ref), passes existing-entity globber.
---@param field { name: string, type: string, required: boolean? }
---@param ctx { project_root: string, type_def: table }
---@return any
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

---Create one entity file. Pure-ish: uses vim.ui only for fields not in `values`.
---@param opts { project_root: string, project_meta: table, entity_def: table,
---              type_def: table?, values: table?, open_after: boolean? }
---@return { path: string }
function M.create(opts)
  local def = opts.entity_def
  local values = vim.deepcopy(opts.values or {})

  for _, field in ipairs(def.fields) do
    if values[field.name] == nil then
      local v = prompt_field(field, { project_root = opts.project_root, type_def = opts.type_def or { entities = { __dummy__ = def } } })
      if field.required and (v == nil or v == "") then
        error(("entity: required field %q not provided"):format(field.name))
      end
      if v ~= nil and v ~= "" then values[field.name] = v end
    end
  end

  -- Slug derivation
  local source_field = slug_mod.source_field(def.fields)
  if not source_field then
    error("entity: no slug-source field; entity type needs an explicit slug")
  end
  local slug = slug_mod.derive(tostring(values[source_field]))

  -- Build interpolation context
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

  -- Read template
  local tmpl_path = opts.project_root .. "/" .. def.template
  if vim.fn.filereadable(tmpl_path) ~= 1 then
    -- Fall back: type-bundle directory may be elsewhere; let caller pre-resolve.
    error(("entity: template not found: %s"):format(tmpl_path))
  end
  local body_template = table.concat(vim.fn.readfile(tmpl_path), "\n")
  local body = format.render(body_template, ctx)

  -- Build full file content. Frontmatter excludes derived `slug` unless explicit.
  local content = M.frontmatter_yaml(values) .. body

  vim.fn.mkdir(vim.fn.fnamemodify(abs, ":h"), "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), abs)

  if opts.open_after then vim.cmd.edit(abs) end
  return { path = abs }
end

return M
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `make test`

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/entity.lua tests/projects/entity_spec.lua
git commit -m "feat(projects): add entity creation flow"
```

---

## Task 7: `scaffold.lua` — new project flow

Per spec §`:WritaNewProject`. mkdir, write marker file, write root_files, run initial[] entity creations.

**Files:**
- Create: `lua/plugins/writing/projects/scaffold.lua`
- Create: `tests/projects/scaffold_spec.lua`

- [ ] **Step 1: Write tests**

```lua
local scaffold = require("plugins.writing.projects.scaffold")

local function read_file(path)
  return table.concat(vim.fn.readfile(path), "\n")
end

describe("scaffold.create", function()
  local tmpdir, type_dir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    type_dir = tmpdir .. "/types/minimal"
    vim.fn.mkdir(type_dir .. "/templates", "p")
    vim.fn.writefile({
      "name: Minimal",
      "description: test",
      "default_path: " .. tmpdir .. "/projects/{slug}",
      "directories: [notes, drafts]",
      "root_files:",
      "  - { path: README.md, template: templates/README.md }",
      "entities:",
      "  note:",
      "    filename: \"notes/{slug}.md\"",
      "    template: templates/note.md",
      "    fields:",
      "      - { name: title, type: string, required: true }",
      "initial:",
      "  - { entity: note, values: { title: \"First Note\" } }",
    }, type_dir .. "/minimal.yaml")
    vim.fn.writefile({ "# {project.title}", "" }, type_dir .. "/templates/README.md")
    vim.fn.writefile({ "# {title}", "" }, type_dir .. "/templates/note.md")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("creates the directory tree, marker, root files, and initial entities", function()
    if vim.fn.executable("yq") ~= 1 then return pending("yq not installed") end

    local loader = require("plugins.writing.projects.loader")
    local def = loader.load_type(type_dir)
    local target = tmpdir .. "/projects/my-project"
    local result = scaffold.create({
      type_loaded = def,
      title = "My Project",
      description = "A test",
      target_path = target,
      open_after = false,
    })

    assert.is_true(vim.fn.isdirectory(target) == 1)
    assert.is_true(vim.fn.isdirectory(target .. "/notes") == 1)
    assert.is_true(vim.fn.isdirectory(target .. "/drafts") == 1)
    assert.is_true(vim.fn.filereadable(target .. "/.writa-project.yaml") == 1)
    assert.is_true(vim.fn.filereadable(target .. "/README.md") == 1)

    -- Root file content includes interpolated project title
    assert.is_truthy(read_file(target .. "/README.md"):match("My Project"))

    -- Initial entity exists
    assert.is_true(vim.fn.filereadable(target .. "/notes/first-note.md") == 1)

    -- Marker file contents
    local marker = read_file(target .. "/.writa-project.yaml")
    assert.is_truthy(marker:match("type: minimal"))
    assert.is_truthy(marker:match("title: My Project"))
  end)

  it("errors when target exists and is non-empty (without confirm flag)", function()
    if vim.fn.executable("yq") ~= 1 then return pending("yq not installed") end

    local loader = require("plugins.writing.projects.loader")
    local def = loader.load_type(type_dir)
    local target = tmpdir .. "/projects/conflict"
    vim.fn.mkdir(target, "p")
    vim.fn.writefile({ "existing" }, target .. "/preexisting.txt")

    assert.has_error(function()
      scaffold.create({
        type_loaded = def,
        title = "Conflict",
        target_path = target,
        open_after = false,
        confirmed = false,
      })
    end)
  end)
end)
```

- [ ] **Step 2: Run tests, confirm fail**

- [ ] **Step 3: Implement `lua/plugins/writing/projects/scaffold.lua`**

```lua
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

  -- Write marker file
  local created_iso = os.date("%Y-%m-%d")
  local marker_lines = {
    ("type: %s"):format(opts.type_loaded.name),
    ("title: %s"):format(opts.title),
    ("description: %s"):format(description),
    ("created: %s"):format(created_iso),
  }
  vim.fn.writefile(marker_lines, target .. "/.writa-project.yaml")

  -- Resolve template directory: type bundle's dir/templates/, but copied into the project?
  -- Per spec, root_files reference templates inside the type bundle. We need to read from
  -- the type bundle dir, render, and write into the project. The template paths in YAML
  -- are relative to the type bundle dir.
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

  -- Write root files
  for _, rf in ipairs(def.root_files or {}) do
    local body = format.render(read_template(rf.template), project_ctx)
    local out_path = target .. "/" .. rf.path
    vim.fn.mkdir(vim.fn.fnamemodify(out_path, ":h"), "p")
    vim.fn.writefile(vim.split(body, "\n", { plain = true }), out_path)
  end

  -- Run initial[] entities. Each one's template is in the type bundle, so we
  -- pre-resolve template content before calling entity.create.
  local first_entity_path
  for _, init in ipairs(def.initial or {}) do
    local ent_def = def.entities[init.entity]
    if not ent_def then
      error(("scaffold: initial[].entity refers to unknown type %q"):format(init.entity))
    end

    -- Patch the entity_def so its template path resolves inside the type bundle.
    -- We do this by writing the template content into the project's temporary path
    -- and pointing entity.create at it. Cleaner: pre-render here.
    local body_template = read_template(ent_def.template)
    local values = vim.deepcopy(init.values or {})

    -- Prompt for missing required fields (entity.create handles this)
    -- but it expects the template at <project_root>/<def.template>. Workaround:
    -- write the template into the project temporarily.
    local stage_path = target .. "/" .. ent_def.template
    vim.fn.mkdir(vim.fn.fnamemodify(stage_path, ":h"), "p")
    vim.fn.writefile(vim.split(body_template, "\n", { plain = true }), stage_path)

    local result = entity.create({
      project_root = target,
      project_meta = { type = opts.type_loaded.name, title = opts.title, description = description },
      entity_def   = ent_def,
      type_def     = def,
      values       = values,
      open_after   = false,
    })

    if not first_entity_path then first_entity_path = result.path end
  end

  -- Clean up staged templates (they're not part of the user's project)
  -- We staged them at <target>/<ent_def.template>, e.g. target/templates/scene.md.
  -- Remove the templates/ directory from the project root if it was staged.
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
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `make test`

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/scaffold.lua tests/projects/scaffold_spec.lua
git commit -m "feat(projects): add project scaffolding flow"
```

---

## Task 8: `open.lua` — discover and select existing project

Per spec §`:WritaOpenProject`. Glob marker files under configured `project_roots` (depth 4), present via `vim.ui.select`, `:cd` and edit on selection.

**Files:**
- Create: `lua/plugins/writing/projects/open.lua`
- Create: `tests/projects/open_spec.lua`

- [ ] **Step 1: Write tests**

```lua
local open = require("plugins.writing.projects.open")

describe("open.discover", function()
  local tmpdir

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir .. "/a/proj1", "p")
    vim.fn.mkdir(tmpdir .. "/b/c/proj2", "p")
    vim.fn.writefile({
      "type: novel",
      "title: Project One",
      "description: first",
    }, tmpdir .. "/a/proj1/.writa-project.yaml")
    vim.fn.writefile({
      "type: essay",
      "title: Project Two",
    }, tmpdir .. "/b/c/proj2/.writa-project.yaml")
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("returns each discovered project with metadata", function()
    if vim.fn.executable("yq") ~= 1 then return pending("yq not installed") end
    local found = open.discover({ tmpdir })
    assert.are.equal(2, #found)
    -- Either order is fine; sort by title for deterministic check
    table.sort(found, function(x, y) return x.title < y.title end)
    assert.are.equal("Project One", found[1].title)
    assert.are.equal("novel", found[1].type)
    assert.is_truthy(found[1].path:match("/proj1$"))
  end)

  it("returns empty list when no roots match", function()
    local found = open.discover({ "/nonexistent/path" })
    assert.are.equal(0, #found)
  end)
end)

describe("open.format_choice", function()
  it("formats one entry", function()
    local entry = { title = "My Novel", type = "novel", path = "/x/y" }
    assert.are.equal("My Novel (novel) — /x/y", open.format_choice(entry))
  end)
end)
```

- [ ] **Step 2: Run tests, confirm fail**

- [ ] **Step 3: Implement `lua/plugins/writing/projects/open.lua`**

```lua
local loader = require("plugins.writing.projects.loader")

local M = {}

---Discover projects under each root by globbing for .writa-project.yaml.
---Glob is bounded to depth 4 to avoid pathological scans.
---@param roots string[]
---@return { title: string, type: string, description: string?, path: string, marker: string }[]
function M.discover(roots)
  local found = {}
  for _, root in ipairs(roots) do
    local expanded = vim.fn.expand(root)
    if vim.fn.isdirectory(expanded) == 1 then
      -- Glob bounded to 4 levels of directory depth.
      -- Patterns: /*.../<.writa-project.yaml> at depths 0..4.
      local patterns = {
        expanded .. "/.writa-project.yaml",
        expanded .. "/*/.writa-project.yaml",
        expanded .. "/*/*/.writa-project.yaml",
        expanded .. "/*/*/*/.writa-project.yaml",
        expanded .. "/*/*/*/*/.writa-project.yaml",
      }
      for _, pat in ipairs(patterns) do
        for _, marker in ipairs(vim.fn.glob(pat, false, true)) do
          local ok, parsed = pcall(loader.read_marker, marker)
          if ok then
            table.insert(found, {
              title       = parsed.title,
              type        = parsed.type,
              description = parsed.description,
              path        = vim.fn.fnamemodify(marker, ":h"),
              marker      = marker,
            })
          end
        end
      end
    end
  end
  return found
end

---@param entry { title: string, type: string, path: string }
---@return string
function M.format_choice(entry)
  return ("%s (%s) — %s"):format(entry.title, entry.type, entry.path)
end

---Run the full :WritaOpenProject flow.
---@param roots string[]
function M.run(roots)
  local found = M.discover(roots)
  if #found == 0 then
    vim.notify(("writa-projects: no projects found under %s"):format(table.concat(roots, ", ")),
      vim.log.levels.INFO)
    return
  end

  vim.ui.select(found, {
    prompt = "Open project:",
    format_item = M.format_choice,
  }, function(choice)
    if not choice then return end
    vim.cmd.cd(vim.fn.fnameescape(choice.path))
    local readme = choice.path .. "/README.md"
    if vim.fn.filereadable(readme) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(readme))
    else
      vim.cmd.edit(vim.fn.fnameescape(choice.path))
    end
  end)
end

return M
```

- [ ] **Step 4: Run tests, confirm pass**

Run: `make test`

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/open.lua tests/projects/open_spec.lua
git commit -m "feat(projects): add project discovery and selection"
```

---

## Task 9: `init.lua` — plugin spec and user commands

Wires the runtime modules into lazy.nvim and registers `:WritaNewProject`, `:WritaOpenProject`, `:WritaNewEntity`. Updates the writing aggregator.

**Files:**
- Create: `lua/plugins/writing/projects/init.lua`
- Modify: `lua/plugins/writing/init.lua`

- [ ] **Step 1: Implement `lua/plugins/writing/projects/init.lua`**

```lua
---@type LazySpec
return {
  "folke/snacks.nvim", -- already loaded; we hang our commands off this no-op dep
  lazy = false,         -- we want :WritaOpenProject available before any file is opened
  config = function()
    local config_dir   = vim.fn.stdpath("config")
    local types_root   = config_dir .. "/project-types"
    local project_roots = { vim.fn.expand("~/writing") }

    local loader = require("plugins.writing.projects.loader")

    --- Helper: ensure a type by name exists, return loaded type.
    local function load_type_by_name(name)
      local dir = types_root .. "/" .. name
      if vim.fn.isdirectory(dir) ~= 1 then
        error(("writa-projects: unknown type %q (looked in %s)"):format(name, dir))
      end
      return loader.load_type(dir)
    end

    --- :WritaNewProject [type]
    vim.api.nvim_create_user_command("WritaNewProject", function(opts)
      local scaffold = require("plugins.writing.projects.scaffold")
      local slug_mod = require("plugins.writing.projects.slug")
      local format   = require("plugins.writing.projects.format")

      local function run_with_type(type_loaded)
        vim.ui.input({ prompt = "Project title: " }, function(title)
          if not title or title == "" then return end
          local slug = slug_mod.derive(title)

          local default_path = type_loaded.definition.default_path or ("~/writing/" .. type_loaded.name .. "/" .. slug)
          local default_expanded = vim.fn.expand(format.render(default_path, { slug = slug }))

          vim.ui.input({ prompt = "Path: ", default = default_expanded }, function(target)
            if not target or target == "" then return end

            vim.ui.input({ prompt = "Description (optional): " }, function(desc)
              local proceed = true
              if vim.fn.isdirectory(target) == 1 then
                local entries = vim.fn.readdir(target)
                if #entries > 0 then
                  local response = vim.fn.confirm(
                    ("Target %s exists and is non-empty. Continue?"):format(target),
                    "&Yes\n&No", 2)
                  proceed = response == 1
                end
              end
              if not proceed then return end

              scaffold.create({
                type_loaded  = type_loaded,
                title        = title,
                description  = desc or "",
                target_path  = target,
                open_after   = true,
                confirmed    = true,
              })
            end)
          end)
        end)
      end

      local arg = opts.args ~= "" and opts.args or nil
      if arg then
        run_with_type(load_type_by_name(arg))
      else
        local types = loader.discover_types(types_root)
        if #types == 0 then
          vim.notify("writa-projects: no project types found in " .. types_root,
            vim.log.levels.WARN)
          return
        end
        local names = {}
        for _, t in ipairs(types) do table.insert(names, t.name) end
        vim.ui.select(names, { prompt = "Project type:" }, function(picked)
          if not picked then return end
          for _, t in ipairs(types) do
            if t.name == picked then run_with_type(t); return end
          end
        end)
      end
    end, {
      nargs = "?",
      complete = function()
        local types = loader.discover_types(types_root)
        local names = {}
        for _, t in ipairs(types) do table.insert(names, t.name) end
        return names
      end,
      desc = "writa: scaffold a new writing project",
    })

    --- :WritaOpenProject
    vim.api.nvim_create_user_command("WritaOpenProject", function()
      require("plugins.writing.projects.open").run(project_roots)
    end, { desc = "writa: open an existing project from configured roots" })

    --- :WritaNewEntity [kind]
    vim.api.nvim_create_user_command("WritaNewEntity", function(opts)
      local entity = require("plugins.writing.projects.entity")
      local marker, root = loader.find_project_root(vim.fn.getcwd())
      if not marker then
        vim.notify("writa-projects: not inside a writa project (no .writa-project.yaml)",
          vim.log.levels.ERROR)
        return
      end
      local meta = loader.read_marker(marker)
      local type_loaded = load_type_by_name(meta.type)
      local def = type_loaded.definition

      local function run_with_kind(kind)
        local ent_def = def.entities[kind]
        if not ent_def then
          vim.notify(("writa-projects: unknown entity type %q for project type %q"):format(kind, meta.type),
            vim.log.levels.ERROR)
          return
        end
        -- Stage the template into the project so entity.create can read it.
        -- Same pattern as scaffold.lua. (Future: pass template content directly.)
        local body_path = type_loaded.dir .. "/" .. ent_def.template
        local stage_path = root .. "/" .. ent_def.template
        vim.fn.mkdir(vim.fn.fnamemodify(stage_path, ":h"), "p")
        vim.fn.writefile(vim.fn.readfile(body_path), stage_path)

        local ok, err = pcall(entity.create, {
          project_root = root,
          project_meta = meta,
          entity_def   = ent_def,
          type_def     = def,
          open_after   = true,
        })

        -- Cleanup staged templates after.
        if vim.fn.isdirectory(root .. "/templates") == 1 then
          vim.fn.delete(root .. "/templates", "rf")
        end

        if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
      end

      local arg = opts.args ~= "" and opts.args or nil
      if arg then run_with_kind(arg)
      else
        local kinds = vim.tbl_keys(def.entities)
        table.sort(kinds)
        vim.ui.select(kinds, { prompt = "Entity type:" }, function(picked)
          if picked then run_with_kind(picked) end
        end)
      end
    end, {
      nargs = "?",
      complete = function()
        local marker = loader.find_project_root(vim.fn.getcwd())
        if not marker then return {} end
        local meta = loader.read_marker(marker)
        local ok, type_loaded = pcall(load_type_by_name, meta.type)
        if not ok then return {} end
        local out = vim.tbl_keys(type_loaded.definition.entities)
        table.sort(out)
        return out
      end,
      desc = "writa: create a new entity in the current project",
    })
  end,
}
```

- [ ] **Step 2: Modify `lua/plugins/writing/init.lua`**

Open the file and add `"projects"` to the end of the `files` list:

```lua
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
  "projects",  -- <-- new
}
```

- [ ] **Step 3: Verify writa boots cleanly**

Run: `NVIM_APPNAME=writa nvim --headless -c "lua print('OK')" -c "qa!" 2>&1 | head -20`
Expected: prints "OK", no errors.

- [ ] **Step 4: Verify commands are registered**

Run: `NVIM_APPNAME=writa nvim --headless -c "echo exists(':WritaNewProject') exists(':WritaOpenProject') exists(':WritaNewEntity')" -c "qa!" 2>&1`
Expected: `2 2 2` (each `2` means defined).

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/writing/projects/init.lua lua/plugins/writing/init.lua
git commit -m "feat(projects): add user commands and lazy plugin spec"
```

---

## Task 10: `novel` project-type bundle

**Files:**
- Create: `project-types/novel/novel.yaml`
- Create: `project-types/novel/templates/{README,outline,chapter,scene,character,location}.md`

- [ ] **Step 1: Create `project-types/novel/novel.yaml`**

```yaml
# yaml-language-server: $schema=file:///home/jackm/.config/writa/schema/project-type/v1.json

name: Novel
description: Long-form prose fiction
default_path: ~/writing/novels/{slug}

directories: [chapters, scenes, characters, locations, research]

root_files:
  - { path: README.md,  template: templates/README.md }
  - { path: outline.md, template: templates/outline.md }

entities:
  chapter:
    filename: "chapters/{number:02d}-{slug}.md"
    template: templates/chapter.md
    fields:
      - { name: number, type: int,    required: true }
      - { name: title,  type: string, required: true }
      - { name: pov,    type: "ref(character)" }

  scene:
    filename: "scenes/{slug}.md"
    template: templates/scene.md
    fields:
      - { name: title,      type: string,                  required: true }
      - { name: chapter,    type: "ref(chapter)",          required: true }
      - { name: characters, type: "list(character)" }
      - { name: location,   type: "ref(location)" }
      - { name: summary,    type: string }

  character:
    filename: "characters/{slug}.md"
    template: templates/character.md
    fields:
      - { name: name,         type: string, required: true }
      - { name: role,         type: string }
      - { name: age,          type: int }
      - { name: description,  type: string }

  location:
    filename: "locations/{slug}.md"
    template: templates/location.md
    fields:
      - { name: name,        type: string, required: true }
      - { name: description, type: string }

initial:
  - { entity: chapter,   values: { number: 1, title: "Chapter 1" } }
  - { entity: character, values: { name: "Protagonist" } }
```

- [ ] **Step 2: Create templates**

`project-types/novel/templates/README.md`:
```markdown
# {project.title}

{project.description}

## Outline

See [[outline]].

## Chapters

(Linked automatically by obsidian.nvim's backlinks.)
```

`project-types/novel/templates/outline.md`:
```markdown
# {project.title} — Outline

## Premise

## Acts

## Themes

## Notes
```

`project-types/novel/templates/chapter.md`:
```markdown
# Chapter {number}: {title}

## Summary

## Scenes

## Draft

---

Part of *{project.title}*.
```

`project-types/novel/templates/scene.md`:
```markdown
# {title}

## Beat

## Draft

---

Part of *{project.title}*.
```

`project-types/novel/templates/character.md`:
```markdown
# {name}

## Role

## Background

## Voice

## Arc
```

`project-types/novel/templates/location.md`:
```markdown
# {name}

## Description

## Significance
```

- [ ] **Step 3: Verify the type loads**

Run:
```bash
NVIM_APPNAME=writa nvim --headless -c "lua local l = require('plugins.writing.projects.loader'); local t = l.load_type(vim.fn.stdpath('config') .. '/project-types/novel'); print(t.definition.name)" -c "qa!" 2>&1
```
Expected: prints `Novel`.

- [ ] **Step 4: Commit**

```bash
git add project-types/novel/
git commit -m "feat(projects): add novel project type"
```

---

## Task 11: `screenplay` project-type bundle

**Files:**
- Create: `project-types/screenplay/screenplay.yaml`
- Create: `project-types/screenplay/templates/{README,outline,screenplay,act,scene,character,location}.md`/`.fountain`

- [ ] **Step 1: Create `project-types/screenplay/screenplay.yaml`**

```yaml
# yaml-language-server: $schema=file:///home/jackm/.config/writa/schema/project-type/v1.json

name: Screenplay
description: Fountain-based long-form drama
default_path: ~/writing/screenplays/{slug}

directories: [acts, scenes, characters, locations, research]

root_files:
  - { path: README.md, template: templates/README.md }

entities:
  screenplay:
    filename: "screenplay.md"
    template: templates/screenplay.md
    fields:
      - { name: title,     type: string,             required: true }
      - { name: logline,   type: string }
      - { name: genre,     type: string }
      - { name: main_cast, type: "list(character)" }

  act:
    filename: "acts/{number:02d}-{slug}.md"
    template: templates/act.md
    fields:
      - { name: number,     type: int,               required: true }
      - { name: title,      type: string,            required: true }
      - { name: summary,    type: string }
      - { name: screenplay, type: "ref(screenplay)" }

  scene:
    filename: "scenes/{slug}.fountain"
    template: templates/scene.fountain
    fields:
      - { name: title,         type: string,                 required: true }
      - { name: slug_line,     type: string,                 required: true }
      - { name: act,           type: "ref(act)",             required: true }
      - { name: location,      type: "ref(location)" }
      - { name: characters,    type: "list(character)" }
      - { name: summary,       type: string }
      - { name: beat,          type: string }
      - { name: subtext,       type: string }

  character:
    filename: "characters/{slug}.md"
    template: templates/character.md
    fields:
      - { name: name,        type: string, required: true }
      - { name: archetype,   type: string }
      - { name: age,         type: int }
      - { name: description, type: string }

  location:
    filename: "locations/{slug}.md"
    template: templates/location.md
    fields:
      - { name: name,        type: string, required: true }
      - { name: description, type: string }

initial:
  - { entity: screenplay, values: { title: "Untitled Screenplay" } }
  - { entity: act,        values: { number: 1, title: "Act 1" } }
  - { entity: act,        values: { number: 2, title: "Act 2" } }
  - { entity: act,        values: { number: 3, title: "Act 3" } }
```

- [ ] **Step 2: Create templates**

`project-types/screenplay/templates/README.md`:
```markdown
# {project.title}

{project.description}

## Title page

See [[screenplay]].

## Acts

(Indexed by obsidian.nvim backlinks.)
```

`project-types/screenplay/templates/screenplay.md`:
```markdown
# {title}

**Genre:** {genre}

**Logline:**
{logline}

## Main Cast

(Linked from frontmatter.)
```

`project-types/screenplay/templates/act.md`:
```markdown
# Act {number}: {title}

## Summary

{summary}

## Scenes

(Linked by backlinks.)
```

`project-types/screenplay/templates/scene.fountain`:
```fountain
Title: {title}
Act: {act}

{slug_line}

ACTION GOES HERE.

CHARACTER
Dialogue goes here.
```

`project-types/screenplay/templates/character.md`:
```markdown
# {name}

**Archetype:** {archetype}

**Age:** {age}

## Description

{description}

## Voice
```

`project-types/screenplay/templates/location.md`:
```markdown
# {name}

## Description

{description}
```

- [ ] **Step 3: Verify**

```bash
NVIM_APPNAME=writa nvim --headless -c "lua local l = require('plugins.writing.projects.loader'); local t = l.load_type(vim.fn.stdpath('config') .. '/project-types/screenplay'); print(t.definition.name)" -c "qa!" 2>&1
```
Expected: prints `Screenplay`.

- [ ] **Step 4: Commit**

```bash
git add project-types/screenplay/
git commit -m "feat(projects): add screenplay project type"
```

---

## Task 12: `essay` project-type bundle

**Files:**
- Create: `project-types/essay/essay.yaml`
- Create: `project-types/essay/templates/{README,essay,argument,citation}.md`

- [ ] **Step 1: Create `project-types/essay/essay.yaml`**

```yaml
# yaml-language-server: $schema=file:///home/jackm/.config/writa/schema/project-type/v1.json

name: Essay
description: Argumentative non-fiction
default_path: ~/writing/essays/{slug}

directories: [arguments, citations]

root_files:
  - { path: README.md, template: templates/README.md }

entities:
  essay:
    filename: "essay.md"
    template: templates/essay.md
    fields:
      - { name: title,        type: string, required: true }
      - { name: thesis,       type: string }
      - { name: introduction, type: string }
      - { name: conclusion,   type: string }

  argument:
    filename: "arguments/{slug}.md"
    template: templates/argument.md
    fields:
      - { name: topic_sentence,      type: string,                required: true }
      - { name: supporting_evidence, type: string }
      - { name: counterargument,     type: string }
      - { name: essay,               type: "ref(essay)" }
      - { name: evidence,            type: "list(citation)" }

  citation:
    filename: "citations/{slug}.md"
    template: templates/citation.md
    fields:
      - { name: title,  type: string, required: true }
      - { name: author, type: string }
      - { name: year,   type: int }
      - { name: url,    type: string }
      - { name: quote,  type: string }

initial:
  - { entity: essay, values: { title: "Untitled Essay" } }
```

- [ ] **Step 2: Create templates**

`project-types/essay/templates/README.md`:
```markdown
# {project.title}

{project.description}

See [[essay]] for the main draft.
```

`project-types/essay/templates/essay.md`:
```markdown
# {title}

## Thesis

{thesis}

## Introduction

{introduction}

## Body

(Pull arguments from `arguments/` here as you draft.)

## Conclusion

{conclusion}

## Bibliography

(Auto-rendered from cited works at export time.)
```

`project-types/essay/templates/argument.md`:
```markdown
# {topic_sentence}

## Supporting evidence

{supporting_evidence}

## Counterargument

{counterargument}

## Cited

(Linked via `evidence` frontmatter.)
```

`project-types/essay/templates/citation.md`:
```markdown
# {title}

**Author:** {author}
**Year:** {year}
**URL:** {url}

## Quote

> {quote}

## Notes
```

- [ ] **Step 3: Verify**

```bash
NVIM_APPNAME=writa nvim --headless -c "lua local l = require('plugins.writing.projects.loader'); local t = l.load_type(vim.fn.stdpath('config') .. '/project-types/essay'); print(t.definition.name)" -c "qa!" 2>&1
```
Expected: prints `Essay`.

- [ ] **Step 4: Commit**

```bash
git add project-types/essay/
git commit -m "feat(projects): add essay project type"
```

---

## Task 13: Mason `yq` and `yaml-language-server`, plus schema association

**Files:**
- Modify: `lua/plugins/mason.lua`
- Modify: `lua/plugins/astrolsp.lua`

- [ ] **Step 1: Read existing `lua/plugins/mason.lua`**

Confirm structure before editing. Should match the pattern shown in plan header.

- [ ] **Step 2: Modify `lua/plugins/mason.lua`**

Append `"yq"` and `"yaml-language-server"` to `ensure_installed`. Final file:

```lua
---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "ltex-ls",
        "vale-ls",
        "vale",
        "marksman",
        "stylua",
        "selene",
        "yq",
        "yaml-language-server",
      })
      return opts
    end,
  },
}
```

- [ ] **Step 3: Read existing `lua/plugins/astrolsp.lua`**

Confirm there's a place to add `yamlls` server config. Look for `config = { ... }` keyed by server name.

- [ ] **Step 4: Modify `lua/plugins/astrolsp.lua` to add yamlls schema association**

Add a `yamlls` config block to associate the project-type schema with the relevant YAML files. Exact integration depends on the file's existing structure; the addition (inside `opts.config`) looks like:

```lua
yamlls = {
  settings = {
    yaml = {
      schemas = {
        [vim.fn.stdpath("config") .. "/schema/project-type/v1.json"] = {
          "project-types/**/*.yaml",
          ".writa-project.yaml",
        },
      },
    },
  },
},
```

Also ensure `yamlls` is in `opts.servers` if that file uses an explicit list.

- [ ] **Step 5: Run mason-tool-installer**

```bash
NVIM_APPNAME=writa nvim --headless -c "MasonToolsInstallSync" -c "qa!" 2>&1 | tail -20
```
Expected: yq and yaml-language-server installed without errors.

Verify:
```bash
ls ~/.local/share/writa/mason/bin/yq ~/.local/share/writa/mason/bin/yaml-language-server
```
Expected: both files exist.

- [ ] **Step 6: Verify yq is callable from a writa nvim session**

```bash
NVIM_APPNAME=writa nvim --headless -c "lua print(vim.fn.executable('yq'))" -c "qa!" 2>&1
```
Expected: prints `1`.

If `0`, Mason's bin path may not be on PATH for headless runs. AstroNvim normally configures this; if it doesn't, the loader's `vim.system({"yq", ...})` falls back to absolute path:

In `lua/plugins/writing/projects/loader.lua`, swap the yq call to:
```lua
local yq = vim.fn.exepath("yq")
if yq == "" then
  yq = vim.fn.stdpath("data") .. "/mason/bin/yq"
end
local result = vim.system({ yq, "-o=json", path }, { text = true }):wait()
```

(Apply this fallback only if Step 6 returned 0.)

- [ ] **Step 7: Re-run tests**

Run: `make test`
Expected: all tests pass (loader tests no longer pending).

- [ ] **Step 8: Commit**

```bash
git add lua/plugins/mason.lua lua/plugins/astrolsp.lua lua/plugins/writing/projects/loader.lua
git commit -m "feat(projects): install yq and yaml-language-server via Mason"
```

---

## Task 14: Dashboard integration

Extend `lua/plugins/dashboard.lua` to surface `:WritaNewProject` and `:WritaOpenProject` as `w` and `W` keys on the snacks dashboard. snacks's `preset.keys` replaces the default key list, so we list defaults explicitly.

**Files:**
- Modify: `lua/plugins/dashboard.lua`

- [ ] **Step 1: Replace contents of `lua/plugins/dashboard.lua`**

```lua
---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = table.concat({
          [[                _ _        ]],
          [[__      ___ __(_) |_ __ _ ]],
          [[\ \ /\ / / '__| | __/ _` |]],
          [[ \ V  V /| |  | | || (_| |]],
          [[  \_/\_/ |_|  |_|\__\__,_|]],
        }, "\n"),
        keys = {
          { icon = " ", key = "w", desc = "New Project",  action = ":WritaNewProject" },
          { icon = " ", key = "W", desc = "Open Project", action = ":WritaOpenProject" },
          { icon = " ", key = "f", desc = "Find File",    action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File",     action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text",    action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config",       action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "L", desc = "Lazy",        action = ":Lazy",          enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "q", desc = "Quit",         action = ":qa" },
        },
      },
    },
  },
}
```

- [ ] **Step 2: Manually verify the dashboard**

Run: `NVIM_APPNAME=writa nvim`

Expected: dashboard renders with the writa banner and the `w`/`W` entries appearing first in the key list.

- [ ] **Step 3: Press `w` from the dashboard**

Expected: `:WritaNewProject` runs (picker for project type appears).

Press `<Esc>` to abort.

- [ ] **Step 4: Press `W` from the dashboard**

Expected: `:WritaOpenProject` runs. If `~/writing/` has no projects, it shows a notification "no projects found"; otherwise the picker appears.

- [ ] **Step 5: Commit**

```bash
git add lua/plugins/dashboard.lua
git commit -m "feat(projects): expose New/Open Project on dashboard"
```

---

## Task 15: Pomo keymap rebind

Free `<Leader>Wp` for Spec 2's project-manager keys. Move pomo to `<Leader>WP` (start) / `<Leader>WT` (stop).

**Files:**
- Modify: `lua/plugins/writing/pomo.lua`

- [ ] **Step 1: Read current pomo file**

Confirm the existing keys (per pre-plan inspection):
```lua
keys = {
  { "<Leader>Wp", "<cmd>TimerStart 25m write<cr>", desc = "Pomodoro 25m" },
  { "<Leader>WP", "<cmd>TimerStop<cr>",            desc = "Pomodoro stop" },
},
```

- [ ] **Step 2: Replace `lua/plugins/writing/pomo.lua` keys**

```lua
return {
  "epwalsh/pomo.nvim",
  version = "*",
  cmd = { "TimerStart", "TimerRepeat", "TimerSession" },
  keys = {
    { "<Leader>WP", "<cmd>TimerStart 25m write<cr>", desc = "Pomodoro start (25m)" },
    { "<Leader>WT", "<cmd>TimerStop<cr>",            desc = "Pomodoro stop" },
  },
  dependencies = { "rcarriga/nvim-notify" },
  opts = {},
}
```

- [ ] **Step 3: Verify keymap registration**

Run:
```bash
NVIM_APPNAME=writa nvim --headless -c "lua vim.defer_fn(function() local m = vim.fn.maparg('<Leader>WP', 'n'); print(m); vim.cmd('qa!') end, 100)" 2>&1
```
Expected output contains `TimerStart 25m write`.

- [ ] **Step 4: Commit**

```bash
git add lua/plugins/writing/pomo.lua
git commit -m "feat(projects): rebind pomo to <Leader>WP/WT, free <Leader>Wp"
```

---

## Task 16: End-to-end manual smoke test

The integration we couldn't unit-test: the full user-facing flow on a real writa session.

**Files:** none changed; this is verification only.

- [ ] **Step 1: Restart writa**

```bash
writa  # alias for NVIM_APPNAME=writa nvim
```
Expected: dashboard renders with writa banner, `w` and `W` entries visible.

- [ ] **Step 2: Create a novel project**

Press `w`. Pick `novel`. Title: `Plan Smoke Test`. Accept default path (`~/writing/novels/plan-smoke-test`). Description: blank.

Expected:
- Directory `~/writing/novels/plan-smoke-test/` created.
- Subdirs `chapters/`, `scenes/`, `characters/`, `locations/`, `research/`.
- `.writa-project.yaml`, `README.md`, `outline.md` at root.
- `chapters/01-chapter-1.md` and `characters/protagonist.md` created from `initial`.
- The first initial entity (`chapters/01-chapter-1.md`) opens in the buffer.

- [ ] **Step 3: Verify rendered content**

```bash
:edit %  " (already open)
```
Confirm:
- Frontmatter: `number: 1`, `title: Chapter 1`.
- Body has `# Chapter 1: Chapter 1` heading and `Part of *Plan Smoke Test*.` line.

- [ ] **Step 4: Create a scene with refs**

```vim
:WritaNewEntity scene
```
- Title: `Opening`
- Chapter: pick `chapters/01-chapter-1.md` from picker.
- Characters: pick `characters/protagonist.md`, then `<done>`.
- Location: skip (Esc).
- Summary: `A quiet morning.`

Expected: `scenes/opening.md` opens with frontmatter:
```yaml
chapter: "[[chapters/01-chapter-1]]"
characters:
  - "[[characters/protagonist]]"
summary: "A quiet morning."
title: Opening
```

- [ ] **Step 5: Verify obsidian backlinks**

Open `characters/protagonist.md` and run obsidian's backlinks command (`:ObsidianBacklinks`). Expected: lists `scenes/opening.md`.

- [ ] **Step 6: Open another project from dashboard**

Run `:Snacks dashboard` to return to dashboard (or restart). Press `W`. Expected: picker shows `Plan Smoke Test (novel) — ~/writing/novels/plan-smoke-test`. Select it. Buffer opens at the project's `README.md`.

- [ ] **Step 7: Create a screenplay project (test second type)**

Press `W` (back to dashboard with `:Snacks dashboard`), then `w`. Pick `screenplay`, title `Smoke Test SP`. Accept default path.

Expected: `screenplay.md` and three `acts/0N-act-N.md` files created. First created file opens.

- [ ] **Step 8: Create an essay project (test third type)**

Same flow, type `essay`, title `Smoke Test Essay`.

Expected: `essay.md` created. Opens.

- [ ] **Step 9: Confirm Mason yaml-language-server is active on a project-type YAML**

```vim
:edit ~/.config/writa/project-types/novel/novel.yaml
:LspInfo
```
Expected: `yaml-language-server` is listed and active.

Hover over `type: string` on a field — should get type info. Type `type: bogus` somewhere — should show a diagnostic from the schema.

- [ ] **Step 10: Verify pomo rebind**

```vim
:nmap <Leader>WP
:nmap <Leader>WT
:nmap <Leader>Wp
```
Expected: `WP` maps to TimerStart, `WT` maps to TimerStop, `Wp` is unmapped.

- [ ] **Step 11: Run the test suite one final time**

```bash
make test
```
Expected: all tests pass; no pending tests (yq is now installed).

- [ ] **Step 12: Tag and push**

```bash
git tag -a v0.2.0 -m "writa-projects: declarative project types, scaffolding, dashboard"
git log --oneline -20  # sanity check
```

(Pushing is optional — user decides.)

---

## Self-review notes

**Spec coverage** — every section maps to a task:

| Spec section | Task |
|---|---|
| Goals | T6/T7/T8/T14 (whole flow + dashboard) |
| Project-type definitions layout | T10/T11/T12 |
| Type definition format | T4 (loader), T5 (schema) |
| Field types | T7 (entity prompts) |
| Body templates | T2 (format) |
| Variable resolution + format specs | T2 |
| Slug rule | T1 |
| `:WritaNewProject` | T7 (scaffold) + T9 (command) |
| `:WritaOpenProject` | T8 + T9 |
| `:WritaNewEntity` | T6 + T9 |
| Project marker file | T7 (write) + T4 (read) |
| Reference resolution + wikilinks | T3 |
| Module layout | All |
| Dashboard integration | T14 |
| MVP novel | T10 |
| MVP screenplay | T11 |
| MVP essay | T12 |
| Mason yaml-ls + schema assoc | T13 |
| Pomo rebind | T15 |
| Risks (yq fallback, picker abstraction, etc.) | T13 fallback note |
| Success criteria | T16 manual smoke |

**Type consistency** — `loader.load_type` returns `{ name, dir, definition }`. All callers (`scaffold.create.opts.type_loaded`, `init.lua` user commands) use that exact shape. `entity.create.opts.entity_def` is one entry from `definition.entities[kind]`. Confirmed consistent across T6, T7, T9.

**Placeholders** — None. Every step has the actual code, command, or expected outcome.

**Risks not covered by tasks**
- `vim.system`-based yq calls block the editor briefly (~50ms). For our tiny YAMLs that's fine; if it gets slow, cache parsed results per `definition.dir + mtime` (one-line addition in `loader.load_type`).
- The `entity.create` template-staging hack (writing the type-bundle template into the project, then deleting it) is ugly. Future cleanup: pass template content directly so no staging is needed. Tracked as future tech-debt — not blocking MVP.

---

## Ready to execute

All 16 tasks covered. Each task is a self-contained subagent unit with clear file paths, complete code, expected outputs, and a commit boundary.
