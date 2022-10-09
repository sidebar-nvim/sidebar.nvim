local luv = vim.loop

local M = {}

function M.autocmd(event_name, pattern)
    return function(augroup_id, cb)
        local autocmd = {
            pattern = pattern,
            group = augroup_id,
            callback = cb,
        }
        vim.api.nvim_create_autocmd(event_name, autocmd)
    end
end

function M.file_changed(file_list)
    return M.autocmd("BufWritePost", vim.tbl_flatten({ file_list }))
end

function M.interval(interval)
    return function(_, cb)
        local timer = luv.new_timer()
        timer:start(interval, interval, cb)
    end
end

return M
