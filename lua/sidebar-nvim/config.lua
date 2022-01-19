local M = {}

M.disable_default_keybindings = 0
M.bindings = nil
M.side = "left"
M.initial_width = 35

M.hide_statusline = false

M.update_interval = 1000

M.enable_profile = false

M.sections = { "datetime", "git", "diagnostics" }

M.section_separator = { "", "-----", "" }

M.git = { icon = "" }

M.diagnostics = { icon = "" }

M.buffers = { icon = "", ignored_buffers = {} }

M.symbols = { icon = "ƒ" }

M.containers = { icon = "", use_podman = false, attach_shell = "/bin/sh", show_all = true, interval = 5000 }

M.datetime = { icon = "", format = "%a %b %d, %H:%M", clocks = { { name = "local" } } }

M.todos = { icon = "", ignored_paths = { "~" }, initially_closed = false }

M.files = { icon = "", show_hidden = false }

M.disable_closing_prompt = false

return M
