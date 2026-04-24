# writa

A Neovim configuration for writing — prose, screenwriting, Markdown notes, LaTeX.

Based on [AstroNvim](https://astronvim.com/). Run via:

    NVIM_APPNAME=writa nvim

Recommended alias (zsh/bash):

    alias writa='NVIM_APPNAME=writa nvim'

## Layout

- `lua/plugins/` — overrides for the AstroNvim base (astrocore, astrolsp, mason, treesitter).
- `lua/plugins/writing/` — writer-specific plugin layer. Future extraction target for an `astrocommunity.writing` pack.
- `lua/polish.lua` — writing-mode autocmd (spell, soft-wrap, conceal).
- `docs/specs/` — design docs.
- `docs/plans/` — implementation plans.
- `docs/vale.ini.example` — template for `~/.vale.ini`.

## Keymaps

All writing features live under the `<Leader>W` prefix. Press `<space>W` in normal mode for the full menu (which-key shows it).

| Keymap | Action |
|---|---|
| `<Leader>Wz` | Zen mode toggle |
| `<Leader>Wo` | Obsidian quick switch |
| `<Leader>Wn` | Obsidian new note |
| `<Leader>Wd` | Obsidian today |
| `<Leader>Wb` | Obsidian backlinks |
| `<Leader>Wm` | Markdown preview toggle |
| `<Leader>Wi` | Paste clipboard image |
| `<Leader>Ws` | Thesaurus: replace word |
| `<Leader>Wu` | Toggle undotree |
| `<Leader>Wp` / `<Leader>WP` | Pomodoro start (25m) / stop |
| `<Leader>Wtf` / `<Leader>Wte` | Translate → French / English |
| `<Leader>Wg` | Gen (local LLM via Ollama) |

## Requirements

- Neovim ≥ 0.10
- `yarn` (for markdown-preview.nvim build)
- `latexmk` + TeX Live (for vimtex) — `sudo pacman -S texlive-basic texlive-binextra texlive-latexrecommended`
- `zathura` (PDF viewer configured in vimtex) — `sudo pacman -S zathura zathura-pdf-mupdf`
- `~/.vale.ini` — copy from `docs/vale.ini.example`
- Self-hosted LanguageTool reachable at the URL in `lua/plugins/astrolsp.lua` (default `https://languagetool.home.lan`)
- Optional: Ollama running locally for `<Leader>Wg` (gen.nvim); model name configured in `lua/plugins/writing/gen.lua`

## Credits

Successor to [OVIWrite](https://github.com/MiragianCycle/OVIWrite). Built on [AstroNvim](https://astronvim.com/) with a curated writing plugin layer.
