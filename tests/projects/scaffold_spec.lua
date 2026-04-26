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
    if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/yq") ~= 1 then
      return pending("yq not installed")
    end

    local loader = require("plugins.writing.projects.loader")
    local def = loader.load_type(type_dir)
    local target = tmpdir .. "/projects/my-project"
    scaffold.create({
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

  it("preserves a title with YAML special characters in the marker file", function()
    if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/yq") ~= 1 then
      return pending("yq not installed")
    end

    local loader = require("plugins.writing.projects.loader")
    local def = loader.load_type(type_dir)
    local target = tmpdir .. "/projects/colon-test"
    scaffold.create({
      type_loaded = def,
      title = "My Book: A Novel",
      description = "First-person story",
      target_path = target,
      open_after = false,
    })

    local marker = loader.read_marker(target .. "/.writa-project.yaml")
    assert.are.equal("My Book: A Novel", marker.title)
    assert.are.equal("First-person story", marker.description)
  end)

  it("errors when target exists and is non-empty (without confirm flag)", function()
    if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/yq") ~= 1 then
      return pending("yq not installed")
    end

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
