---@type LazySpec
return {
  "folke/snacks.nvim", -- already loaded; we hang our commands off this no-op dep
  lazy = false,         -- we want :WritaOpenProject available before any file is opened
  config = function()
    local config_dir   = vim.fn.stdpath("config")
    local types_root   = config_dir .. "/project-types"
    local project_roots = { vim.fn.expand("~/writing") }

    local loader = require("plugins.writing.projects.loader")

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

          local default_path = type_loaded.definition.default_path
            or ("~/writing/" .. type_loaded.name .. "/" .. slug)
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

              local ok, err = pcall(scaffold.create, {
                type_loaded  = type_loaded,
                title        = title,
                description  = desc or "",
                target_path  = target,
                open_after   = true,
                confirmed    = true,
              })
              if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
            end)
          end)
        end)
      end

      local arg = opts.args ~= "" and opts.args or nil
      if arg then
        local ok, type_loaded = pcall(load_type_by_name, arg)
        if not ok then vim.notify(tostring(type_loaded), vim.log.levels.ERROR); return end
        run_with_type(type_loaded)
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
      local ok_load, type_loaded = pcall(load_type_by_name, meta.type)
      if not ok_load then
        vim.notify(tostring(type_loaded), vim.log.levels.ERROR)
        return
      end
      local def = type_loaded.definition

      local function run_with_kind(kind)
        local ent_def = def.entities[kind]
        if not ent_def then
          vim.notify(
            ("writa-projects: unknown entity type %q for project type %q"):format(kind, meta.type),
            vim.log.levels.ERROR)
          return
        end
        -- Stage the template into the project so entity.create can read it.
        local body_path = type_loaded.dir .. "/" .. ent_def.template
        local stage_path = root .. "/" .. ent_def.template
        vim.fn.mkdir(vim.fn.fnamemodify(stage_path, ":h"), "p")
        vim.fn.writefile(vim.fn.readfile(body_path), stage_path)

        local ok_create, err = pcall(entity.create, {
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

        if not ok_create then vim.notify(tostring(err), vim.log.levels.ERROR) end
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
