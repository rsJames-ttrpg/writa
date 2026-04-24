# writa-projects — design (Spec 1)

Project types and scaffolding for writa. A user runs `:WritaNewProject novel`, answers a few prompts, and gets a directory tree pre-populated with chapters, characters, and other entities defined by a declarative YAML template. Once inside a project, `:WritaNewEntity scene` walks them through creating a new scene with typed prompts (including pickers for references to other entities, e.g., which chapter this scene belongs to).

This is Spec 1 of a three-part plan:
- **Spec 1 (this doc):** project types, scaffolding, entity creation, **minimal dashboard integration** (New/Open Project entries)
- **Spec 2 (next):** richer project manager UX — recent-project MRU tracking, favorites, project search by title/description, per-project settings
- **Spec 3 (deferred):** entity-relationship queries — Dataview-in-nvim territory, punted

## Goals

- Writers can scaffold a fully-laid-out writing project (novel, screenplay, essay) with one command.
- Project types are declarative YAML — writers and non-Lua-users can author their own types.
- Entity creation inside an existing project is prompt-driven, with pickers for references to other entities.
- Plain-text everywhere; relationships stored as obsidian-style `[[wikilinks]]` so `obsidian.nvim`'s backlinks work without additional indexing.
- The writa dashboard exposes **New Project** and **Open Project** entries so the experience matches familiar project-management plugins — users don't have to remember commands.
- Structure the code so the whole subsystem can be extracted to a standalone plugin (`writa-projects.nvim`) later with `git mv`.

## Non-goals

- No relationship queries ("show me all scenes featuring Jack"). That's Spec 3.
- No MRU tracking, favorites, or search across project metadata. The Open-Project picker lists all discovered projects unfiltered; richer UX is Spec 2.
- No hierarchical directory layout. Entities are flat at the project root; relationships are expressed via frontmatter links, not directory nesting.
- No Lua templates. A future `pre_scaffold.lua` / `post_scaffold.lua` hook is plausible for power users but not in MVP.
- No automatic migrations when a type definition changes. Types are authored, not versioned per-project.

## Layout

### Project-type definitions

Project types live in `~/.config/writa/project-types/<name>/`:

```
~/.config/writa/project-types/novel/
├── novel.yaml              # type definition
└── templates/
    ├── chapter.md          # body template per entity type
    ├── scene.md
    ├── character.md
    ├── location.md
    ├── README.md           # body template for root_files entries
    └── outline.md
```

### A scaffolded novel project

```
~/writing/novels/my-book/
├── .writa-project.yaml     # marker file (type + metadata)
├── README.md               # written from templates/README.md
├── outline.md              # written from templates/outline.md
├── chapters/
│   └── 01-chapter-1.md     # from initial[] in novel.yaml
├── scenes/                 # empty directory
├── characters/
│   └── protagonist.md      # from initial[] in novel.yaml
├── locations/              # empty
└── research/               # empty
```

## Type definition format

```yaml
# yaml-language-server: $schema=https://writa.dev/schema/project-type/v1.json

name: Novel
description: Long-form prose fiction
default_path: ~/writing/novels/{slug}

# Subdirectories created up-front (even if empty)
directories: [chapters, scenes, characters, locations, research]

# Files written at the project root, each from a body template
root_files:
  - { path: README.md,  template: templates/README.md }
  - { path: outline.md, template: templates/outline.md }

# Entity type definitions — one file per instance
entities:
  chapter:
    filename: "chapters/{number:02d}-{slug}.md"
    template: templates/chapter.md
    fields:
      - { name: number, type: int, required: true }
      - { name: title,  type: string, required: true }
      - { name: pov,    type: "ref(character)" }

  scene:
    filename: "scenes/{slug}.md"
    template: templates/scene.md
    fields:
      - { name: title,      type: string, required: true }
      - { name: chapter,    type: "ref(chapter)", required: true }
      - { name: characters, type: "list(character)" }
      - { name: location,   type: "ref(location)" }

  character:
    filename: "characters/{slug}.md"
    template: templates/character.md
    fields:
      - { name: name, type: string, required: true }
      - { name: role, type: string }

  location:
    filename: "locations/{slug}.md"
    template: templates/location.md
    fields:
      - { name: name, type: string, required: true }

# Entities created at scaffold time (in order)
initial:
  - { entity: chapter,   values: { number: 1, title: "Chapter 1" } }
  - { entity: character, values: { name: "Protagonist" } }
```

### Field types

| Type              | Scaffold prompt        | Stored in frontmatter              |
|-------------------|------------------------|------------------------------------|
| `string`          | `vim.ui.input`         | Plain string                       |
| `int`             | `vim.ui.input` + parse | Integer                            |
| `list`            | `vim.ui.input` CSV     | YAML list of strings               |
| `ref(EntityType)` | picker of existing     | `"[[path/to/entity]]"`             |
| `list(EntityType)`| multi-select picker    | YAML list of `"[[..]]"` strings    |

Field flags:
- `required: true` — prompt is non-skippable; error if value is empty
- (absent `required`) — prompt skippable; field omitted from frontmatter if unset

### Body templates

Plain markdown. Frontmatter is not in the template — the runtime assembles it from the resolved field values and prepends it to the template's contents.

Example `templates/chapter.md`:

```markdown
# {title}

## Summary

## Draft

---

Part of *{project.title}*.
```

Produces (for `{ number: 1, title: "Opening", project.title: "My Novel" }`):

```markdown
---
number: 1
title: Opening
---
# Opening

## Summary

## Draft

---

Part of *My Novel*.
```

### Variable resolution

- `{field}` — the entity's own field value
- `{project.title}`, `{project.slug}`, `{project.description}` — project-scoped values
- `{slug}` — auto-derived from the entity's slug-source field (see Slug rule below) unless explicitly given
- `{number:02d}` — Python-style format spec; supported subset: `d` (integer), `s` (string), numeric width, `0` zero-pad flag. Unsupported specs raise an error on scaffold, not silently mangle.

### Slug rule

Each entity type has an implicit slug source: the first `required` field of type `string` among `title`, `name`, else the first required string field. If no required string field exists, the type must declare an explicit `slug` field or scaffolding fails for it.

Derivation from the source value:

1. Lowercase.
2. Replace any run of non-ASCII-alphanumeric with `-`.
3. Trim leading/trailing `-`.
4. Collapse multiple `-` to one.

`"Chapter 1: The Beginning"` → `chapter-1-the-beginning`. `{slug}` is always available in `filename` and `body` template interpolation but is not written into frontmatter unless declared as an explicit field.

## Commands and behavior

### `:WritaNewProject [type]`

1. If `type` omitted → picker across available `project-types/`.
2. Prompt for `title` (required).
3. Derive `slug` from title.
4. Prompt for `path` with `default_path` pre-filled (having interpolated `{slug}`).
5. If the target directory exists and is non-empty → confirm before proceeding.
6. Create the directory tree from `directories`.
7. Write `.writa-project.yaml` marker file with `{ type, title, description, created }`.
8. For each entry in `root_files`: read template, interpolate, write.
9. For each entry in `initial[]`: run the entity creation flow with `values` pre-filled. Missing required fields are still prompted for.
10. Open the first `initial` entity's file (or `README.md` if no initial entities).

### `:WritaOpenProject`

1. For each root in `project_roots` (default `{ "~/writing" }`, configurable), glob `**/.writa-project.yaml` — bounded depth 4 to avoid pathological deep scans.
2. Parse each marker file's `title`, `type`, `description`.
3. Present via `vim.ui.select` as "Title (type) — path". AstroNvim's UI config picks telescope or snacks automatically.
4. On selection: `:cd` to the project directory, open `README.md` if present, else the first `initial[]` entity's file.

Results are cached per-session keyed on mtime of each marker file. No persistent registry — Spec 2 adds that.

### `:WritaNewEntity [kind]`

1. Walk up from cwd to find `.writa-project.yaml`. Error if not inside a project.
2. Load the project's type definition.
3. If `kind` omitted → picker across `entities` keys of that type.
4. For each field (in declaration order):
   - Skip if value already given (when called with pre-filled values from `initial`).
   - `string` / `int` → `vim.ui.input`.
   - `list` → `vim.ui.input` (comma-separated).
   - `ref(X)` / `list(X)` → picker populated from existing X-entities in the project. Glob is computed by replacing every `{...}` token in `entities.X.filename` with `*` (e.g., `chapters/{number:02d}-{slug}.md` → `chapters/*-*.md`).
5. Derive `slug` from the slug source field.
6. Render filename via format interpolation. Error if file already exists.
7. Assemble frontmatter from resolved field values.
8. Render body from template.
9. Write `<frontmatter>\n<body>` to the file.
10. Open the new file.

### Project marker file

`.writa-project.yaml` at the project root:

```yaml
type: novel
title: My Novel
description: A first-person coming-of-age story.
created: 2026-04-24
```

Written at scaffold time. Used by `:WritaNewEntity` to identify the project root and its type. Not edited programmatically after creation — if a writer wants to rename/relocate, they do it by hand.

## Reference resolution and wikilinks

A `ref(character)` value, when the user picks `characters/jack.md` from the picker, is stored in frontmatter as:

```yaml
pov: "[[characters/jack]]"
```

The `.md` extension is dropped, matching obsidian conventions. A `list(character)` becomes a YAML list of such strings.

`obsidian.nvim`'s backlinks feature then returns all scenes whose frontmatter `[[characters/jack]]` automatically. No new index to maintain.

## Module layout

All implementation at `~/.config/writa/lua/plugins/writing/projects/`:

```
lua/plugins/writing/projects/
├── init.lua       # plugin spec + :WritaNewProject / :WritaOpenProject / :WritaNewEntity user commands
├── loader.lua     # read project-types/ dir, parse YAML, validate against schema
├── scaffold.lua   # :WritaNewProject flow — mkdir, root_files, initial entities
├── open.lua       # :WritaOpenProject flow — discovery scan, picker, cd + open
├── entity.lua     # :WritaNewEntity flow — prompts, pickers, file write
├── format.lua     # variable + format-spec interpolation
├── refs.lua       # wikilink generation from picker values
└── slug.lua       # slug derivation
```

Each module has a single responsibility and a small public interface. The writing/ aggregator gets one new `"projects"` entry.

### Dashboard integration

The existing `lua/plugins/dashboard.lua` (which already overrides the snacks header) is extended to add two keymap entries under the dashboard's `keys` section:

```lua
keys = {
  { icon = " ", key = "w", desc = "New Project",   action = ":WritaNewProject" },
  { icon = " ", key = "W", desc = "Open Project",  action = ":WritaOpenProject" },
  -- ... existing entries preserved
},
```

Keys chosen: lowercase `w` (new) and uppercase `W` (open), so muscle-memory pairs them. Icons are nerd-font glyphs that render in the user's Hack Nerd Font setup. Placement: directly under `Find File` / `New File` so project actions sit at the top of the dashboard key list, above config/utility entries.

Existing snacks dashboard defaults (Find File, New File, Recent Files, Find Text, Config, Sessions, Lazy, Quit) are preserved by mutating the list, not replacing it.

YAML parsing: depend on a pure-Lua YAML library (e.g., `FutureGap/yaml.nvim` or equivalent — exact pick deferred to implementation). Avoids a system-level `yq` dependency.

Schema validation: the JSON schema at `schema/project-type/v1.json` (shipped in the writa repo) gives editor-time completion via `yaml-language-server`, and the loader runs a lightweight Lua-side validation on load (checks required keys, field `type` regex) to fail fast on typos.

## MVP content — what ships day one

Three project types ship with writa:

1. **novel** — prose fiction; entities: chapter, scene, character, location. Directories: chapters, scenes, characters, locations, research.
2. **screenplay** — Fountain-based; entities: script (single `.fountain` file), scene, character, location. Directories: scripts, scenes, characters, locations, research. `scripts/{slug}.fountain` is the main writing target; scenes and characters are planning aids.
3. **essay** — single-file longform non-fiction; entities: draft, source. Directories: drafts, sources, notes. `drafts/{version}-{slug}.md` as the main file, sources are citations.

## Integration with existing writa features

- `yaml-language-server` added to Mason's `ensure_installed` (writa extends `lua/plugins/mason.lua`) with schema association for `project-types/**/*.yaml`.
- `<Leader>Wp` currently = "Pomodoro 25m" (pomo.nvim). Rebind pomo to `<Leader>WP` **start** and `<Leader>WT` **stop**, freeing `<Leader>Wp` for project-manager keys in Spec 2. (Note: this means renaming two keys. Decided to flag it now rather than colliding in Spec 2.)
- `.writa-project.yaml` is picked up as `yaml` filetype automatically; writa's writing-mode autocmd already ignores non-prose filetypes, so no exclusion is needed.

## Deferred for a future spec

- **Spec 2:** MRU tracking (`~/.local/state/writa/projects.json`); "Recent Projects" section on the dashboard above the "Open Project" entry; project search by title/description substring; favorites/pinning; per-project settings overlay (`.writa-project.yaml` extended fields).
- **Spec 3:** relationship queries — a `:WritaEntitiesOf` picker, Dataview-style cross-entity queries, timeline views.
- Post-scaffold Lua hooks (`post_scaffold.lua`) — YAGNI until a real use case shows up.
- Project-type versioning / migration — assume writers don't need this for now.
- Auto-renumbering when a chapter is inserted between existing ones.

## Risks

- **YAML parser choice:** pure-Lua YAML libs are relatively slow and have varying completeness. For our tiny schema it's fine, but if performance bites we can revisit (shell out to `yq`, pre-compile schemas, etc.). Mitigation: keep the loader cache per-session so we only parse each type once.
- **Picker dependency:** ref fields need a picker. AstroNvim ships both telescope and snacks pickers. Entity-pick uses `vim.ui.select` as the abstraction so both work; the user's picker choice (via AstroNvim's UI config) is honored automatically.
- **Obsidian wikilink format variance:** obsidian.nvim supports multiple link formats. We emit `[[path/to/file]]` (wiki style, no alias) which is universally recognized; users who prefer markdown-style links can configure obsidian to re-render. No config required on writa's side.
- **Filename collisions during scaffold:** a novel seeded with a chapter "Chapter 1" + an essay with a "draft.md" could collide if someone chooses overlapping slugs. Mitigation: error-on-exist, user reruns with a different slug.

## Success criteria

- `:WritaNewProject novel` produces a complete, opened project in under a second (excluding human prompt time).
- Running `:WritaNewEntity scene` in that project, choosing "Opening" as the title, picking the chapter and characters from the picker, produces a valid scene file with frontmatter linking back to those entities.
- The same set of actions works identically for `screenplay` and `essay` types.
- The writa dashboard shows **New Project** and **Open Project** entries; pressing `w` from the dashboard starts a new project; pressing `W` lists existing projects discovered in `~/writing/`.
- Zero system-level dependencies beyond what writa already requires.
- A writer can author a new `thesis.yaml` project type with a `templates/` folder beside it and it shows up in the `:WritaNewProject` picker without any Lua edits or plugin restart.
