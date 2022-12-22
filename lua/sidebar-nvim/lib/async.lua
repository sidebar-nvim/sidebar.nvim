local async = require("plenary.async")

local M = {}

local helpers = {}

setmetatable(M, {
    __index = function(_, key)
        if helpers[key] ~= nil then
            return helpers[key]
        end

        return async[key]
    end,
})

-- https://github.com/nvim-lua/plenary.nvim/pull/293
helpers.api = setmetatable({}, {
    __index = function(t, k)
        return function(...)
            -- if we are in a fast event await the scheduler
            if vim.in_fast_event() then
                async.util.scheduler()
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
                async.util.scheduler()
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
                async.util.scheduler()
            end

            return vim.cmd[k](...)
        end
    end,
})

helpers.fs = {
    read_file = function(filename)
        local err, fd = async.uv.fs_open(filename, "r", 438)
        assert(not err, err)

        local stat
        err, stat = async.uv.fs_fstat(fd)
        assert(not err, err)

        local data
        err, data = async.uv.fs_read(fd, stat.size, 0)
        assert(not err, err)

        err = async.uv.fs_close(fd)
        assert(not err, err)

        return data
    end,

    write_file = function(filename, data)
        local err, fd = async.uv.fs_open(filename, "w", 438)
        assert(not err, err)

        err = async.uv.fs_write(fd, data)
        assert(not err, err)

        err = async.uv.fs_close(fd)
        assert(not err, err)
    end,
}

return M
