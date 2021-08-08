local view = require('sidebar-nvim.view')
local max_width = view.View.width - 10
local severityLevel = {"Error", "Warning", "Info", "Hint"}
local icons = {"", "", "", ""}
local useIcons = true

local function get_diagnostics()
    local messages = ""
    local current_buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(current_buf)
    diagnostics = vim.lsp.diagnostic.get(current_buf - 1)
    for _, diag in pairs(diagnostics) do
        message = diag["message"]
        local severity = diag["severity"]
        local level = severityLevel[severity]
        local icon = icons[severity]

        if message:len() > max_width then
          message = message:sub(1, max_width) .. "..."
        end

        if useIcons then
          messages = messages .. "\n" .. icon .. " " .. message:gsub("\n", " ")
        else
          messages = messages .. "\n" .. level .. " " .. message:gsub("\n", " ")
        end
    end
    if messages ~= "" then return messages else return "<no diagnostics>" end
end

return {
  title = "Diagnostics",
  icon = "📄",
  draw = function()
    return get_diagnostics()
  end,
}
