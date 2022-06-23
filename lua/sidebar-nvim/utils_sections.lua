local utils = require("sidebar-nvim.utils")
local config = require("sidebar-nvim.config")

local M = {}

function M.section_iterator()
    local i = 0
    return function()
        i = i + 1
        if i <= #config.sections then
            local section = utils.resolve_section(i, config.sections[i])
            return i, section
        end
    end
end

function M.get_section_at_index(index)
    return utils.resolve_section(index, config.sections[index])
end

return M
