# Projects

Declarative project scaffolding and entity creation for writa. A project is a directory tree (chapters, scenes, characters, etc.) generated from a YAML "project type". Once inside a project, new entities are created with prompt-driven flows that pick from existing entities for cross-references — those references are stored as `[[wikilinks]]` so `obsidian.nvim` backlinks work without any extra indexing.

## Quickstart

1. `:WritaNewProject novel` — pick a title, accept the default path (`~/writing/novels/<slug>`), optional description.
2. The new project opens. You're now in `~/writing/novels/my-book/` with `chapters/`, `scenes/`, `characters/`, `locations/`, `research/` laid out, a seeded chapter and protagonist, and `README.md` open.
3. `:WritaNewEntity scene` — answer prompts (title, which chapter, which characters, location, summary). The scene file lands in `scenes/`, frontmatter linked to chapter + characters via wikilinks, and opens.

Same flow for `screenplay` and `essay`.

## Commands

### `:WritaNewProject [type]`

Scaffolds a new project. With no argument, picks the type interactively from `project-types/`. Tab-completes type names.

Prompts:
1. **Project title** (required)
2. **Path** — pre-filled with the type's `default_path` (with `{slug}` interpolated)
3. **Description** (optional)
4. If target directory exists and is non-empty, confirm before proceeding.

After scaffold: opens the first seeded entity, or `README.md` if none.

### `:WritaOpenProject`

Discovers projects under configured roots (default `~/writing/`, depth 4) by globbing for `.writa-project.yaml`, then presents them via `vim.ui.select` (snacks or telescope, whichever AstroNvim is configured to use). Selecting one `:cd`s into the project, opens its `README.md`, and notifies.

To scan additional roots, set `opts.project_roots` on the spec in `lua/plugins/writing/projects/init.lua`:

```lua
opts = {
  project_roots = { "~/writing", "~/Documents/writing" },
},
```

### `:WritaNewEntity [kind]`

Creates a new entity inside the current project. Walks up from cwd to find `.writa-project.yaml`; errors if you're not inside a project. With no argument, picks the entity kind interactively from the project's type. Tab-completes kinds.

Prompts depend on field type:
- `string` / `int` — `vim.ui.input`
- `list` — comma-separated input
- `ref(X)` — picker over existing X-entities in the project
- `list(X)` — repeated picker; pick `<done>` to finish

After creation: opens the new file.

## Dashboard

The writa dashboard adds two entries above the snacks defaults:

| Key | Action |
|---|---|
| `w` | New Project (`:WritaNewProject`) |
| `W` | Open Project (`:WritaOpenProject`) |

## Discovery

A project is any directory containing a `.writa-project.yaml` marker. Discovery scans each root in `opts.project_roots` (default `~/writing/`) recursively to depth 4.

```yaml
# .writa-project.yaml
type: novel
title: My Novel
description: A first-person coming-of-age story.
created: 2026-04-24
```

`type` must match a directory name under `~/.config/writa/project-types/`.

## Built-in project types

- **novel** — long-form prose fiction. Entities: `chapter`, `scene`, `character`, `location`. Seeded with one chapter and a protagonist.
- **screenplay** — Fountain-based drama. Entities: `screenplay` (singleton), `act`, `scene` (`.fountain` body), `character`, `location`. Seeded with a 3-act structure.
- **essay** — argumentative non-fiction. Entities: `essay` (singleton), `argument`, `citation`. Seeded with one essay shell.

To add a custom type, see [`project-types/AUTHORING.md`](../project-types/AUTHORING.md).

## Limitations

- No MRU, favorites, or search across projects (planned for Spec 2).
- No relationship queries — relationships live as wikilinks; query via obsidian.nvim's backlinks for now.

## Requirements

- `yq` — the Go flavor (`mikefarah/yq`), **not** Python yq. Auto-installed via Mason.
- `yaml-language-server` — for editor-time validation of project-type YAML. Auto-installed via Mason.
