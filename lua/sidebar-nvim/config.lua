
local M = {}

M.disable_default_keybindings = 0
M.bindings = nil
M.side = "left"
M.initial_width = 50

M.update_interval = 1000

M.sections = {
  "datetime",
  "git-status",
  "diagnostics",
}

return M
