local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")

local loclist = Loclist:new({ ommit_single_group = true })
local loclist_items = {}
local open_symbols = {}

local kinds = {
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
}
local function build_loclist(symbols, level)
    table.sort(symbols, function(a, b)
        return a.range.start.line < b.range.start.line
    end)

    for _, symbol in ipairs(symbols) do
        local kind = kinds[symbol.kind]
        loclist_items[#loclist_items + 1] = {
            group = "symbols",
            left = {
                { text = string.rep(" ", level) .. kind.text, hl = kind.hl },
                { text = symbol.name .. " ", hl = "SidebarNvimSymbolsName" },
                { text = symbol.detail, hl = "SidebarNvimSymbolsDetail" },
            },
            right = {},
            data = { symbol = symbol },
        }

        -- uses a unique key for each symbol appending the name and position
        if symbol.children and open_symbols[symbol.name .. symbol.range.start.line .. symbol.range.start.character] then
            build_loclist(symbol.children, level + 1)
        end
    end
end

local function get_symbols(ctx)
    local lines = {}
    local hl = {}

    vim.lsp.buf_request(
        vim.api.nvim_get_current_buf(),
        "textDocument/documentSymbol",
        vim.lsp.util.make_position_params(),
        -- function(err, method, result, client_id, bufnr, config)
        function(err, _, symbols, _, _, _)
            loclist_items = {}
            if err ~= nil then
                return
            end

            build_loclist(symbols, 1)

            -- error(vim.inspect(result))
        end
    )

    -- FIX: there is no guarantee the callback will have executed before this point, so loclist will problably have items from the last update
    loclist:set_items(loclist_items, { remove_groups = false })
    loclist:draw(ctx, lines, hl)

    if lines == nil or #lines == 0 then
        return "<no symbols>"
    else
        return { lines = lines, hl = hl }
    end
end

return {
    title = "Symbols",
    icon = config["symbols"].icon,
    draw = function(ctx)
        return get_symbols(ctx)
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimSymbolsName = "SidebarNvimNormal",
            SidebarNvimSymbolsDetail = "SidebarNvimLineNr",
        },
    },
    bindings = {
        ["t"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            local symbol = location.data.symbol
            local key = symbol.name .. symbol.range.start.line .. symbol.range.start.character

            if open_symbols[key] == nil then
                open_symbols[key] = true
            else
                open_symbols[key] = nil
            end
        end,
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            local symbol = location.data.symbol

            vim.cmd("wincmd p")
            vim.cmd("e " .. location.filepath)
            vim.fn.cursor(symbol.range.start.line, symbol.range.start.character)
        end,
    },
}
