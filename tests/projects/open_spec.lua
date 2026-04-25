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
    if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/yq") ~= 1 then
      return pending("yq not installed")
    end
    local found = open.discover({ tmpdir })
    assert.are.equal(2, #found)
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
