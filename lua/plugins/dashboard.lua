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
        keys = {
          { icon = " ", key = "w", desc = "New Project",  action = ":WritaNewProject" },
          { icon = " ", key = "W", desc = "Open Project", action = ":WritaOpenProject" },
          { icon = " ", key = "f", desc = "Find File",    action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File",     action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text",    action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config",       action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = "󰒲 ", key = "L", desc = "Lazy",        action = ":Lazy",          enabled = package.loaded.lazy ~= nil },
          { icon = " ", key = "q", desc = "Quit",         action = ":qa" },
        },
      },
    },
  },
}
