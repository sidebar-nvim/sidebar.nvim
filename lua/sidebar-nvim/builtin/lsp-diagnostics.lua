local severity_level = {"Error", "Warning", "Info", "Hint"}
local icons = {"", "", "", ""}
local use_icons = true

local function get_diagnostics(ctx)
    local messages = {}
    local hl = {}
    local current_buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(current_buf)

    local max_width = ctx.width - 10

    diagnostics = vim.lsp.diagnostic.get(current_buf - 1)
    for i, diag in pairs(diagnostics) do
        message = diag["message"]
        local severity = diag["severity"]
        local level = severity_level[severity]
        local icon = icons[severity]

        if use_icons then
          message = icon .. " " .. message:gsub("\n", " ")
          table.insert(messages, message)
        else
          message = level .. " " .. message:gsub("\n", " ")
          table.insert(messages, mess)
        end
        table.insert(hl, { 'SidebarNvimSectionKeyword', i, 0, message:len() })
    end
    if messages ~= {} then
      return {
        lines = messages,
        hl = hl
      }
    else
      return "<no diagnostics>"
    end
end

return {
  title = "Diagnostics",
  icon = "📄",
  draw = function(ctx)
    return get_diagnostics(ctx)
  end,
}
