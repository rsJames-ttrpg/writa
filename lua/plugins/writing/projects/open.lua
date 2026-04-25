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
    vim.notify(
      ("writa-projects: no projects found under %s"):format(table.concat(roots, ", ")),
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
