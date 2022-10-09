local LineBuilderProps = {
    current = {
        left = {},
        right = {},
    },
}

local LineBuilder = {}

LineBuilder.__index = LineBuilder

function LineBuilder:new()
    local obj = vim.deepcopy(LineBuilderProps)

    obj = setmetatable(obj, self)

    return obj
end

function LineBuilder:empty()
    return LineBuilder:new():left("")
end

function LineBuilder:left(text, hl)
    table.insert(self.current.left, { text = text, hl = hl })

    return self
end

function LineBuilder:right(text, hl)
    table.insert(self.current.right, { text = text, hl = hl })

    return self
end

function LineBuilder:build(max_width)
    return LineBuilder.build_from_table(self.current, max_width)
end

-- extracted from this PR: https://github.com/sidebar-nvim/sidebar.nvim/pull/41
-- thanks @lambdahands
local function sanitize_line(line)
    return string.gsub(tostring(line), "[\n\r]", " ")
end

function LineBuilder.build_from_table(tbl, max_width)
    if getmetatable(tbl) == LineBuilder then
        return tbl:build(max_width)
    end

    tbl = tbl or {}

    local line = ""
    local hl = {}

    for _, item in ipairs(tbl.left or {}) do
        if item ~= nil and item.text ~= nil then
            -- Calculate space left in line
            local space_left = max_width - #line

            -- Break if line is already full
            if space_left <= 0 then
                break
            end

            local new_text = sanitize_line(item.text):sub(1, space_left)
            table.insert(hl, { group = item.hl or "SidebarNvimNormal", start_col = #line, length = #new_text })
            line = line .. new_text
        end
    end

    local temp_line = ""
    local temp_hl = {}

    for _, item in ipairs(tbl.right or {}) do
        if item ~= nil and item.text ~= nil then
            -- Calculate space left in line
            local space_left = max_width - #line - #temp_line - 1

            -- Break if line is already full
            if space_left <= 0 then
                break
            end

            local new_text = sanitize_line(item.text):sub(1, space_left)
            table.insert(
                temp_hl,
                { group = item.hl or "SidebarNvimNormal", start_col = #line + #temp_line, length = #new_text }
            )
            temp_line = temp_line .. new_text
        end
    end

    -- Calculate offset and add empty space in the middle
    local offset = max_width - #temp_line - #line
    local gap = string.rep(" ", offset)
    line = line .. gap .. temp_line

    -- Add highlights accounting for offset
    for _, current_hl in ipairs(temp_hl) do
        table.insert(
            hl,
            { group = current_hl.group, start_col = current_hl.start_col + offset, length = current_hl.length }
        )
    end

    return line, hl
end

function LineBuilder:__tostring()
    return self:build(120)
end

return LineBuilder
