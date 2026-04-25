local loader = require("plugins.writing.projects.loader")

local FIXTURES = vim.fn.getcwd() .. "/tests/projects/fixtures/types"

local function has_yq()
  local mason_yq = vim.fn.stdpath("data") .. "/mason/bin/yq"
  return vim.fn.executable(mason_yq) == 1 or vim.fn.executable("yq") == 1
end

describe("loader.parse_yaml_file", function()
  it("parses a valid YAML file via yq", function()
    if not has_yq() then return pending("yq not installed") end
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

describe("loader.find_project_root", function()
  it("walks up to find a marker", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/sub/deep", "p")
    vim.fn.writefile({ "type: x", "title: y" }, tmp .. "/.writa-project.yaml")
    local marker, root = loader.find_project_root(tmp .. "/sub/deep")
    assert.is_not_nil(marker)
    assert.is_truthy(marker:match("/%.writa%-project%.yaml$"))
    assert.is_truthy(root and root:sub(-#tmp) == tmp)
    vim.fn.delete(tmp, "rf")
  end)

  it("returns nil when no marker exists in any ancestor", function()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local marker, root = loader.find_project_root(tmp)
    assert.is_nil(marker)
    assert.is_nil(root)
    vim.fn.delete(tmp, "rf")
  end)
end)
