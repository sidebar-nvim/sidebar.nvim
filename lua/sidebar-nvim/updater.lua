
local builtin = require("sidebar-nvim.builtin")


local M = {}

-- map containing the lines for each section
-- { section1 = {lines...}, section2= = {lines...} }
M.sections_data = {}

local function resolve_section_fn(name, section)
  if type(section) == "string" then
    return section, builtin[section]
  elseif type(section) == "table" then
    return section.name, section.fn
  end

  return name, section
end

function M.setup()
  if vim.g.sidebar_nvim_sections == nil then return end
end

function M.update()
  if vim.v.exiting ~= vim.NIL then return end

  for name, section in pairs(vim.g.sidebar_nvim_sections) do
    local name, fn = resolve_section_fn(name, section)
    M.sections_data[name] = fn()
  end

end

return M

