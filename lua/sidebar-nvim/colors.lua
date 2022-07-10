local api = vim.api

local M = {}

local function get_hl_groups()
    return {}
end

local function get_links()
    return {
        SidebarNvimSectionTitle = "Directory",
        SidebarNvimSectionSeparator = "VertSplit",
        SidebarNvimSectionTitleSeperator = "Comment",
        SidebarNvimNormal = "Normal",
        SidebarNvimLabel = "Label",
        SidebarNvimComment = "Comment",
        SidebarNvimLineNr = "LineNr",
        SidebarNvimKeyword = "Keyword",
    }
end

function M.def_hl_group(group, gui, fg, bg)
    gui = gui and " gui=" .. gui or ""
    fg = fg and " guifg=" .. fg or ""
    bg = bg and " guibg=" .. bg or ""

    api.nvim_command("hi def " .. group .. gui .. fg .. bg)
end

function M.def_hl_link(group, link_to)
    api.nvim_command("hi def link " .. group .. " " .. link_to)
end

function M.setup()
    local higlight_groups = get_hl_groups()
    for k, d in pairs(higlight_groups) do
        M.def_hl_group(k, d.gui, d.fg, d.bg)
    end

    local links = get_links()
    for k, d in pairs(links) do
        M.def_hl_link(k, d)
    end
end

return M
