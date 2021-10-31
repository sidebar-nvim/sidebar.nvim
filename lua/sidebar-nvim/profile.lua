local config = require("sidebar-nvim.config")

local M = {}

M.entries = {}

function M.clear()
    M.entries = {}
end

function M.add_point(name, value, unit)
    M.entries[name] = { value = value, unit = unit }
end

function M.run(name, fn, ...)
    if not config.enable_profile then
        return fn(...)
    end

    local time_before = vim.loop.hrtime()

    local ret = { fn(...) }

    local duration = vim.loop.hrtime() - time_before

    M.add_point(name, duration, "ns")

    return unpack(ret)
end

function M.wrap_fn(name, fn)
    return function(...)
        return M.run(name, fn, ...)
    end
end

function M.print_summary(filter)
    local filtered_keys = vim.tbl_keys(M.entries)

    if filter then
        filtered_keys = vim.tbl_filter(function(entry)
            return vim.tbl_contains(filter, entry)
        end, vim.tbl_keys(
            M.entries
        ))
    end

    local entries = {}
    for _, key in ipairs(filtered_keys) do
        table.insert(entries, vim.tbl_deep_extend("force", { name = key }, M.entries[key]))
    end

    -- TODO: convert units

    table.sort(entries, function(a, b)
        -- reverse sort
        return a.value > b.value
    end)

    for _, entry in ipairs(entries) do
        print(string.format("Name: %s Value: %f", entry.name, entry.value / 1000000))
    end
end

return M
