local pasync = require("plenary.async")

local M = {}

local helpers = {}

setmetatable(M, {
    __index = function(_, key)
        if helpers[key] ~= nil then
            return helpers[key]
        end

        return pasync[key]
    end,
})

-- https://github.com/nvim-lua/plenary.nvim/pull/293
helpers.api = setmetatable({}, {
    __index = function(t, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                pasync.util.scheduler()
            end

            return vim.api[k](...)
        end
    end,
})

-- https://github.com/nvim-lua/plenary.nvim/pull/298
helpers.fn = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                pasync.util.scheduler()
            end

            return vim.fn[k](...)
        end
    end,
})

helpers.cmd = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                pasync.util.scheduler()
            end

            return vim.cmd[k](...)
        end
    end,
})

return M
