---@type LazySpec
return {
  "folke/snacks.nvim", -- already loaded; we attach via init (additive) so we
  lazy = false,        -- don't replace AstroNvim's snacks config function
  init = function()
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

    --- Continuation-chain prompt walker. Calls `on_done(values)` once all fields
    --- have been resolved. Async-safe: each prompt is a callback in the snacks
    --- (or telescope/dressing) UI, never `vim.wait`.
    local function prompt_fields(fields, idx, values, ctx, on_done)
      if idx > #fields then return on_done(values) end
      local field = fields[idx]
      local refs = require("plugins.writing.projects.refs")
      local entity = require("plugins.writing.projects.entity")

      local function next_field(v)
        if v ~= nil and v ~= "" then values[field.name] = v end
        if field.required and (values[field.name] == nil or values[field.name] == "") then
          vim.notify(("writa-projects: required field %q not provided — aborting"):format(field.name),
            vim.log.levels.ERROR)
          return
        end
        prompt_fields(fields, idx + 1, values, ctx, on_done)
      end

      if field.type == "string" then
        local prompt = field.name .. (field.required and " (required): " or ": ")
        vim.ui.input({ prompt = prompt }, next_field)
        return
      end

      if field.type == "int" then
        vim.ui.input({ prompt = field.name .. ": " }, function(raw)
          if raw == nil or raw == "" then return next_field(nil) end
          local n = tonumber(raw)
          if not n then
            vim.notify(("writa-projects: %q expected int, got %q"):format(field.name, raw),
              vim.log.levels.ERROR)
            return
          end
          next_field(n)
        end)
        return
      end

      if field.type == "list" then
        vim.ui.input({ prompt = field.name .. " (comma-separated): " }, function(raw)
          if raw == nil or raw == "" then return next_field(nil) end
          local out = {}
          for s in raw:gmatch("[^,]+") do table.insert(out, vim.trim(s)) end
          next_field(out)
        end)
        return
      end

      local ref_kind = field.type:match("^ref%(([%w_]+)%)$")
      if ref_kind then
        local ref_def = ctx.def.entities[ref_kind]
        if not ref_def then
          vim.notify(("writa-projects: ref(%s) — entity type not declared"):format(ref_kind),
            vim.log.levels.ERROR)
          return
        end
        local glob = entity.glob_for_filename(ref_def.filename)
        local matches = vim.fn.glob(ctx.project_root .. "/" .. glob, false, true)
        local relpaths = {}
        for _, abs in ipairs(matches) do
          table.insert(relpaths, abs:sub(#ctx.project_root + 2))
        end
        if #relpaths == 0 then
          vim.notify(("no %s entities exist yet — skipping %s"):format(ref_kind, field.name),
            vim.log.levels.INFO)
          return next_field(nil)
        end
        vim.ui.select(relpaths, { prompt = ("%s (%s): "):format(field.name, ref_kind) },
          function(picked)
            if not picked then return next_field(nil) end
            next_field(refs.to_wikilink(picked))
          end)
        return
      end

      local list_kind = field.type:match("^list%(([%w_]+)%)$")
      if list_kind then
        local lk_def = ctx.def.entities[list_kind]
        if not lk_def then
          vim.notify(("writa-projects: list(%s) — entity type not declared"):format(list_kind),
            vim.log.levels.ERROR)
          return
        end
        local glob = entity.glob_for_filename(lk_def.filename)
        local matches = vim.fn.glob(ctx.project_root .. "/" .. glob, false, true)
        local relpaths = {}
        for _, abs in ipairs(matches) do
          table.insert(relpaths, abs:sub(#ctx.project_root + 2))
        end
        if #relpaths == 0 then return next_field({}) end

        local picked_links = {}
        local function pick_more()
          local remaining = {}
          for _, rp in ipairs(relpaths) do
            local link = refs.to_wikilink(rp)
            local already = false
            for _, p in ipairs(picked_links) do
              if p == link then already = true; break end
            end
            if not already then table.insert(remaining, rp) end
          end
          if #remaining == 0 then return next_field(picked_links) end
          local choices = { "<done>" }
          for _, rp in ipairs(remaining) do table.insert(choices, rp) end
          vim.ui.select(choices, { prompt = ("%s (%s): "):format(field.name, list_kind) },
            function(picked)
              if not picked or picked == "<done>" then return next_field(picked_links) end
              table.insert(picked_links, refs.to_wikilink(picked))
              pick_more()
            end)
        end
        pick_more()
        return
      end

      vim.notify(("writa-projects: unknown field type %q"):format(field.type),
        vim.log.levels.ERROR)
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
      local ok_marker, meta = pcall(loader.read_marker, marker)
      if not ok_marker then
        vim.notify(tostring(meta), vim.log.levels.ERROR); return
      end
      local ok_load, type_loaded = pcall(load_type_by_name, meta.type)
      if not ok_load then
        vim.notify(tostring(type_loaded), vim.log.levels.ERROR); return
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

        prompt_fields(ent_def.fields, 1, {}, { project_root = root, def = def }, function(values)
          -- Stage template into project so entity.create can read it
          local body_path = type_loaded.dir .. "/" .. ent_def.template
          local stage_path = root .. "/" .. ent_def.template
          vim.fn.mkdir(vim.fn.fnamemodify(stage_path, ":h"), "p")
          vim.fn.writefile(vim.fn.readfile(body_path), stage_path)

          local ok_create, err = pcall(entity.create, {
            project_root = root,
            project_meta = meta,
            entity_def   = ent_def,
            values       = values,
            open_after   = true,
          })

          if vim.fn.isdirectory(root .. "/templates") == 1 then
            vim.fn.delete(root .. "/templates", "rf")
          end

          if not ok_create then vim.notify(tostring(err), vim.log.levels.ERROR) end
        end)
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
        local ok_meta, meta = pcall(loader.read_marker, marker)
        if not ok_meta then return {} end
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
