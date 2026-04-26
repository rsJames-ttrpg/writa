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
        filetypes = { "markdown", "text", "tex", "plaintex", "gitcommit" },
        settings = {
          ltex = {
            language = "en-US",
            languageToolHttpServerUri = "https://languagetool.home.lan",
          },
        },
      },
      vale_ls = {
        filetypes = { "markdown", "text", "tex" },
      },
      marksman = {
        filetypes = { "markdown" },
      },
      yamlls = {
        settings = {
          yaml = {
            schemas = {
              [vim.fn.stdpath("config") .. "/schema/project-type/v1.json"] = {
                "project-types/**/*.yaml",
                ".writa-project.yaml",
              },
            },
          },
        },
      },
    },
  },
}
