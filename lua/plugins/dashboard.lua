---@type LazySpec
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}

    opts.dashboard.preset.header = table.concat({
      [[                _ _        ]],
      [[__      ___ __(_) |_ __ _ ]],
      [[\ \ /\ / / '__| | __/ _` |]],
      [[ \ V  V /| |  | | || (_| |]],
      [[  \_/\_/ |_|  |_|\__\__,_|]],
    }, "\n")

    local existing = opts.dashboard.preset.keys or {}
    local filtered = {}
    for _, k in ipairs(existing) do
      if k.key ~= "w" and k.key ~= "W" then
        table.insert(filtered, k)
      end
    end
    table.insert(filtered, 1, { icon = " ", key = "W", desc = "Open Project", action = ":WritaOpenProject" })
    table.insert(filtered, 1, { icon = " ", key = "w", desc = "New Project", action = ":WritaNewProject" })
    opts.dashboard.preset.keys = filtered
  end,
}
