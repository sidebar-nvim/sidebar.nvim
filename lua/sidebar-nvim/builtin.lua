
local M = {}

M.datetime = function()
  return vim.fn.strftime("%c")
end

return M
