local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local utils = require("sidebar-nvim.utils")

local loclist = Loclist:new({
  indent = " ",
})

local use_icons = true
local icons = { "", "", "", "" }
local severity_level = { "Error", "Warning", "Info", "Hint" }
local severity_level_coc_to_native = {
  Error       = 1,
  Warning     = 2,
  Information = 3,
  Hint        = 4,
}

local use_coc = vim.fn.exists("*CocAction") == 1

local function get_diagnostics_native()
    local result = vim.diagnostic.get()
    for _, diag in ipairs(result) do
        diag.file = vim.api.nvim_buf_get_name(diag.bufnr)
    end
    return result
end

local function get_diagnostics_coc()
    local ok, result = pcall(vim.fn.CocAction, 'diagnosticList')
    if not ok or type(result) ~= "table" then
        return {}
    end

    -- Example:
    --
    -- {
    --   'file': '/home/user/src/sidebar.nvim/lua/sidebar-nvim/builtin/git.lua',
    --   'lnum': 172,
    --   'end_lnum': 172,
    --   'location': {'uri': 'file:///home/user/src/sidebar.nvim/lua/sidebar-nvim/builtin/git.lua', 'range': {'end': {'character': 63, 'line': 171}, 'start': {'character': 46, 'line': 171}}},
    --   'source': 'Lua Diagnostics.',
    --   'code': 'unknown-diag-code',
    --   'level': 0,
    --   'message': 'Unknown diagnostic code `missing-parameter`.',
    --   'end_col': 64,
    --   'col': 47,
    --   'severity': 'Error',
    -- }

    for _, diag in ipairs(result) do
        diag.severity = severity_level_coc_to_native[diag.severity]
    end
    return result
end

local function ingest_diagnostics(all_diagnostics)
    local current_buf = vim.api.nvim_get_current_buf()
    local current_buf_filepath = vim.api.nvim_buf_get_name(current_buf)
    local current_buf_filename = vim.fn.fnamemodify(current_buf_filepath or '', ":t")

    local loclist_items = {}

    for _, diag in pairs(all_diagnostics) do
        local filepath = diag.file
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
                    text = tostring(diag.lnum + 1) .. ' ',
                    hl = "SidebarNvimLspDiagnosticsLineNumber",
                },
                { text = message },
            },
            lnum = diag.lnum + 1,
            col = diag.col + 1,
            filepath = filepath,
        })
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

local function get_diagnostics()
  local diagnostics =
    use_coc
      and get_diagnostics_coc()
       or get_diagnostics_native()
  ingest_diagnostics(diagnostics)
end

return {
    title = "Diagnostics",
    icon = config["diagnostics"].icon,
    setup = function(_)
        if use_coc then
            vim.api.nvim_exec([[
                augroup sidebar_nvim_diagnostics_update
                    autocmd!
                    autocmd User CocDiagnosticChange lua require'sidebar-nvim.builtin.diagnostics'.update()
                augroup END
            ]], false)
        else
            vim.api.nvim_exec([[
                augroup sidebar_nvim_diagnostics_update
                    autocmd!
                    autocmd DiagnosticChanged * lua require'sidebar-nvim.builtin.diagnostics'.update()
                augroup END
            ]], false)
            get_diagnostics()
        end
    end,
    update = function(_)
        get_diagnostics()
    end,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if lines == nil or #lines == 0 then
            return utils.empty_message("<no diagnostics>")
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
