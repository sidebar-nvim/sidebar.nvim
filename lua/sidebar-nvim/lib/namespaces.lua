local M = {}

M.hl_namespace_id = vim.api.nvim_create_namespace("SidebarNvimHighlights")
M.extmarks_namespace_id = vim.api.nvim_create_namespace("SidebarNvimExtmarks")
M.keymaps_namespace_id = vim.api.nvim_create_namespace("SidebarNvimExtmarksKeymaps")

return M
