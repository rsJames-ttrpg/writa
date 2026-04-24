return {
  "barreiroleo/ltex_extra.nvim",
  ft = { "markdown", "text", "tex", "gitcommit" },
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
