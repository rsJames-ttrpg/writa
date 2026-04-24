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
