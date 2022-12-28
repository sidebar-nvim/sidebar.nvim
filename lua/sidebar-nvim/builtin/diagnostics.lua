local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Loclist = require("sidebar-nvim.lib.loclist")

local api = async.api

local diagnostics = Section:new({
    title = "Diagnostics",
    icon = "",

    severity_level = { "Error", "Warning", "Info", "Hint" },
    icons = { "", "", "", "" },
    use_icons = true,

    reloaders = { reloaders.autocmd({ "DiagnosticChanged", "BufEnter" }, "*") },

    opened_groups = {},

    keymaps = {
        file_toggle = "t",
        file_edit = "e",
    },

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
})

function diagnostics:file_toggle(filepath)
    local filename = vim.fs.basename(filepath)
    if self.opened_groups[filename] then
        self.opened_groups[filename] = nil
    else
        self.opened_groups[filename] = true
    end
end

function diagnostics:file_edit(filepath, location)
    vim.cmd("wincmd p")
    vim.cmd("e " .. filepath)
    vim.api.nvim_win_set_cursor(0, { location.lnum, location.col })
end

function diagnostics:draw_content(ctx)
    local groups = {}

    local current_buf = api.nvim_get_current_buf()
    local current_buf_filepath = api.nvim_buf_get_name(current_buf)
    local current_buf_filename = vim.fs.basename(current_buf_filepath)

    local open_bufs = api.nvim_list_bufs()

    local all_diagnostics = vim.diagnostic.get()

    for _, diag in pairs(all_diagnostics) do
        local bufnr = diag.bufnr
        if open_bufs[bufnr] ~= nil and api.nvim_buf_is_loaded(bufnr) then
            local filepath = api.nvim_buf_get_name(bufnr)
            local filename = vim.fs.basename(filepath)

            local is_current_file_opened = current_buf_filename == filename

            local message = diag.message
            message = message:gsub("\n", " ")

            local severity = diag.severity
            local level = self.severity_level[severity]
            local icon = self.icons[severity]

            if not self.use_icons then
                icon = level
            end

            groups[filename] = groups[filename]
                or {
                    items = {},
                    is_closed = not is_current_file_opened and not self.opened_groups[filename],
                    keymaps = self:bind_keymaps({ filepath }, { filter = { "file_toggle" } }),
                }

            table.insert(
                groups[filename].items,
                LineBuilder:new({
                    keymaps = self:bind_keymaps({
                        filepath,
                        {

                            lnum = diag.lnum + 1,
                            col = diag.col + 1,
                        },
                    }, { filter = { "file_edit" } }),
                })
                    :left(icon .. " ", "SidebarNvimLspDiagnostics" .. level)
                    :left(diag.lnum + 1, "SidebarNvimLspDiagnosticsLineNumber")
                    :left(":")
                    :left((diag.col + 1) .. " ", "SidebarNvimLspDiagnosticsColNumber")
                    :left(message)
            )
        end
    end

    -- forget filenames without diagnostics
    for _, filepath in ipairs(vim.tbl_keys(self.opened_groups)) do
        local filename = vim.fs.basename(filepath)
        if groups[filename] == nil then
            self.opened_groups[filename] = nil
        end
    end

    local loclist = Loclist:new(groups)

    return loclist:draw()
end

return diagnostics
