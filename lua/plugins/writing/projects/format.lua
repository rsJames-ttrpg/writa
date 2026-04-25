local M = {}

---Parse a format spec like "02d", "4s", "d", "" into components.
---Returns nil if unsupported.
---@param spec string
---@return { zero_pad: boolean, width: number?, type: string? }?
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
