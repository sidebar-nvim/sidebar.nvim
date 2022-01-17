local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")

local loclist = Loclist:new({})

local severity_level = { "Error", "Warning", "Info", "Hint" }
local icons = { "", "", "", "" }
local use_icons = true

local function get_diagnostics()
    local current_buf = vim.api.nvim_get_current_buf()
    local current_buf_filepath = vim.api.nvim_buf_get_name(current_buf)
    local current_buf_filename = vim.fn.fnamemodify(current_buf_filepath, ":t")

    local open_bufs = vim.api.nvim_list_bufs()

    local all_diagnostics = vim.diagnostic.get()
    local loclist_items = {}

    for _, diag in pairs(all_diagnostics) do
        local bufnr = diag.bufnr
        if open_bufs[bufnr] ~= nil and vim.api.nvim_buf_is_loaded(bufnr) then
            local filepath = vim.api.nvim_buf_get_name(bufnr)
            local filename = vim.fn.fnamemodify(filepath, ":t")

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
                left = {
                    { text = icon .. " ", hl = "SidebarNvimLspDiagnostics" .. level },
                    {
                        text = diag.lnum + 1,
                        hl = "SidebarNvimLspDiagnosticsLineNumber",
                    },
                    { text = ":" },
                    {
                        text = (diag.col + 1) .. " ",
                        hl = "SidebarNvimLspDiagnosticsColNumber",
                    },
                    { text = message },
                },
                lnum = diag.lnum + 1,
                col = diag.col + 1,
                filepath = filepath,
            })
        end
    end

    local previous_state = vim.tbl_map(function(group)
        return group.is_closed
    end, loclist.groups)

    loclist:set_items(loclist_items, { remove_groups = true })
    loclist:close_all_groups()

    for group_name, is_closed in pairs(previous_state) do
        if loclist.groups[group_name] ~= nil then
            loclist.groups[group_name].is_closed = is_closed
        end
    end

    if loclist.groups[current_buf_filename] ~= nil then
        loclist.groups[current_buf_filename].is_closed = false
    end
end

return {
    title = "Diagnostics",
    icon = config["diagnostics"].icon,
    setup = function(_)
        vim.api.nvim_exec(
            [[
          augroup sidebar_nvim_diagnostics_update
              autocmd!
              autocmd DiagnosticChanged * lua require'sidebar-nvim.builtin.diagnostics'.update()
          augroup END
          ]],
            false
        )

        get_diagnostics()
    end,
    update = function(_)
        get_diagnostics()
    end,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if lines == nil or #lines == 0 then
            return "<no diagnostics>"
        else
            return { lines = lines, hl = hl }
        end
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimLspDiagnosticsError = "LspDiagnosticsDefaultError",
            SidebarNvimLspDiagnosticsWarning = "LspDiagnosticsDefaultWarning",
            SidebarNvimLspDiagnosticsInfo = "LspDiagnosticsDefaultInformation",
            SidebarNvimLspDiagnosticsHint = "LspDiagnosticsDefaultHint",
            SidebarNvimLspDiagnosticsLineNumber = "SidebarNvimLineNr",
            SidebarNvimLspDiagnosticsColNumber = "SidebarNvimLineNr",
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
