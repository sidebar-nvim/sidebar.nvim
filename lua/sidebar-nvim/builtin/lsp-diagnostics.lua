local Loclist = require("sidebar-nvim.components.loclist")

local loclist = Loclist:new({
    highlights = {
        group = "SidebarNvimLspDiagnosticsFilename",
        group_count = "SidebarNvimLspDiagnosticsTotalNumber",
        item_text = "SidebarNvimLspDiagnosticsMessage",
        item_lnum = "SidebarNvimLspDiagnosticsLineNumber",
        item_col = "SidebarNvimLspDiagnosticsColNumber",
    },
})

local severity_level = { "Error", "Warning", "Info", "Hint" }
local icons = { "", "", "", "" }
local use_icons = true

local function get_diagnostics(ctx)
    local lines = {}
    local hl = {}

    local current_buf = vim.api.nvim_get_current_buf()
    local current_buf_filepath = vim.api.nvim_buf_get_name(current_buf)
    local current_buf_filename = vim.fn.fnamemodify(current_buf_filepath, ":t")

    local open_bufs = vim.api.nvim_list_bufs()

    local all_diagnostics = vim.lsp.diagnostic.get_all()
    local loclist_items = {}

    for bufnr, buffer_diagnostics in pairs(all_diagnostics) do
        if open_bufs[bufnr] ~= nil and vim.api.nvim_buf_is_loaded(bufnr) then
            local filepath = vim.api.nvim_buf_get_name(bufnr)
            local filename = vim.fn.fnamemodify(filepath, ":t")

            for _, diag in pairs(buffer_diagnostics) do
                local message = diag.message
                message = message:gsub("\n", " ")

                local severity = diag.severity
                local level = severity_level[severity]
                local icon = icons[severity]
                if not use_icons then
                    icon = level
                end

                table.insert(loclist_items, {
                    group = filename,
                    text = message,
                    icon = { hl = "SidebarNvimLspDiagnostics" .. level, text = icon },
                    lnum = diag.range.start.line + 1,
                    col = diag.range.start.character + 1,
                    filepath = filepath,
                })
            end
        end
    end

    local previous_state = vim.tbl_map(function(group)
        return group.is_closed
    end, loclist.groups)

    loclist:set_items(loclist_items)
    loclist:close_all_groups()

    for group_name, is_closed in pairs(previous_state) do
        if loclist.groups[group_name] ~= nil then
            loclist.groups[group_name].is_closed = is_closed
        end
    end

    if loclist.groups[current_buf_filename] ~= nil then
        loclist.groups[current_buf_filename].is_closed = false
    end

    loclist:draw(ctx, lines, hl)

    if lines == nil or #lines == 0 then
        return "<no diagnostics>"
    else
        return { lines = lines, hl = hl }
    end
end

return {
    title = "Diagnostics",
    icon = "📄",
    draw = function(ctx)
        return get_diagnostics(ctx)
    end,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        links = {
            SidebarNvimLspDiagnosticsError = "LspDiagnosticsDefaultError",
            SidebarNvimLspDiagnosticsWarn = "LspDiagnosticsDefaultWarning",
            SidebarNvimLspDiagnosticsInfo = "LspDiagnosticsDefaultInformation",
            SidebarNvimLspDiagnosticsHint = "LspDiagnosticsDefaultHint",
            SidebarNvimLspDiagnosticsLineNumber = "SidebarNvimLineNr",
            SidebarNvimLspDiagnosticsColNumber = "SidebarNvimLineNr",
            SidebarNvimLspDiagnosticsFilename = "SidebarNvimLabel",
            SidebarNvimLspDiagnosticsTotalNumber = "LspTroubleCount",
            SidebarNvimLspDiagnosticsMessage = "SidebarNvimNormal",
        },
    },
    bindings = {
        ["t"] = function(line)
            loclist:toggle_group_at(line)
        end,
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            -- TODO: I believe there is a better way to do this, but I haven't had the time to do investigate
            vim.cmd("wincmd p")
            vim.cmd("e " .. location.filepath)
            vim.fn.cursor(location.lnum, location.col)
        end,
    },
}
