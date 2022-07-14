--
-- group.lua
--

local utils = require("sidebar-nvim.utils")
local table_insert = table.insert
local strwidth = vim.api.nvim_strwidth
local strcharpart = vim.fn.strcharpart

local M = {}

-- A "group" is an array with the format `{ text = string, hl = string }` or just `string`

function M.length(groups)
  local result = 0

  for _, group in ipairs(groups) do
    result = result + strwidth(group.text)
  end

  return result
end

function M.concat(...)
  local result = {}
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) == "table" then
      for _, v in ipairs(arg) do
        result[#result + 1] = v
      end
    else
      result[#result + 1] = arg
    end
  end
  return result
end

function M.append(groups, group)
  groups[#groups + 1] = group
  return groups
end

function M.to_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    local text = group.text
    result = result .. text
  end

  return result
end

function M.unzip(groups, lnum)
  local hl = {}
  local text = ''
  local byte_length = 0

  for _, group in ipairs(groups) do
    local current_length = #group.text
    table.insert(hl, { group.hl, lnum, byte_length, byte_length + current_length })
    text = text .. group.text
    byte_length = byte_length + current_length
  end

  return text, hl
end

function M.insert(groups, position, others)
  local current_position = 0

  local new_groups = {}

  local i = 1
  while i <= #groups do
    local group = groups[i]
    local group_width = strwidth(group.text)

    -- While we haven't found the position...
    if current_position + group_width <= position then
      table_insert(new_groups, group)
      i = i + 1
      current_position = current_position + group_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current group if it `position` is inside it
      if available_width > 0 then
        local new_group = { group.hl, strcharpart(group.text, 0, available_width) }
        table_insert(new_groups, new_group)
      end

      -- Add new other groups
      local others_width = 0
      for _, other in ipairs(others) do
        local other_width = strwidth(other.text)
        others_width = others_width + other_width
        table_insert(new_groups, other)
      end

      local end_position = position + others_width

      -- Then, resume adding previous groups
      -- table.insert(new_groups, 'then')
      while i <= #groups do
        local previous_group = groups[i]
        local previous_group_width = strwidth(previous_group.text)
        local previous_group_start_position = current_position
        local previous_group_end_position   = current_position + previous_group_width

        if previous_group_end_position <= end_position and previous_group_width ~= 0 then
          -- continue
        elseif previous_group_start_position >= end_position then
          -- table.insert(new_groups, 'direct')
          table_insert(new_groups, previous_group)
        else
          local remaining_width = previous_group_end_position - end_position
          local start = previous_group_width - remaining_width
          local end_  = previous_group_width
          local new_group = { previous_group.hl, strcharpart(previous_group.text, start, end_) }
          -- table.insert(new_groups, { group_start_position, group_end_position, end_position })
          table_insert(new_groups, new_group)
        end

        i = i + 1
        current_position = current_position + previous_group_width
      end

      break
    end
  end

  return new_groups
end

function M.slice_right(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(groups) do
    local hl   = group.hl
    local text = group.text
    local text_width = strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      local new_group = { text = strcharpart(text, 0, diff), hl = hl }
      table_insert(new_groups, new_group)
      break
    end

    table_insert(new_groups, group)
  end

  return new_groups
end

function M.slice_left(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(utils.reverse(groups)) do
    local hl   = group.hl
    local text = group.text
    local text_width = strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      local new_group = { text = strcharpart(text, start, length), hl = hl}
      table_insert(new_groups, 1, new_group)
      break
    end

    table_insert(new_groups, 1, group)
  end

  return new_groups
end

function M.group_from_string(text)
  return { text = text, hl = "SidebarNvimNormal" }
end

function M.normalize(groups)
  local result = {}

  if groups == nil then
    return result
  end

  for _, group in ipairs(groups) do

    if type(group) == "string" then
      table.insert(result, M.group_from_string(group))

    elseif type(group) == "table" and group.text ~= nil then

      if group.text == "" then
        -- continue
      else
        if group.hl == nil then
          group.hl = "SidebarNvimNormal"
        end
        table.insert(result, group)
      end

    else
      error("Invalid group value: " .. tostring(vim.inspect(group)))
    end
  end

  return result
end

return M
