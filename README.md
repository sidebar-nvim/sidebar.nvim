# sidebar.nvim

A generic and modular lua sidebar inspired by [lualine](https://github.com/hoob3rt/lualine.nvim)

Development status: Alpha - bugs are expected

![screenshot](./docs/screenshot.png)

## Quick start

```lua
local sidebar = require("sidebar-nvim")
local opts = {}
sidebar.setup(opts)
sidebar.open()
```

See [options](##options) for a full list of setup options

## Options

Sidebar setup options.

Defaults:

```lua
require("sidebar-nvim").setup({
    disable_default_keybindings = 0,
    bindings = nil,
    side = "left",
    initial_width = 50,
    update_interval = 1000,
    sections = { "datetime", "git-status", "diagnostics" }
})
```

#### `disable_default_keybindings`

Default: 0

Enable/disable the default keybindings

#### `bindings`

Default: nil

Attach custom bindings to the sidebar buffer.

Example:

```lua
require("sidebar-nvim").setup({
    bindings = { ["q"] = function() require("sidebar-nvim").close() end }
})
```

Note sections can override these bindings, please see [Section Bindings](#bindings-1)

#### `side`

Default: `left`

#### `initial_width`

Default: 50

#### `update_interval`

Default: 1000

Update frequency in milliseconds

#### `sections`

Default: `{ "datetime", "git-status", "diagnostics" }`

Which sections should the sidebar render

See [Bultin Sections](##builtin-sections) and [Custom Sections](##custom-sections)


## Builtin Sections

#### datetime

Prints the current date and time using `vim.fn.strftime("%c")`

#### git-status

Prints the status of the repo as returned by `git status --porcelain`

##### keybindings

| key | when | action |
|-----|------|--------|
| `e` | hovering filename | open file in the previous window

#### lsp-diagnostics

Prints the current status of the builtin lsp grouper by file. It shows only loaded buffers

##### keybindings

| key | when | action |
|-----|------|--------|
| `e` | hovering diagnostic message | open file in the previous window at the diagnostic position
| `t` | hovering filename | toggle collapse on the group

#### todos

Shows the TODOs in source. Provided by [todo-comments](https://github.com/folke/todo-comments.nvim)

##### keybindings

| key | when | action |
|-----|------|--------|
| `e` | hovering todo location | open file in the previous window at the todo position
| `t` | hovering the group | toggle collapse on the group

## Custom Sections

sidebar.nvim accepts user defined sections. The minimal section definition is a table with a `draw` function that returns the string ready to render in the sidebar and a title. See below the list of available properties

```lua

local section = {
    title = "Section Title",
    icon = "->",
    draw = function(ctx)
        return "> string here\n> multiline"
    end,
    highlights = {
        groups = { MyHighlightGroup = { gui="#C792EA", fg="#ff0000", bg="#00ff00" } },
        links = { MyHighlightGroupLink = "Keyword" }
    }
}

```

#### `draw`

The function accepts a single parameter `ctx` containing the current width of the sidebar:

```lua
{ width = 90 }
```

The draw function may appear in three forms:

- Returning a string
- Returning a table of strings
- Returning a table like `{ lines = "", hl = {} }`

The later is used to specify the highlight groups related to the lines returned

Example:

```lua

local section = {
    title = "test",
    draw = function()
        return {
            lines = {"> item1", "> item2"},
            hl = {
                -- { <group name>, <line index relative to the returned lines>, <column start>, <column end, -1 means end of the line> }
                { "SectionMarker", 0, 0, 1 },
            }
        }
    end
}

```

#### `highlights`

Specify the highlight groups associated with this section. This table contains two properties: `groups` and `links`

- `groups` define new highlight groups
- `links` link highlight groups to another

Example:

```lua
local section = {
    title = "Custom Section",
    icon = "->",
    draw = function()
        return {
            lines = {"hello world"},
            hl = {
                -- more info see `:h nvim_buf_add_highlight()`
                { "CustomHighlightGroupHello", 0, 0, 5 }, -- adds `CustomHighlightGroupHello` to the word "hello"
                { "CustomHighlightGroupWorld", 0, 6, -1 }, -- adds `CustomHighlightGroupWorld` to the word "world"
            }, 
        }
    end,
    highlights = {
        groups = { CustomHighlightGroupHello = { gui="#ff0000", fg="#00ff00", bg="#0000ff" } },
        links = { CustomHighlightGroupWorld = "Keyword" }
    }
}
```

more info see: [:h nvim_buf_add_highlight](https://neovim.io/doc/user/api.html#nvim_buf_add_highlight())

#### `bindings`

Custom sections can define custom bindings. Bindings are dispatched to the section that the cursor is currently over.

This means that multiple sections can define the same bindings and SidebarNvim will dispatch to the correct section depending on the cursor position.

Example:

```lua
local lines = {"hello", "world"}
local section = {
    title = "Custom Section",
    icon = "->",
    draw = function()
        return lines
    end,
    bindings = {
        ["e"] = function(line, col)
            print("current word: "..lines[line])
        end,
    },
}
```

## Builtin components

Builtin components abstract ui elements that can be reused within sections.

#### Loclist

Create a location list with collapsable groups.

Sections using it: [git-status](#git-status), [lsp-diagnostics](#lsp-diagnostics) and [todos](#todos)

Example:
```lua
local Loclist = require("sidebar-nvim.components.loclist")
local loclist = Loclist:new()
loclist:add_item({ group = "my_group", lnum = 1, col = 2, text = "my cool location", icon = { text = "#", hl = "MyCustomHighlightGroup" } })

-- inside the section draw function
local lines, hl = {}, {}

table.insert(lines, "Here's the location list you asked:")

loclist:draw(ctx, lines, hl)

return { lines = lines, hl = hl }

```

## Colors

| Highlight Group | Defaults To |
| --------------- | ----------- |
| *SidebarNvimSectionTitle* | Directory |
| *SidebarNvimSectionSeparator* | Comment |
| *SidebarNvimGitStatusState* | Keyword |
| *SidebarNvimGitStatusFileName* | Normal |
| *SidebarNvimLspDiagnosticsError* | LspDiagnosticsDefaultError |
| *SidebarNvimLspDiagnosticsWarn* | LspDiagnosticsDefaultWarning |
| *SidebarNvimLspDiagnosticsInfo* | LspDiagnosticsDefaultInformation |
| *SidebarNvimLspDiagnosticsHint* | LspDiagnosticsDefaultHint |
| *SidebarNvimLspDiagnosticsLineNumber* | LineNr |
| *SidebarNvimLspDiagnosticsColNumber* | LineNr |
| *SidebarNvimLspDiagnosticsFilename* | Label |
| *SidebarNvimLspDiagnosticsTotalNumber* | LspTroubleCount |
| *SidebarNvimLspDiagnosticsMessage* | Normal |
| *SidebarNvimTodoTag* | Label |
| *SidebarNvimTodoTotalNumber* | Normal |
| *SidebarNvimTodoFilename* | Normal |
| *SidebarNvimTodoLineNumber* | LineNr |
| *SidebarNvimTodoColNumber* | LineNr |

## References

We based most of the code from the awesome work of @kyazdani42 in [nvim-tree](https://github.com/kyazdani42/nvim-tree.lua)

## Contributors

[@GustavoKatel](https://github.com/GustavoKatel/)
[@davysson](https://github.com/davysson/)
