local M = {}

M.disable_default_keybindings = 0
M.bindings = nil
M.side = "left"
M.initial_width = 35

M.hide_statusline = false

M.update_interval = 1000

M.enable_profile = false

M.sections = { default = { "datetime", "git", "diagnostics" } }

M.section_separator = { "", "-----", "" }

M.section_title_separator = { "" }

M.git = { icon = "" }

M.diagnostics = { icon = "" }

M.symbols = { icon = "ƒ" }

M.containers = { icon = "", use_podman = false, attach_shell = "/bin/sh", show_all = true, interval = 5000 }

M.files = { icon = "", show_hidden = false, ignored_paths = { "%.git$" } }

return M
