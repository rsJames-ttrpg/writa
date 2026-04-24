# writa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a new Neovim configuration at `~/.config/writa/` — AstroNvim base plus an isolated "writing layer" of ~18 writer-specific plugins — that runs via `NVIM_APPNAME=writa` with zero bleed into the user's daily `~/.config/nvim` install.

**Architecture:** Stock AstroNvim template as base. All writer-specific plugins live in `lua/plugins/writing/`, one plugin per file, structured so that directory can later be extracted as an `astrocommunity.writing` pack with `git mv`. Separate lockfile, separate Mason store, separate state from daily nvim.

**Tech Stack:** Neovim ≥ 0.10, AstroNvim v5, lazy.nvim, Mason, nvim-lspconfig, ltex-ls (proxying to self-hosted LanguageTool at `https://languagetool.home.lan`), vimtex, obsidian.nvim, noice.nvim.

**Spec:** `/home/jackm/.config/writa/docs/specs/2026-04-24-writa-design.md`

---

## Verification model

Neovim configs are verified differently from test-driven code. Every task ends with one or more of:

- **Headless smoke:** `NVIM_APPNAME=writa nvim --headless "+qa"` — boots, no unhandled errors on stderr.
- **Lazy state:** `NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa"` — installs/updates cleanly.
- **Interactive check:** open a specific filetype file, run `:LspInfo` / `:checkhealth` / press a keymap, confirm expected behavior.

Interactive checks are called out explicitly in each task with the exact command to run and what to look for.

---

## Phase 0 — Bootstrap

### Task 0.1: Preserve spec, clone AstroNvim template, restore spec

The spec we already wrote lives at `~/.config/writa/docs/specs/`. The AstroNvim template bootstrap expects an empty directory. We move the spec aside, clone, then move it back.

**Files:**
- Preserve: `~/.config/writa/docs/` (contains the spec)
- Create: `~/.config/writa/` (full AstroNvim template tree)

- [ ] **Step 1: Move existing writa contents aside**

```bash
mv ~/.config/writa ~/.config/writa.preserve
```

- [ ] **Step 2: Clone AstroNvim template**

```bash
git clone --depth 1 https://github.com/AstroNvim/template ~/.config/writa
```

- [ ] **Step 3: Remove the template's upstream git remote and history**

We want a fresh local git history, not a fork of the template.

```bash
rm -rf ~/.config/writa/.git
```

- [ ] **Step 4: Restore the spec/plan docs**

```bash
mv ~/.config/writa.preserve/docs ~/.config/writa/docs
rmdir ~/.config/writa.preserve
```

- [ ] **Step 5: Verify directory structure**

```bash
ls ~/.config/writa
```

Expected output includes: `init.lua`, `lua/`, `docs/`, `lazy-lock.json` may or may not be present yet.

```bash
ls ~/.config/writa/docs/specs ~/.config/writa/docs/plans
```

Expected: `2026-04-24-writa-design.md` and `2026-04-24-writa-implementation.md`.

### Task 0.2: Initialize git and make the baseline commit

**Files:**
- Create: `~/.config/writa/.gitignore` (if the template didn't ship one)

- [ ] **Step 1: Initialize git repo**

```bash
cd ~/.config/writa && git init && git branch -m main
```

- [ ] **Step 2: Verify .gitignore covers lazy-lock or add one**

```bash
cat ~/.config/writa/.gitignore 2>/dev/null || echo "no gitignore"
```

If there's no gitignore, create one:

```bash
cat > ~/.config/writa/.gitignore <<'EOF'
# lazy.nvim state
/lazy-lock.json.bak
# editor swap
*.swp
EOF
```

Note: we **do** track `lazy-lock.json` — that's the reproducibility pin.

- [ ] **Step 3: Make baseline commit**

```bash
cd ~/.config/writa && git add -A && git commit -m "chore: initial AstroNvim template"
```

- [ ] **Step 4: Verify commit**

```bash
cd ~/.config/writa && git log --oneline
```

Expected: one commit, "chore: initial AstroNvim template".

### Task 0.3: Bootstrap lazy.nvim and first Lazy sync

**Files:** none changed; this just populates `~/.local/share/writa/`.

- [ ] **Step 1: Launch writa headlessly to trigger lazy bootstrap and plugin install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -40
```

Expected: installs all AstroNvim base plugins. No "E5108" unhandled errors. Warnings about mason packages being missing are fine.

- [ ] **Step 2: Verify writa has its own state directory**

```bash
ls ~/.local/share/writa/lazy | head -5
```

Expected: plugin directories like `astrocore`, `lazy.nvim`, `snacks.nvim`, etc.

- [ ] **Step 3: Interactive boot test**

Run in a terminal:

```bash
NVIM_APPNAME=writa nvim
```

Expected: AstroNvim dashboard loads. No error messages in `:messages`. `:q` to exit.

- [ ] **Step 4: Commit any lockfile changes**

```bash
cd ~/.config/writa && git add -A && git status
```

If `lazy-lock.json` appeared, commit:

```bash
cd ~/.config/writa && git commit -m "chore: initial lazy-lock"
```

---

## Phase 1 — Base

### Task 1.1: Configure astrocore (options, spell, leader)

**Files:**
- Create: `~/.config/writa/lua/plugins/astrocore.lua`

AstroNvim's stock `lua/plugins/astrocore.lua` ships with `if true then return {} end` as a guard. We replace it with an active configuration.

- [ ] **Step 1: Check current state of astrocore.lua**

```bash
head -3 ~/.config/writa/lua/plugins/astrocore.lua
```

Expected: first line is the `if true then return {} end` guard.

- [ ] **Step 2: Write active astrocore config**

Overwrite `~/.config/writa/lua/plugins/astrocore.lua`:

```lua
---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 500, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = true, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = { update_in_insert = false },
    options = {
      opt = {
        spell = true,
        spelllang = "en_us",
        wrap = true,
        linebreak = true,
        breakindent = true,
        conceallevel = 2,
        concealcursor = "",
        relativenumber = true,
        number = true,
        signcolumn = "yes",
        scrolloff = 8,
        undofile = true,
        timeoutlen = 300,
      },
      g = {
        mapleader = " ",
        maplocalleader = ",",
      },
    },
    mappings = {
      n = {
        ["<Leader>W"] = { desc = "Writing" },
      },
    },
  },
}
```

- [ ] **Step 3: Verify Lua syntax**

```bash
NVIM_APPNAME=writa nvim --headless "+luafile ~/.config/writa/lua/plugins/astrocore.lua" "+qa" 2>&1
```

Expected: no output (file parses as a returned table).

- [ ] **Step 4: Boot and confirm leader and spell**

```bash
NVIM_APPNAME=writa nvim --headless "+lua print(vim.g.mapleader, vim.opt.spell:get())" "+qa"
```

Expected: `   true` (space as leader, spell enabled).

- [ ] **Step 5: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/astrocore.lua && git commit -m "feat(astrocore): enable spell, soft-wrap, leader, Writing group"
```

### Task 1.2: Treesitter parsers for writing filetypes

**Files:**
- Create: `~/.config/writa/lua/plugins/treesitter.lua`

- [ ] **Step 1: Write treesitter spec**

```lua
---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = function(_, opts)
    opts.ensure_installed = opts.ensure_installed or {}
    vim.list_extend(opts.ensure_installed, {
      "markdown",
      "markdown_inline",
      "latex",
      "bibtex",
      "org",
      "yaml",
      "toml",
    })
    return opts
  end,
}
```

Note: fountain does not have a treesitter parser upstream; vim-fountain provides vim-regex syntax instead. That is handled in Phase 4.

- [ ] **Step 2: Sync and verify parsers install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+TSUpdateSync" "+qa" 2>&1 | tail -20
```

Expected: parsers install; no errors.

- [ ] **Step 3: Interactive verify**

```bash
NVIM_APPNAME=writa nvim --headless "+lua print(vim.inspect(vim.tbl_keys(require('nvim-treesitter.parsers').get_parser_configs())))" "+qa" 2>&1 | grep -E "markdown|latex|org" | head -5
```

Expected: matches show `markdown`, `latex`, `org` present.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/treesitter.lua lazy-lock.json && git commit -m "feat(treesitter): add markdown, latex, bibtex, org parsers"
```

### Task 1.3: Mason — install ltex-ls and vale-ls

**Files:**
- Create: `~/.config/writa/lua/plugins/mason.lua`

- [ ] **Step 1: Write Mason tool-installer extension**

```lua
---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "ltex-ls",
        "vale-ls",
        "vale",
        "marksman",
      })
      return opts
    end,
  },
}
```

- [ ] **Step 2: Trigger install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+MasonToolsInstall" "+qa" 2>&1 | tail -20
```

Expected: Mason installs the four tools. This may take 30–60 seconds.

- [ ] **Step 3: Verify binaries exist**

```bash
ls ~/.local/share/writa/mason/bin/ | grep -E "ltex|vale|marksman"
```

Expected: at minimum `ltex-ls`, `vale`, `vale-ls`, `marksman` listed.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/mason.lua && git commit -m "feat(mason): install ltex-ls, vale-ls, vale, marksman"
```

### Task 1.4: Configure astrolsp with ltex server

**Files:**
- Create: `~/.config/writa/lua/plugins/astrolsp.lua`

- [ ] **Step 1: Write active astrolsp config**

Overwrite `~/.config/writa/lua/plugins/astrolsp.lua`:

```lua
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    features = {
      codelens = true,
      inlay_hints = false,
      semantic_tokens = true,
    },
    formatting = {
      format_on_save = { enabled = false },
      timeout_ms = 1000,
    },
    config = {
      ltex = {
        filetypes = { "markdown", "text", "tex", "plaintex", "gitcommit", "org" },
        settings = {
          ltex = {
            language = "en-US",
            languageToolHttpServerUri = "https://languagetool.home.lan",
          },
        },
      },
      vale_ls = {
        filetypes = { "markdown", "text", "tex", "org" },
      },
      marksman = {
        filetypes = { "markdown" },
      },
    },
  },
}
```

- [ ] **Step 2: Headless boot test**

```bash
NVIM_APPNAME=writa nvim --headless "+qa" 2>&1
```

Expected: no output (clean boot).

- [ ] **Step 3: Interactive LSP test**

```bash
echo "# Test\n\nThis is a sentence with an teh typo." > /tmp/writa-test.md
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

In the editor:
- Wait 2–3 seconds.
- `:LspInfo`

Expected: shows `ltex`, `vale_ls`, `marksman` attached (or at least starting).
- Diagnostics should appear on the "teh" typo.
- `:q` to exit.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/astrolsp.lua && git commit -m "feat(astrolsp): configure ltex (self-hosted LT), vale-ls, marksman"
```

### Task 1.5: Writing-mode filetype autocmd

**Files:**
- Create: `~/.config/writa/lua/polish.lua` (overwrite template's empty polish)

- [ ] **Step 1: Check current polish**

```bash
cat ~/.config/writa/lua/polish.lua
```

Expected: a near-empty file with guard or just `return function() end`.

- [ ] **Step 2: Write writing_mode autocmd in polish**

Overwrite `~/.config/writa/lua/polish.lua`:

```lua
return function()
  local group = vim.api.nvim_create_augroup("writa_writing_mode", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown", "tex", "plaintex", "org", "fountain", "text" },
    callback = function(args)
      vim.opt_local.spell = true
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
      vim.opt_local.breakindent = true
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = ""
      if args.match == "fountain" then
        vim.opt_local.textwidth = 80
      end
    end,
  })
end
```

- [ ] **Step 3: Verify**

```bash
NVIM_APPNAME=writa nvim --headless /tmp/writa-test.md "+lua print(vim.opt_local.spell:get(), vim.opt_local.linebreak:get())" "+qa"
```

Expected: `true  true`

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/polish.lua && git commit -m "feat(polish): writing_mode autocmd for markdown/tex/org/fountain/text"
```

---

## Phase 2 — Core writing plugins

All plugins in this and subsequent phases live under `lua/plugins/writing/`. Create the directory and a re-export `init.lua` once, then add plugin files.

### Task 2.1: Writing directory scaffold

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/init.lua`

lazy.nvim auto-imports `lua/plugins/*.lua` but does **not** auto-import subdirectories unless you use `{ import = "plugins.writing" }`. We rely on returning the plugin specs from `init.lua` via an aggregator.

- [ ] **Step 1: Create aggregator**

```lua
-- Aggregates all plugin specs in this directory into one LazySpec list.
-- Each file in this directory returns a single plugin spec (a table).
-- Future extraction to astrocommunity: this file becomes the pack entry point.
local M = {}

local files = {
  "ltex",
  "pencil",
  "zen-mode",
  "render-markdown",
  "img-clip",
  "undotree",
  "obsidian",
  "markdown-preview",
  "autolist",
  "fountain",
  "vimtex",
  "pomo",
  "translate",
  "thesaurus",
  "cmp-dictionary",
  "vale",
  "noice",
  "gen",
}

for _, name in ipairs(files) do
  local ok, spec = pcall(require, "plugins.writing." .. name)
  if ok and spec then
    table.insert(M, spec)
  end
end

return M
```

Note: `pcall` means missing files are skipped silently during build-up. This lets us add plugin files phase-by-phase without breaking boot.

- [ ] **Step 2: Headless boot test**

```bash
NVIM_APPNAME=writa nvim --headless "+qa" 2>&1
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/init.lua && git commit -m "feat(writing): scaffold writing plugin directory with aggregator"
```

### Task 2.2: ltex (port from oviwrite)

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/ltex.lua`

The LSP server itself is configured in `astrolsp.lua` (Task 1.4). This file adds `ltex_extra.nvim` for dictionary/code-action persistence.

- [ ] **Step 1: Write ltex_extra spec**

```lua
return {
  "barreiroleo/ltex_extra.nvim",
  ft = { "markdown", "text", "tex", "gitcommit", "org" },
  opts = {
    load_langs = { "en-US" },
    init_check = false,
    path = vim.fn.stdpath "config" .. "/ltex",
  },
  config = function(_, opts)
    require("ltex_extra").setup(opts)
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("ltex_extra_reload", { clear = true }),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and (client.name == "ltex" or client.name == "ltex_plus") then
          vim.schedule(function() require("ltex_extra").reload() end)
        end
      end,
    })
  end,
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -10
```

- [ ] **Step 3: Interactive check**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Wait for ltex to attach (5–10s), then with cursor on a flagged word:
- `<leader>la` or `:lua vim.lsp.buf.code_action()` — should show *Add 'word' to dictionary* among options.
- `:q`

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/ltex.lua lazy-lock.json && git commit -m "feat(writing): add ltex_extra for dictionary code actions"
```

### Task 2.3: pencil (soft-wrap for prose)

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/pencil.lua`

Using `preservim/vim-pencil` — the canonical option. Works fine in neovim despite the name.

- [ ] **Step 1: Write spec**

```lua
return {
  "preservim/vim-pencil",
  ft = { "markdown", "text", "tex", "org", "fountain" },
  init = function()
    vim.g["pencil#wrapModeDefault"] = "soft"
    vim.g["pencil#textwidth"] = 80
    vim.g["pencil#conceallevel"] = 2
  end,
  config = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("writa_pencil", { clear = true }),
      pattern = { "markdown", "text", "tex", "org", "fountain" },
      callback = function() vim.fn["pencil#init"]() end,
    })
  end,
}
```

- [ ] **Step 2: Install & verify**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

In the editor, write a long line. It should soft-wrap without breaking words at screen edge. `:q`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/pencil.lua lazy-lock.json && git commit -m "feat(writing): add vim-pencil for prose soft-wrap"
```

### Task 2.4: zen-mode

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/zen-mode.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "folke/zen-mode.nvim",
  cmd = "ZenMode",
  keys = {
    { "<Leader>Wz", "<cmd>ZenMode<cr>", desc = "Toggle Zen mode" },
  },
  opts = {
    window = {
      width = 90,
      options = {
        number = false,
        relativenumber = false,
        signcolumn = "no",
      },
    },
    plugins = {
      options = { enabled = true, ruler = false, showcmd = false },
      gitsigns = { enabled = true },
      tmux = { enabled = false },
    },
  },
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Interactive check**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Press `<space>Wz`. Expected: centered narrow column, line numbers hidden. Press again to toggle off. `:q`.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/zen-mode.lua lazy-lock.json && git commit -m "feat(writing): add zen-mode with <Leader>Wz"
```

### Task 2.5: render-markdown

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/render-markdown.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    heading = { sign = false },
    code = { sign = false },
    checkbox = {
      unchecked = { icon = "󰄱 " },
      checked = { icon = "󰱒 " },
    },
  },
}
```

- [ ] **Step 2: Install and verify**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Expected: `# Test` displays as styled heading (color, size-effect if supported). `:q`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/render-markdown.lua lazy-lock.json && git commit -m "feat(writing): add render-markdown"
```

### Task 2.6: img-clip

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/img-clip.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "HakonHarnes/img-clip.nvim",
  ft = { "markdown", "tex" },
  keys = {
    { "<Leader>Wi", "<cmd>PasteImage<cr>", desc = "Paste clipboard image" },
  },
  opts = {
    default = {
      dir_path = "assets",
      relative_to_current_file = true,
      prompt_for_file_name = true,
      insert_mode_after_paste = true,
    },
    filetypes = {
      markdown = { template = "![$CURSOR]($FILE_PATH)" },
      tex = { template = "\\includegraphics[width=0.8\\textwidth]{$FILE_PATH}" },
    },
  },
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit** (manual interactive test requires an image in clipboard; skip for CI)

```bash
cd ~/.config/writa && git add lua/plugins/writing/img-clip.lua lazy-lock.json && git commit -m "feat(writing): add img-clip with <Leader>Wi"
```

### Task 2.7: undotree

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/undotree.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "mbbill/undotree",
  cmd = "UndotreeToggle",
  keys = {
    { "<Leader>Wu", "<cmd>UndotreeToggle<cr>", desc = "Toggle undotree" },
  },
  config = function()
    vim.g.undotree_WindowLayout = 2
    vim.g.undotree_SetFocusWhenToggle = 1
  end,
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Interactive test**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Press `<space>Wu`. Expected: undotree panel opens. `:qa`.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/undotree.lua lazy-lock.json && git commit -m "feat(writing): add undotree with <Leader>Wu"
```

---

## Phase 3 — Notes

### Task 3.1: obsidian.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/obsidian.lua`

The user needs to pick a vault path. Default to `~/notes` — the plugin creates it on first use.

- [ ] **Step 1: Write spec**

```lua
return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  cmd = {
    "ObsidianOpen", "ObsidianNew", "ObsidianQuickSwitch", "ObsidianFollowLink",
    "ObsidianBacklinks", "ObsidianTags", "ObsidianToday", "ObsidianYesterday",
    "ObsidianTomorrow", "ObsidianTemplate", "ObsidianSearch", "ObsidianLink",
    "ObsidianLinkNew", "ObsidianWorkspace", "ObsidianPasteImg", "ObsidianRename",
  },
  keys = {
    { "<Leader>Wo", "<cmd>ObsidianQuickSwitch<cr>", desc = "Obsidian quick switch" },
    { "<Leader>Wn", "<cmd>ObsidianNew<cr>", desc = "Obsidian new note" },
    { "<Leader>Wd", "<cmd>ObsidianToday<cr>", desc = "Obsidian today" },
    { "<Leader>Wb", "<cmd>ObsidianBacklinks<cr>", desc = "Obsidian backlinks" },
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      { name = "notes", path = "~/notes" },
    },
    completion = { nvim_cmp = true, min_chars = 2 },
    notes_subdir = "inbox",
    daily_notes = { folder = "daily" },
    new_notes_location = "notes_subdir",
    ui = { enable = false }, -- render-markdown handles display
  },
}
```

Note: `ui.enable = false` prevents obsidian's markdown renderer from fighting with render-markdown.nvim.

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Interactive test**

```bash
mkdir -p ~/notes
NVIM_APPNAME=writa nvim ~/notes
```

Press `<space>Wn`. Expected: prompt for a new note name; creates file under `~/notes/inbox/`. `:qa`.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/obsidian.lua lazy-lock.json && git commit -m "feat(writing): add obsidian.nvim with vault at ~/notes"
```

### Task 3.2: markdown-preview.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/markdown-preview.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
  build = "cd app && yarn install",
  ft = "markdown",
  keys = {
    { "<Leader>Wm", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview toggle" },
  },
  init = function()
    vim.g.mkdp_auto_start = 0
    vim.g.mkdp_auto_close = 1
    vim.g.mkdp_theme = "dark"
  end,
}
```

Note: the `build` step requires `yarn` — if it's missing, the user can use `pnpm install` or `npm install` by editing the build command. We use `yarn` because it's the plugin's documented build command.

- [ ] **Step 2: Check yarn availability**

```bash
which yarn
```

If not present, install (arch): `sudo pacman -S yarn`. Alternative: edit the `build` line to `"cd app && npm install"`.

- [ ] **Step 3: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -10
```

Expected: `yarn install` runs in the plugin dir. No errors.

- [ ] **Step 4: Interactive**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Press `<space>Wm`. Expected: browser opens with preview. Close browser. Press `<space>Wm` again to stop. `:q`.

- [ ] **Step 5: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/markdown-preview.lua lazy-lock.json && git commit -m "feat(writing): add markdown-preview with <Leader>Wm"
```

### Task 3.3: autolist.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/autolist.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "gaoDean/autolist.nvim",
  ft = { "markdown", "text", "tex" },
  config = function()
    require("autolist").setup()
    local map = function(m, lhs, rhs) vim.keymap.set(m, lhs, rhs, { expr = true, buffer = false }) end
    map("i", "<tab>", "<cmd>AutolistTab<cr>")
    map("i", "<s-tab>", "<cmd>AutolistShiftTab<cr>")
    map("i", "<CR>", "<CR><cmd>AutolistNewBullet<cr>")
    map("n", "o", "o<cmd>AutolistNewBullet<cr>")
    map("n", "O", "O<cmd>AutolistNewBulletBefore<cr>")
    map("n", "<CR>", "<cmd>AutolistToggleCheckbox<cr><CR>")
  end,
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Interactive test**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Type `- item one`, press Enter. Expected: next line auto-starts with `- `. `:q!`.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/autolist.lua lazy-lock.json && git commit -m "feat(writing): add autolist for smart list continuation"
```

---

## Phase 4 — Scripts & LaTeX

### Task 4.1: vim-fountain

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/fountain.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "kblin/vim-fountain",
  ft = "fountain",
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Interactive test**

```bash
cat > /tmp/writa-test.fountain <<'EOF'
INT. ROOM - DAY

JACK
(softly)
Hello.
EOF
NVIM_APPNAME=writa nvim /tmp/writa-test.fountain
```

Expected: syntax highlighting on scene heading, character name, parenthetical, dialogue. `:q`.

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/fountain.lua lazy-lock.json && git commit -m "feat(writing): add vim-fountain for screenwriting"
```

### Task 4.2: vimtex

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/vimtex.lua`

- [ ] **Step 1: Check latexmk is installed**

```bash
which latexmk
```

Expected: path printed. If missing, install: `sudo pacman -S texlive-basic texlive-binextra texlive-latexrecommended`.

- [ ] **Step 2: Write spec**

```lua
return {
  "lervag/vimtex",
  ft = { "tex", "plaintex" },
  init = function()
    vim.g.vimtex_view_method = "zathura"
    vim.g.vimtex_compiler_method = "latexmk"
    vim.g.vimtex_quickfix_mode = 0
    vim.g.vimtex_mappings_enabled = 1
    vim.g.vimtex_imaps_enabled = 0 -- let cmp/snippets handle insert-mode maps
  end,
}
```

Note: `vimtex_view_method = "zathura"` matches arch-Linux conventions; change to `"skim"` (macOS) or `"okular"` if needed.

- [ ] **Step 3: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 4: Interactive test**

```bash
cat > /tmp/writa-test.tex <<'EOF'
\documentclass{article}
\begin{document}
Hello, world.
\end{document}
EOF
NVIM_APPNAME=writa nvim /tmp/writa-test.tex
```

Run `:VimtexCompile`. Expected: compiles to PDF in a side process. `:q`.

- [ ] **Step 5: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/vimtex.lua lazy-lock.json && git commit -m "feat(writing): add vimtex with latexmk + zathura"
```

---

## Phase 5 — Workflow

### Task 5.1: pomo.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/pomo.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "epwalsh/pomo.nvim",
  version = "*",
  cmd = { "TimerStart", "TimerRepeat", "TimerSession" },
  keys = {
    { "<Leader>Wp", "<cmd>TimerStart 25m write<cr>", desc = "Pomodoro 25m" },
    { "<Leader>WP", "<cmd>TimerStop<cr>", desc = "Pomodoro stop" },
  },
  dependencies = { "rcarriga/nvim-notify" },
  opts = {},
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/pomo.lua lazy-lock.json && git commit -m "feat(writing): add pomo.nvim with <Leader>Wp"
```

### Task 5.2: translate.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/translate.lua`

Using `uga-rosa/translate.nvim` — well-maintained, works with Google Translate API without keys.

- [ ] **Step 1: Write spec**

```lua
return {
  "uga-rosa/translate.nvim",
  cmd = "Translate",
  keys = {
    { "<Leader>Wtf", "<cmd>Translate FR<cr>", mode = { "n", "v" }, desc = "Translate → French" },
    { "<Leader>Wte", "<cmd>Translate EN<cr>", mode = { "n", "v" }, desc = "Translate → English" },
  },
  opts = {
    default = { command = "google" },
  },
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/translate.lua lazy-lock.json && git commit -m "feat(writing): add translate.nvim"
```

### Task 5.3: thesaurus_query

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/thesaurus.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "Ron89/thesaurus_query.vim",
  cmd = { "Thesaurus", "ThesaurusQueryReplaceCurrentWord" },
  keys = {
    { "<Leader>Ws", "<cmd>ThesaurusQueryReplaceCurrentWord<cr>", desc = "Thesaurus: replace word" },
  },
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/thesaurus.lua lazy-lock.json && git commit -m "feat(writing): add thesaurus_query"
```

### Task 5.4: cmp-dictionary

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/cmp-dictionary.lua`

- [ ] **Step 1: Verify a dictionary file exists**

```bash
ls /usr/share/dict/words 2>/dev/null || ls /usr/share/hunspell/en_US.dic 2>/dev/null
```

If neither present (arch): `sudo pacman -S words`.

- [ ] **Step 2: Write spec**

```lua
return {
  "uga-rosa/cmp-dictionary",
  event = "InsertEnter",
  dependencies = { "hrsh7th/nvim-cmp" },
  config = function()
    local dict = require("cmp_dictionary")
    dict.setup({
      paths = { "/usr/share/dict/words" },
      exact_length = 2,
      first_case_insensitive = true,
    })

    local cmp = require("cmp")
    cmp.setup.filetype({ "markdown", "text", "tex", "org", "fountain" }, {
      sources = cmp.config.sources({
        { name = "dictionary", keyword_length = 2 },
        { name = "buffer" },
        { name = "path" },
      }),
    })
  end,
}
```

- [ ] **Step 3: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/cmp-dictionary.lua lazy-lock.json && git commit -m "feat(writing): add cmp-dictionary for prose completion"
```

### Task 5.5: vale (companion to vale-ls)

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/vale.lua`

`vale-ls` is the LSP (already configured in astrolsp); this file just ensures vale has a config if the user runs it manually via `:!vale %`.

- [ ] **Step 1: Create a minimal .vale.ini template for the user's home dir**

```bash
test -f ~/.vale.ini || cat > ~/.vale.ini <<'EOF'
StylesPath = ~/.local/share/vale/styles
MinAlertLevel = suggestion

Packages = proselint

[*.{md,mdx}]
BasedOnStyles = Vale, proselint
EOF
```

- [ ] **Step 2: Sync vale styles**

```bash
vale sync || echo "vale styles sync failed — run manually later"
```

- [ ] **Step 3: Write a minimal plugin spec (noop — vale runs via vale-ls already)**

Skip the file; vale-ls is already handled in astrolsp. Remove "vale" from the writing aggregator list.

```bash
# Edit the aggregator
sed -i '/"vale",/d' ~/.config/writa/lua/plugins/writing/init.lua
```

- [ ] **Step 4: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/init.lua ~/.vale.ini && git commit -m "feat(writing): configure vale-ls via .vale.ini"
```

### Task 5.6: noice.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/noice.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  opts = {
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  },
}
```

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/noice.lua lazy-lock.json && git commit -m "feat(writing): add noice.nvim"
```

### Task 5.7: gen.nvim

**Files:**
- Create: `~/.config/writa/lua/plugins/writing/gen.lua`

- [ ] **Step 1: Write spec**

```lua
return {
  "David-Kunz/gen.nvim",
  cmd = "Gen",
  keys = {
    { "<Leader>Wg", ":Gen<cr>", mode = { "n", "v" }, desc = "Gen (LLM) menu" },
  },
  opts = {
    model = "llama3.1",
    host = "localhost",
    port = "11434",
    display_mode = "float",
    show_prompt = false,
    show_model = true,
    no_auto_close = false,
  },
}
```

Note: requires ollama running locally on port 11434. User may need to edit `model` to what they have installed.

- [ ] **Step 2: Install**

```bash
NVIM_APPNAME=writa nvim --headless "+Lazy! sync" "+qa" 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/writing/gen.lua lazy-lock.json && git commit -m "feat(writing): add gen.nvim with <Leader>Wg"
```

---

## Phase 6 — Polish

### Task 6.1: Which-key group label & prefix audit

**Files:**
- Modify: `~/.config/writa/lua/plugins/astrocore.lua`

The `<Leader>W` group label was set in Task 1.1. AstroNvim's built-in which-key reads this. This task verifies and enriches it with a few sub-prefixes (translate `Wt`, pomodoro has both `Wp` start / `WP` stop).

- [ ] **Step 1: Add sub-group label for `<Leader>Wt`**

Edit `~/.config/writa/lua/plugins/astrocore.lua`, expand the `mappings.n` block:

Replace the existing `mappings` block with:

```lua
    mappings = {
      n = {
        ["<Leader>W"] = { desc = "Writing" },
        ["<Leader>Wt"] = { desc = "Translate" },
      },
    },
```

- [ ] **Step 2: Verify interactive**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-test.md
```

Press `<space>W`, wait for which-key popup. Expected: labeled entries for z/o/n/d/b/m/i/s/u/p/P/g, and a `+Translate` group. `:q`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config/writa && git add lua/plugins/astrocore.lua && git commit -m "feat(astrocore): label Writing and Translate which-key groups"
```

### Task 6.2: Keymap collision audit

- [ ] **Step 1: Dump all normal-mode `<Leader>W*` mappings**

```bash
NVIM_APPNAME=writa nvim --headless "+redir! > /tmp/writa-maps.txt" "+nmap <Leader>W" "+redir END" "+qa"
cat /tmp/writa-maps.txt
```

Expected: list of `<Leader>Wz`, `<Leader>Wo`, `<Leader>Wn`, `<Leader>Wd`, `<Leader>Wb`, `<Leader>Wm`, `<Leader>Wi`, `<Leader>Ws`, `<Leader>Wu`, `<Leader>Wp`, `<Leader>WP`, `<Leader>Wtf`, `<Leader>Wte`, `<Leader>Wg`. No duplicates.

- [ ] **Step 2: If duplicates found, resolve**

No code changes expected; this task documents the expected map set.

- [ ] **Step 3: Commit (no changes expected; skip if clean)**

### Task 6.3: stylua + selene clean-up

**Files:**
- Create: `~/.config/writa/stylua.toml`
- Create: `~/.config/writa/selene.toml`

- [ ] **Step 1: stylua config**

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "None"
```

- [ ] **Step 2: selene config**

```toml
std = "vim+lua51"
```

Also `~/.config/writa/selene/vim.yml`:

```bash
mkdir -p ~/.config/writa/selene
cat > ~/.config/writa/selene/vim.yml <<'EOF'
base: lua51
name: vim
globals:
  vim:
    any: true
EOF
```

- [ ] **Step 3: Format lua**

```bash
cd ~/.config/writa && stylua lua/ 2>&1 | head
```

Expected: no output (success). If stylua not installed: `cargo install stylua` or use Mason's `stylua`.

- [ ] **Step 4: Lint**

```bash
cd ~/.config/writa && selene lua/ 2>&1 | head
```

Expected: "Results: 0 errors, 0 warnings" (or skipped with a message if not installed).

- [ ] **Step 5: Commit**

```bash
cd ~/.config/writa && git add -A && git commit -m "chore: stylua + selene config and initial formatting"
```

### Task 6.4: README for writa

**Files:**
- Create: `~/.config/writa/README.md`

- [ ] **Step 1: Write a short README**

```markdown
# writa

A Neovim configuration for writing — prose, screenwriting, Markdown notes, LaTeX.

Based on [AstroNvim](https://astronvim.com/). Run via:

```sh
NVIM_APPNAME=writa nvim
```

Recommended alias in your shell rc:

```sh
alias writa='NVIM_APPNAME=writa nvim'
```

## Layout

- `lua/plugins/` — config overrides for the AstroNvim base.
- `lua/plugins/writing/` — writer-specific plugin layer. Future extraction target.
- `docs/specs/` — design docs.
- `docs/plans/` — implementation plans.

## Requirements

- Neovim ≥ 0.10
- `yarn` (for markdown-preview.nvim build)
- `latexmk` + TeX Live (for vimtex)
- A PDF viewer configured in `lua/plugins/writing/vimtex.lua`
- `~/.vale.ini` (created during install)
- A self-hosted LanguageTool server reachable at the URL in `lua/plugins/astrolsp.lua`
```

- [ ] **Step 2: Commit**

```bash
cd ~/.config/writa && git add README.md && git commit -m "docs: add README"
```

---

## Phase 7 — Shakedown

### Task 7.1: End-to-end filetype smoke

- [ ] **Step 1: Create one test file per supported filetype**

```bash
mkdir -p /tmp/writa-shakedown && cd /tmp/writa-shakedown

cat > test.md <<'EOF'
# Markdown test

This has teh typo. And a [link](http://example.com).

- item 1
- item 2
EOF

cat > test.tex <<'EOF'
\documentclass{article}
\begin{document}
A sentence with teh typo.
\end{document}
EOF

cat > test.fountain <<'EOF'
INT. ROOM - DAY

JACK
Hello teh world.
EOF

cat > test.org <<'EOF'
* Heading
  A sentence with teh typo.
EOF
```

- [ ] **Step 2: Open each and verify**

For each file, open in writa, wait 5 seconds, then run `:LspInfo` and check:

```bash
NVIM_APPNAME=writa nvim /tmp/writa-shakedown/test.md
# expect: ltex, vale_ls, marksman attached; diagnostic on "teh"
# :q
NVIM_APPNAME=writa nvim /tmp/writa-shakedown/test.tex
# expect: ltex attached; vimtex commands available (:VimtexCompile)
# :q
NVIM_APPNAME=writa nvim /tmp/writa-shakedown/test.fountain
# expect: fountain syntax colors; pencil soft-wrap active
# :q
NVIM_APPNAME=writa nvim /tmp/writa-shakedown/test.org
# expect: orgmode commands available; ltex attached
# :q
```

- [ ] **Step 3: Zen mode across filetypes**

```bash
NVIM_APPNAME=writa nvim /tmp/writa-shakedown/test.md
```

`<space>Wz` — toggle zen. Expected: centered column, no line numbers, no sign column. Toggle off. `:q`.

### Task 7.2: Shell alias & retirement plan note

- [ ] **Step 1: Detect shell**

```bash
echo $SHELL
```

- [ ] **Step 2: Append alias to shell rc**

If zsh:

```bash
grep -q "alias writa=" ~/.zshrc || echo "alias writa='NVIM_APPNAME=writa nvim'" >> ~/.zshrc
```

If bash:

```bash
grep -q "alias writa=" ~/.bashrc || echo "alias writa='NVIM_APPNAME=writa nvim'" >> ~/.bashrc
```

- [ ] **Step 3: Reload shell and test**

```bash
# In a fresh shell:
writa /tmp/writa-shakedown/test.md
```

Expected: writa opens normally. `:q`.

- [ ] **Step 4: Note about ovi retirement**

Do **not** remove `~/.config/oviwrite/` yet. Use writa for a week. Once confident, delete:

```bash
# Only after confidence:
# rm -rf ~/.config/oviwrite ~/.local/share/oviwrite ~/.local/state/oviwrite ~/.cache/oviwrite
```

### Task 7.3: Final commit

- [ ] **Step 1: Ensure tree is clean**

```bash
cd ~/.config/writa && git status
```

Expected: nothing to commit.

- [ ] **Step 2: Tag phase 7 complete**

```bash
cd ~/.config/writa && git tag v0.1.0
```

- [ ] **Step 3: Verify**

```bash
cd ~/.config/writa && git log --oneline
```

Expected: ~20 commits, clean history, v0.1.0 tag on HEAD.

---

## Deferred for a future spec

- Extract `lua/plugins/writing/` into a public `astrocommunity.writing` pack repo.
- Decide on snippets plugin (luasnip config for prose).
- BibTex / Zotero integration.
- Typst filetype support.
- Inkscape-figures or other figure workflow for LaTeX.
