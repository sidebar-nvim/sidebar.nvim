local M = {}

M.enable_profile = false

M.views = {
    default = {
        sections = { "datetime", "git", "diagnostics" },
        winopts = {
            position = "left",
            width = 35,
            hide_statusline = false,
        },
    },
}

M.section_separator = { "", "-----", "" }

M.section_title_separator = { "" }

M.git = { icon = "" }

M.diagnostics = { icon = "" }

M.symbols = { icon = "ƒ" }

M.containers = { icon = "", use_podman = false, attach_shell = "/bin/sh", show_all = true, interval = 5000 }

return M
