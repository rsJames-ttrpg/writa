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
