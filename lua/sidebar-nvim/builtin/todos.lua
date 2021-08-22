local has_todos, todos = pcall(require, "todo-comments.search")
local Loclist = require("sidebar-nvim.components.loclist")

local loclist = Loclist:new({
  highlights = {
    group = "SidebarNvimTodoTag",
    group_count = "SidebarNvimTodoTotalNumber",
    item_text = "SidebarNvimTodoFilename",
    item_lnum = "SidebarNvimTodoLineNumber",
    item_col = "SidebarNvimTodoColNumber",
  }
})

local function do_search(ctx)
  if not has_todos then
    return
  end

  local opts = nil
  todos.search(function(results)
    table.sort(results, function(a, b)
      return a.tag < b.tag
    end)

    table.sort(results, function(a, b)
      return a.filename < b.filename
    end)

    table.sort(results, function(a, b)
      return a.lnum < b.lnum
    end)

    loclist:clear()

    for _, item in pairs(results) do
      loclist:add_item({
        group = item.tag,
        lnum = item.lnum,
        col = item.col,
        text = vim.fn.fnamemodify(item.filename, ":t"),
        filepath = item.filename,
      })
    end
  end, opts)
end

return {
  title = "TODOs",
  icon = "📄",
  draw = function(ctx)
    if not has_todos then
      local lines =  {"provider 'todo-comments' not installed"}
      return {lines = lines, hl = {}}
    end

    do_search(ctx)

    local lines = {}
    local hl = {}

    loclist:draw(ctx, lines, hl)

    if #lines == 0 then
      lines = {"<no TODOs>"}
    end

    return {
      lines = lines,
      hl = hl,
    }
  end,
  highlights = {
    -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
    groups = {},
    -- { MyHLGroupLink = <string> }
    links = {
      SidebarNvimTodoTag = "Label",
      SidebarNvimTodoTotalNumber = "Normal",
      SidebarNvimTodoFilename = "Normal",
      SidebarNvimTodoLineNumber = "LineNr",
      SidebarNvimTodoColNumber = "LineNr",
    },
  },
  bindings = {
    ["t"] = function(line)
      loclist:toggle_group_at(line)
    end,
    ["e"] = function(line)
      local location = loclist:get_location_at(line)
      if not location then
        return
      end
      vim.cmd("wincmd p")
      vim.cmd("e "..location.filename)
      vim.fn.cursor(location.lnum, location.col)
    end,
  },
}

