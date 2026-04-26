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
