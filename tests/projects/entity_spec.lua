local entity = require("plugins.writing.projects.entity")

describe("entity.frontmatter_yaml", function()
  it("emits an empty frontmatter when no fields", function()
    assert.are.equal("---\n---\n", entity.frontmatter_yaml({}))
  end)

  it("emits scalar fields", function()
    local fm = entity.frontmatter_yaml({ title = "Opening", number = 1 })
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

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    vim.fn.mkdir(tmpdir .. "/notes", "p")
    vim.fn.writefile({
      "type: minimal",
      "title: Test Project",
      "description: x",
      "created: 2026-04-25",
    }, tmpdir .. "/.writa-project.yaml")
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
