---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = table.concat({
          [[                _ _        ]],
          [[__      ___ __(_) |_ __ _ ]],
          [[\ \ /\ / / '__| | __/ _` |]],
          [[ \ V  V /| |  | | || (_| |]],
          [[  \_/\_/ |_|  |_|\__\__,_|]],
        }, "\n"),
      },
    },
  },
}
