local M = {}

M.enable_profile = false

M.views = {
    default = {
        -- sections = { "datetime", "git", "diagnostics" },
        sections = { "datetime", "git" },
        winopts = {
            position = "left",
            width = 35,
            hide_statusline = false,
        },
    },
}

M.section_separator = { "", "-----", "" }

M.section_title_separator = { "" }

M.containers = { icon = "", use_podman = false, attach_shell = "/bin/sh", show_all = true, interval = 5000 }

return M
