-- Headless test bootstrap. Adds the writa repo + plenary to runtimepath.

local repo_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
vim.opt.rtp:prepend(repo_root)

local plenary = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.rtp:prepend(plenary)
end

vim.cmd("runtime plugin/plenary.vim")
