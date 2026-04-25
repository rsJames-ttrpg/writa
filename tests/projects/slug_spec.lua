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
