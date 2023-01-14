local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Loclist = require("sidebar-nvim.lib.loclist")
local logger = require("sidebar-nvim.logger")

local api = async.api

local function get_range(s)
    return s.range or s.location.range
end

local Symbols = Section:new({
    title = "Symbols",
    icon = "ƒ",

    reloaders = { reloaders.autocmd({ "InsertLeave" }, "*") },

    opened_symbols = {},
    last_buffer = nil,
    last_pos = nil,

    keymaps = {
        symbol_toggle = "t",
        file_edit = "e",
    },

    kinds = {
        { text = " ", hl = "TSURI" },
        { text = " ", hl = "TSNamespace" },
        { text = " ", hl = "TSNamespace" },
        { text = " ", hl = "TSNamespace" },
        { text = "𝓒 ", hl = "TSType" },
        { text = "ƒ ", hl = "TSMethod" },
        { text = " ", hl = "TSMethod" },
        { text = " ", hl = "TSField" },
        { text = " ", hl = "TSConstructor" },
        { text = "ℰ ", hl = "TSType" },
        { text = "ﰮ ", hl = "TSType" },
        { text = " ", hl = "TSFunction" },
        { text = " ", hl = "TSConstant" },
        { text = " ", hl = "TSConstant" },
        { text = "𝓐 ", hl = "TSString" },
        { text = "# ", hl = "TSNumber" },
        { text = "⊨ ", hl = "TSBoolean" },
        { text = " ", hl = "TSConstant" },
        { text = "⦿ ", hl = "TSType" },
        { text = " ", hl = "TSType" },
        { text = "NULL ", hl = "TSType" },
        { text = " ", hl = "TSField" },
        { text = "𝓢 ", hl = "TSType" },
        { text = "🗲 ", hl = "TSType" },
        { text = "+ ", hl = "TSOperator" },
        { text = "𝙏 ", hl = "TSParameter" },
    },

    highlights = {
        groups = {},
        links = {
            SidebarNvimSymbolsName = "SidebarNvimNormal",
            SidebarNvimSymbolsDetail = "SidebarNvimLineNr",
        },
    },
})

function Symbols:symbol_toggle(_, symbol)
    local key = symbol.name .. symbol.range.start.line .. symbol.range.start.character

    if self.opened_symbols[key] == nil then
        self.opened_symbols[key] = true
    else
        self.opened_symbols[key] = nil
    end
end

function Symbols:file_edit(filepath, symbol)
    vim.cmd("wincmd p")
    vim.cmd("e " .. filepath)
    vim.api.nvim_win_set_cursor(0, { symbol.range.start.line, symbol.range.start.character })
end

function Symbols:build_loclist(filepath, loclist_items, symbols, level)
    table.sort(symbols, function(a, _)
        return get_range(a).start.line < get_range(a).start.line
    end)

    for _, symbol in ipairs(symbols) do
        local kind = self.kinds[symbol.kind]
        table.insert(
            loclist_items,
            LineBuilder:new({ keymaps = self:bind_keymaps({ filepath, symbol }) })
                :left(string.rep(" ", level) .. kind.text, kind.hl)
                :left(symbol.name .. " ", "SidebarNvimSymbolsName")
                :left(symbol.detail, "SidebarNvimSymbolsDetail")
        )

        -- uses a unique key for each symbol appending the name and position
        if
            symbol.children
            and self.opened_symbols[symbol.name .. symbol.range.start.line .. symbol.range.start.character]
        then
            self:build_loclist(filepath, loclist_items, symbol.children, level + 1)
        end
    end

    return loclist_items
end

function Symbols:draw_content(ctx)
    local current_buf = api.nvim_get_current_buf()
    local current_pos = vim.lsp.util.make_position_params()

    local no_symbols_view = { LineBuilder:new():left("<no symbols>") }

    -- if current buffer is sidebar's own buffer, use previous buffer
    if current_buf ~= ctx.view:get_bufnr() then
        self.last_buffer = current_buf
        self.last_pos = current_pos
    else
        current_buf = self.last_buffer
        current_pos = self.last_pos
    end

    if
        current_buf == ctx.view:get_bufnr()
        or not current_buf
        or not api.nvim_buf_is_loaded(current_buf)
        or api.nvim_buf_get_option(current_buf, "buftype") ~= ""
    then
        return no_symbols_view
    end

    local clients = vim.lsp.buf_get_clients(current_buf)
    local clients_filtered = vim.tbl_filter(function(client)
        return client.supports_method("textDocument/documentSymbol")
    end, clients)

    if #clients_filtered == 0 then
        return no_symbols_view
    end

    local err, method, symbols = async.lsp.buf_request_all(current_buf, "textDocument/documentSymbol", current_pos)

    if vim.fn.has("nvim-0.5.1") == 1 or vim.fn.has("nvim-0.8") == 1 then
        symbols = method
    end

    local filepath = vim.api.nvim_buf_get_name(current_buf)
    if err ~= nil then
        logger:error("error trying to get symbols: " .. tostring(err), { err = err })
        return no_symbols_view
    end

    if symbols == nil then
        return no_symbols_view
    end

    local loclist = Loclist:new(
        { symbols = {
            items = self:build_loclist(filepath, {}, symbols, 1),
        } },
        { omit_single_group = true }
    )

    return loclist:draw()
end

return Symbols
