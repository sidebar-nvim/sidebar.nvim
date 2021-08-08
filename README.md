# sidebar.nvim

A generic and module lua sidebar inspired by [lualine](https://github.com/hoob3rt/lualine.nvim)

## Quick start

```lua
local sidebar = require("sidebar-nvim")
local opts = {}
sidebar.setup(ops)
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

Attach custom bindings to the sidebar buffer

Example:

```lua
require("sidebar-nvim").setup({
    bindings = { key = "q", cb = ":SidebarNvimClose<CR>" }
})
```

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

#### diagnostics

Prints the current status of the builtin lsp

TODO

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
                -- { <group name>, <line index relative to the returned lines>, <column start>, <column end> }
                { "SectionMarker", 0, 0, 1 },
            }
        }
    end
}

```

## TODO

- [ ] Sections custom mappings - allow sections to bind custom key mappings
- [ ] Section options - allow sections to receive options during startup

## References

We based most of the code from the awesome work of @kyazdani42 in [nvim-tree](https://github.com/kyazdani42/nvim-tree.lua)

## Contributors

[@GustavoKatel](https://github.com/GustavoKatel/)
[@davysson](https://github.com/davysson/)
