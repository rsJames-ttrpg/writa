# Authoring a project type

A project type tells writa how to scaffold a new project of that kind and what entities it knows how to create afterward. Types are pure data: a YAML file plus a `templates/` directory. No Lua required.

This guide walks through building a custom type from scratch, then references every key.

---

## Tutorial: a `poem-collection` type

We'll build a project type for a curated poetry collection. Each project has a few sections; each poem belongs to a section and (optionally) a few thematic tags.

### Step 1 — make the directory

```
~/.config/writa/project-types/poem-collection/
├── poem-collection.yaml
└── templates/
    ├── README.md
    ├── poem.md
    ├── section.md
    └── tag.md
```

The directory name (`poem-collection`) becomes the type identifier and **must match** the YAML filename's stem.

### Step 2 — write the YAML

`poem-collection.yaml`:

```yaml
# yaml-language-server: $schema=file:///home/jackm/.config/writa/schema/project-type/v1.json

name: PoemCollection
description: A curated poetry collection
default_path: ~/writing/poems/{slug}

directories: [poems, sections, tags]

root_files:
  - { path: README.md, template: templates/README.md }

entities:
  section:
    filename: "sections/{slug}.md"
    template: templates/section.md
    fields:
      - { name: title,       type: string, required: true }
      - { name: description, type: string }

  tag:
    filename: "tags/{slug}.md"
    template: templates/tag.md
    fields:
      - { name: name, type: string, required: true }

  poem:
    filename: "poems/{slug}.md"
    template: templates/poem.md
    fields:
      - { name: title,   type: string,         required: true }
      - { name: section, type: "ref(section)", required: true }
      - { name: tags,    type: "list(tag)" }

initial:
  - { entity: section, values: { title: "Opening" } }
```

The `# yaml-language-server: $schema=…` header on line 1 wires up live validation in nvim.

### Step 3 — write the templates

`templates/README.md`:

```markdown
# {project.title}

{project.description}
```

`templates/poem.md`:

```markdown
# {title}

```

`templates/section.md`:

```markdown
# {title}

{description}
```

`templates/tag.md`:

```markdown
# {name}
```

Templates do **not** include frontmatter — the runtime assembles a YAML block from the resolved field values and prepends it.

### Step 4 — try it

```vim
:WritaNewProject poem-collection
```

Title `Spring Cycle`, accept default path. The project opens with `README.md`, and an `Opening` section already exists from `initial[]`. Then:

```vim
:WritaNewEntity poem
```

Answer prompts: title `Thaw`, section picker offers `Opening`, tags picker is empty (no tags yet — pick `<done>`). The new file opens with frontmatter linking to `[[sections/opening]]`.

That's the whole shape. Everything below is reference.

---

## Reference

### Top-level keys

| Key           | Type        | Required | Notes                                                         |
|---------------|-------------|----------|---------------------------------------------------------------|
| `name`        | string      | yes      | Display name. Shown in the type picker; stored in the marker. |
| `description` | string      | no       | Shown in the project picker (Spec 2).                         |
| `default_path`| string      | no       | Pre-fills the path prompt. `{slug}` is interpolated.          |
| `directories` | string list | yes      | Subdirectories created at scaffold (even if empty).           |
| `root_files`  | list        | no       | Files written at the project root from a template.            |
| `entities`    | map         | yes      | Entity type definitions.                                      |
| `initial`     | list        | no       | Entities created during scaffold.                             |

### `root_files[]`

```yaml
root_files:
  - { path: README.md, template: templates/README.md }
```

| Key        | Notes                                                              |
|------------|--------------------------------------------------------------------|
| `path`     | Project-relative output path.                                      |
| `template` | Path to the template file, relative to the type directory.         |

These templates are interpolated against the project context only (`{project.title}`, `{project.slug}`, `{project.description}`, `{slug}`). They are **not** entities — no frontmatter is added.

### `entities.<kind>`

```yaml
entities:
  scene:
    filename: "scenes/{slug}.md"
    template: templates/scene.md
    fields: [...]
```

| Key        | Notes                                                                                |
|------------|--------------------------------------------------------------------------------------|
| `filename` | Project-relative path with `{var}` placeholders. Interpolated against field values. |
| `template` | Path to the body template, relative to the type directory.                           |
| `fields`   | Ordered list of fields. Prompts run in declaration order.                            |

### Field types

| Type              | Prompt                                  | Frontmatter shape           |
|-------------------|-----------------------------------------|-----------------------------|
| `string`          | `vim.ui.input`                          | plain string                |
| `int`             | `vim.ui.input` + parse                  | integer                     |
| `list`            | `vim.ui.input`, comma-separated         | YAML list of strings        |
| `ref(EntityKind)` | picker of existing `EntityKind`         | `"[[path/to/entity]]"`      |
| `list(EntityKind)`| repeated picker, `<done>` to finish     | YAML list of `"[[…]]"`      |

Field flags:
- `required: true` — prompt is non-skippable; missing value aborts.
- (no `required`) — prompt is skippable; field is omitted from frontmatter if empty.

Frontmatter keys are emitted in **alphabetical order** (deterministic). Don't rely on declaration order in the file output.

### Filename interpolation

Placeholders allowed in `filename`:

- `{field_name}` — value of a field on this entity
- `{slug}` — auto-derived (see Slug rule)
- `{field:spec}` — formatted value

Format-spec grammar (Python-style subset): `[0]?<width>?[ds]`.

| Spec | Meaning                  | Example                  |
|------|--------------------------|--------------------------|
| `d`  | integer                  | `{number:d}` → `1`       |
| `s`  | string                   | `{title:s}` → `Foo`      |
| `02d`| int, zero-pad to width 2 | `{number:02d}` → `01`    |
| `4s` | string, space-pad to 4   | `{tag:4s}` → `foo `      |

Anything outside this subset (e.g. `{n:x}`, `{n:.2f}`) errors at scaffold time. Unmatched braces in templates also error.

### Slug rule

Each entity gets an auto-derived `{slug}`. The source field is picked in this order:

1. A field named `title` that is `required: true` and `type: string`.
2. A field named `name` that is `required: true` and `type: string`.
3. The first `required: true` `type: string` field, in declaration order.

If no required string field exists, scaffolding the entity errors. Add one (or rename your existing field to `title` / `name`).

Derivation:

1. Lowercase
2. Replace any run of non-`[a-z0-9]` with `-`
3. Trim leading/trailing `-`

`"Chapter 1: The Beginning"` → `chapter-1-the-beginning`.

### Body templates

Plain text — extension is whatever `entities.<kind>.filename` ends in (`.md`, `.fountain`, etc.). Variables available:

- `{field_name}` — any field on this entity (empty string if unset)
- `{slug}` — entity's derived slug
- `{project.title}`, `{project.slug}`, `{project.description}` — project-scoped

Templates do **not** include frontmatter. The runtime emits a `---`-fenced YAML block from the resolved field values and prepends it.

### Wikilink output

A `ref(character)` value picked from `characters/jack.md` is stored as:

```yaml
pov: "[[characters/jack]]"
```

The extension is dropped — `.md`, `.markdown`, and `.fountain` are all stripped. A `list(character)` becomes a YAML list of those strings. `obsidian.nvim` resolves backlinks against this format automatically.

### `initial[]`

```yaml
initial:
  - { entity: chapter,   values: { number: 1, title: "Chapter 1" } }
  - { entity: character, values: { name: "Protagonist" } }
```

Each entry runs the entity creation flow at scaffold time with `values` pre-filled. Any required fields not present in `values` are still prompted for.

Order matters: if a later initial entity has a `ref(X)` field, the picker only sees X-entities created earlier.

### Validation

Two layers:

1. **Editor-time** — `yaml-language-server` against `schema/project-type/v1.json` (the schema header on line 1 of your YAML wires this up). Red squigglies in nvim if you forget a required key or use a bad field type.
2. **Load-time** — `lua/plugins/writing/projects/loader.lua` re-checks required keys and validates each field's `type` against the regex grammar. Failures surface as `vim.notify` warnings during `:WritaNewProject` / `:WritaOpenProject`.

### A real example

`project-types/novel/novel.yaml` is a complete, working type covering all the patterns above (multiple entity types, refs, lists-of-refs, initial entities). Read it alongside this guide.
