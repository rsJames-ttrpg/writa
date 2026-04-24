# writa — design

A writer-focused Neovim configuration, installed alongside the daily-driver Neovim and run via `NVIM_APPNAME=writa`. Successor to the abandoned OVIWrite, built on AstroNvim. Structured so the writing-specific plugin layer can later be extracted as an `astrocommunity.writing` pack for public consumption.

## Goals

- Zero bleed into daily coding config. Separate `NVIM_APPNAME`, separate lockfile, separate Mason store, separate state.
- Inherit AstroNvim's baseline (keymaps, LSP plumbing, completion, file pickers, theme system, treesitter) so writing and coding sessions share muscle memory.
- Cover the three writing modes the author actually does: screenwriting (Fountain), markdown notes / Zettelkasten, long-form prose + LaTeX.
- Eliminate OVIWrite's duplication and broken-plugin sprawl. Target ~15–18 writer-specific plugins, not ~60.
- Structure the writing layer as a future community pack from day one: one self-contained directory, local today, extractable later with `git mv`.

## Non-goals

- Not a standalone distro. Depends on AstroNvim.
- No in-place migration of OVIWrite. The existing `~/.config/oviwrite` is retired once writa is usable, not upgraded.
- No shared filesystem state with the daily `~/.config/nvim`. Symlink-based sharing was explicitly rejected — the two configs evolve independently.

## Architecture

### Dual-appname layout

```
~/.config/nvim/          # daily driver, untouched
~/.config/writa/         # new; this spec
~/.config/oviwrite/      # legacy; retire after writa is ready
```

Shell alias: `writa="NVIM_APPNAME=writa nvim"` (exact name user's choice; current `ovi` alias kept in place until retirement).

### Directory structure

```
~/.config/writa/
├── init.lua                  # stock AstroNvim bootstrap
├── lazy-lock.json            # managed by lazy; distinct from daily nvim
├── selene.toml
├── stylua.toml
├── docs/
│   └── specs/
│       └── 2026-04-24-writa-design.md   # this file
└── lua/
    ├── community.lua         # AstroNvim community pack imports
    ├── lazy_setup.lua        # stock
    ├── polish.lua            # writa-specific tweaks
    └── plugins/
        ├── astrocore.lua     # options, keymaps, autocmds (consolidated)
        ├── astrolsp.lua      # LSP servers incl. ltex
        ├── astroui.lua       # theme
        ├── mason.lua         # ltex-ls, vale install
        ├── treesitter.lua    # markdown, markdown_inline, latex, bibtex, org
        └── writing/          # ← future astrocommunity.writing pack
            ├── init.lua
            ├── ltex.lua
            ├── vale.lua
            ├── pencil.lua
            ├── zen-mode.lua
            ├── render-markdown.lua
            ├── img-clip.lua
            ├── undotree.lua
            ├── obsidian.lua
            ├── markdown-preview.lua
            ├── autolist.lua
            ├── fountain.lua
            ├── vimtex.lua
            ├── pomo.lua
            ├── translate.lua
            ├── thesaurus.lua
            ├── cmp-dictionary.lua
            ├── noice.lua
            └── gen.lua
```

The `writing/` subdirectory is the physical boundary of the future community pack. Its contents move unchanged into a GitHub repo when extracted; only `init.lua` gains an astrocommunity-style loader wrapper at that time.

### Base

Clone `AstroNvim/template` into `~/.config/writa/`, then overlay the writa-specific files. No fork, no custom bootstrap.

## Plugin inventory

### Core writing (all writing filetypes)

| Plugin | Role |
|---|---|
| `barreiroleo/ltex_extra.nvim` + `ltex-ls` | Grammar/spell via self-hosted LanguageTool at `https://languagetool.home.lan`. Already-built config carries over from `~/.config/oviwrite/lua/plugins/ltex.lua`. |
| `errata-ai/vale` (via mason) + vale.nvim wrapper | Prose style linting — different layer from grammar. |
| pencil plugin (exact fork — `preservim/vim-pencil` or a neovim-native successor — picked in phase 2) | Soft-wrap for prose. |
| `folke/zen-mode.nvim` | Single distraction-free mode. Replaces six OVIWrite plugins (goyo, limelight, twilight, centerpad, typewriter, zen-mode). |
| `MeanderingProgrammer/render-markdown.nvim` | Inline rendering of headings, code, tables, lists in the buffer. Strictly supersedes `headlines.nvim`. |
| `HakonHarnes/img-clip.nvim` | Paste clipboard images into markdown/latex. |
| `mbbill/undotree` | Undo history UI; writers value this more than coders. |

### Markdown notes / Zettelkasten

| Plugin | Role |
|---|---|
| `epwalsh/obsidian.nvim` | Notes graph, backlinks, daily notes. Works on a plain markdown vault — the Obsidian app is not required. Replaces VimWiki + vim-zettel. |
| `iamcco/markdown-preview.nvim` | Browser preview of markdown. |
| `gaoDean/autolist.nvim` | Smart list continuation in prose. |

### Screenwriting

| Plugin | Role |
|---|---|
| `kblin/vim-fountain` | Fountain syntax + folding. |

### Long-form / LaTeX

| Plugin | Role |
|---|---|
| `lervag/vimtex` | LaTeX editing + compile pipeline. |

### Workflow

| Plugin | Role |
|---|---|
| `epwalsh/pomo.nvim` | Pomodoro timer. |
| `niuiic/translate.nvim` (or equivalent) | Translation; final plugin choice deferred to phase 5. |
| `Ron89/thesaurus_query.vim` | Thesaurus lookup. |
| `uga-rosa/cmp-dictionary` | System-dictionary completion source for nvim-cmp. |

### Keep from OVIWrite by explicit user request

| Plugin | Role |
|---|---|
| `folke/noice.nvim` | Pretty command-line and notifications. User likes it. |
| `David-Kunz/gen.nvim` | Local-LLM writing assistance. User may use it. |

### Dropped (with rationale)

- **Distraction-free duplicates** (`goyo`, `limelight`, `twilight`, `centerpad`, `typewriter`): zen-mode.nvim covers all six.
- **Grammar duplicates** (`LanguageTool.nvim` (vigoux), `vim-grammarous`): ltex-ls covers both and adds LSP code actions.
- **Wiki duplicates** (`vimwiki`, `vim-zettel`, `vimorg`, `org-bullets`): obsidian.nvim + nvim-orgmode cover.
- **AstroNvim baseline** (`fzf-vim`, `fzf-lua`, `telescope`, `nvim-cmp`, `nvim-autopairs`, `nvim-tree`, `nvim-web-devicons`, `mason`, `mason-lspconfig`, `alpha`, `comment`, `gruvbox`/`catppuccin`/`nightfox` as raw plugins): all provided by AstroNvim's stock template or its community.
- **Writer-non-essential** (`cl-neovim`, `gen` — kept on request, `w3m`, `high-str`, `stay-centered`, `screenkey`, `hardtime`, `styledoc`, `quicklispnvim`, `vim-dialect`): dropped unless user specifically reinstates.
- **Misc duplicates / obsolete**: `vim-pencil` → pencil.nvim, `headlines.nvim` → render-markdown.nvim, `autopandoc` → dropped unless user uses it, `vim-latex-preview` → vimtex provides.

Net: ~18 writer-specific plugins, down from ~60 in OVIWrite.

## Conventions

### Keymaps

All writing-specific keymaps live under the `<leader>W` prefix (capital W). Which-key group label: "Writing".

- `<leader>Wz` — zen mode toggle
- `<leader>Wo` — obsidian picker
- `<leader>Wt` — translate menu
- `<leader>Wp` — pomodoro menu
- `<leader>Wm` — markdown preview toggle
- `<leader>Wg` — gen (LLM) menu
- `<leader>Wi` — paste clipboard image
- `<leader>Ws` — thesaurus for word under cursor
- `<leader>Wu` — undotree toggle

Single namespace. No collision with AstroNvim's default lowercase prefixes.

### Autocmds

One `writing_mode` augroup. A single per-filetype handler on `markdown|tex|org|fountain|typst`:

- `spell = true`, `spelllang = "en"`
- `conceallevel = 2` (for markdown and obsidian)
- `wrap = true`, `linebreak = true`, `breakindent = true`
- enable pencil.nvim for the buffer
- set `textwidth` appropriately (screenwriting wants 80; prose wants unset)

Replaces OVIWrite's 15+ per-filetype `BufEnter` autocmds. Anything filetype-specific beyond this (e.g. vimtex compile on `.tex` open) lives in the plugin's own config, not in a global autocmd.

### File organization

One plugin per file in `lua/plugins/writing/`. No combining. This maps 1:1 to the community-pack layout and makes extraction mechanical.

## Build phases

| # | Phase | Completion criterion |
|---|---|---|
| 0 | Bootstrap | `NVIM_APPNAME=writa nvim` boots to the AstroNvim dashboard with no errors. |
| 1 | Base | options + keymaps + autocmds wired in astrocore; treesitter parsers installed; ltex LSP attaches in a markdown file. |
| 2 | Core writing | ltex, pencil, zen-mode, render-markdown, img-clip, undotree all load without errors; `<leader>Wz` works. |
| 3 | Notes | obsidian opens a test vault; markdown-preview renders in browser; autolist continues a list. |
| 4 | Scripts + LaTeX | `.fountain` file highlights; vimtex compiles a sample `.tex`. |
| 5 | Workflow | pomo, translate, thesaurus, cmp-dictionary, vale, noice, gen all installed and their keymaps respond. |
| 6 | Polish | which-key shows "Writing" group under `<leader>W`; autocmds consolidated; no duplicate keymaps; selene + stylua clean. |
| 7 | Shakedown | Open a real `.md`, `.tex`, `.fountain`, `.org` file. LSP attaches, diagnostics show, rendering works, compile succeeds. |

After phase 7, the alias goes live and `~/.config/oviwrite/` can be retired at the user's pace. Extraction to a public astrocommunity-style repo becomes a separate follow-on project.

## Deferred decisions

- Exact `translate.nvim` plugin choice (several competing forks). Picked in phase 5.
- Whether to include `vale-ls` in addition to the vale.nvim wrapper. Decided in phase 5.
- Whether to include `typst` filetype support. Punted — user does not currently write typst.
- Extraction mechanics and repo name for the community pack. Punted to a future spec.

## Risks and mitigations

- **AstroNvim base-version drift**: AstroNvim's stock template pins versions in its lockfile. writa gets its own lockfile, so daily-nvim updates cannot break writa. Mitigation: built in by design.
- **Plugin conflict in writing/ directory**: each plugin is isolated in its own file with its own lazy-loading triggers. If one plugin breaks, it doesn't cascade. Mitigation: strict one-plugin-per-file convention.
- **Two ltex-ls installs (oviwrite + writa)**: Mason stores are per-appname, so both exist side-by-side harmlessly. oviwrite removed when writa is usable.
- **User stuck in OVIWrite during build**: all work happens in `~/.config/writa/`; oviwrite remains functional. Switchover is a one-line alias edit.
