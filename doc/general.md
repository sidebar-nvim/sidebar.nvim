# Overview

A generic and modular lua sidebar inspired by lualine

# Installing

You can install sidebar using any package manager.

With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'sidebar-nvim/sidebar.nvim'
```

# Setup

Minimal setup:

```lua
require("sidebar-nvim").setup()
```

# Options

The following code block shows the defaults options:

```lua
{
  disable_default_keybindings = 0,
  bindings = nil,
  open = false,
  side = "left",
  initial_width = 35,
  hide_statusline = false,
  update_interval = 1000,
  sections = { "datetime", "git", "diagnostics" },
  section_separator = "-----",
  containers = {
      attach_shell = "/bin/sh", show_all = true, interval = 5000,
  },
  datetime = { format = "%a %b %d, %H:%M", clocks = { { name = "local" } } },
  todos = { ignored_paths = { "~" } },
  disable_closing_prompt = false
}
```

- `disable_default_keybindings` (number): Enable/disable the default keybindings. Default is `0`

- `bindings` (function): Attach custom bindings to the sidebar buffer. Default is `nil`

- `side` (string): Side of sidebar. Default is `'left'`

- `initial_width` (number): Width of sidebar. Default is `50`

- `hide_statusline` (bool): Show or hide sidebar statusline. Default is `false`

- `update_interval` (number): Update frequency in milliseconds. Default is `1000`

- `sections` (table): Which sections should the sidebar render. Default is `{ "datetime", "git", "diagnostics" }`

- `section_separator` (string | function): Section separator mark, can be a string or a function. Default is `-----`

    ```lua
    -- Using a function
    function section_separator(section)
        return "-----"
    end
    ```

  `section` is the section definition. See [Custom Sections](#custom-sections) for more info

- `disable_closing_prompt` (bool): Enable/disable the closing prompt when the sidebar is the last open window. Default is `false`

# Lua API

Public Lua api is available as: `require("sidebar-nvim").<function>`

- `toggle()`: Open/close the view

- `close()`: Close if open, otherwise no-op

- `open()`: Open if closed, otherwise no-op

- `update()`: Immediately update the view and the sections

- `resize(size)`: Resize the view width to `size`

  Parameters:

    - `size` (number): Resize the view width

- `focus()`: Move the cursor to the sidebar window

- `get_width(tabpage)`: Get the current width of the view from the current `tabpage`.

  Parameters:

    - `tabpage` (number): is the tab page number, if null it will return the width in the current tab page

- `reset_highlight()`: Use in case of errors. Clear the current highlighting so it can be re-rendered

# Commands

- `SidebarNvimToggle`: Open/Close the view
- `SidebarNvimClose`: Close if open, otherwise no-op
- `SidebarNvimOpen`: Open if closed, otherwise no-op
- `SidebarNvimUpdate`: Immediately update the view and the sections
- `SidebarNvimResize size`: Resize the view width to size, `size` is a number
- `SidebarNvimFocus`: Move the cursor to the sidebar window


# Custom Sections

sidebar.nvim accepts user defined sections. The minimal section definition is a table with a `draw` function that returns the string ready to render in the sidebar and a title. See below the list of available properties

```lua
local section = {
    title = "Section Title",
    icon = "->",
    setup = function(ctx)
        -- called only once and if the section is being used
    end,
    update = function(ctx)
        -- hook callback, called when an update was requested by either the user of external events (using autocommands)
    end,
    draw = function(ctx)
        return "> string here\n> multiline"
    end,
    highlights = {
        groups = { MyHighlightGroup = { gui="#C792EA", fg="#ff0000", bg="#00ff00" } },
        links = { MyHighlightGroupLink = "Keyword" }
    }
}

```

## Section Icon

String with the icon or a function that returns a string

```lua
local section = {
    icon = function()
        return "#"
    end,
    -- or
    -- icon = "#"
}
```

## Section Setup

This function is called only once *and* only if the section is being used
You can use this function to create timers, background jobs etc

## Section Update

This plugin can request the section to update its internal state by calling this function. You may use this to avoid calling expensive functions during draw.

NOTE: This does not have any debouncing and it may be called multiples times, you may want to use a [debouncer](#debouncer)

Events that trigger section updates:

- `BufWritePost *`
- `VimResume *`
- `FocusGained *`

## Section Draw

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

## Section Highlights

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

## Section Bindings

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

### Loclist

Create a location list with collapsable groups.

Sections using it: [git](#git), [diagnostics](#diagnostics) and [todos](#todos)

Example:
```lua
local Loclist = require("sidebar-nvim.components.loclist")
local loclist = Loclist:new({
    -- line and col numbers
    show_location = true,
    -- badge showing the number of items in each group
    show_group_count = true,
    -- if there's a single group, skip rendering the group controls
    ommit_single_group = false,
    -- initial state of the groups
    groups_initially_closed = false,
    -- highlight groups for each control element
    highlights = {
        group = "SidebarNvimLabel",
        group_count = "SidebarNvimNormal",
        item_icon = "SidebarNvimNormal",
        item_lnum = "SidebarNvimLineNr",
        item_col = "SidebarNvimLineNr",
        item_text = "SidebarNvimNormal",
    },
})
loclist:add_item({ group = "my_group", lnum = 1, col = 2, text = "my cool location", icon = { text = "#", hl = "MyCustomHighlightGroup" } })

-- inside the section draw function
local lines, hl = {}, {}

table.insert(lines, "Here's the location list you asked:")

loclist:draw(ctx, lines, hl)

return { lines = lines, hl = hl }

```

## Utils

### Debouncer

This can be used to avoid multiple calls within a certain time frame. It's useful if you want to avoid multiple expensive computations in sequence.

Example:

```lua
local Debouncer = require("sidebar-nvim.debouncer")

local function expensive_computation(n)
    print(n + 1)
end

local expensive_computation_debounced = Debouncer:new(expensive_computation, 1000)

expensive_computation_debounced:call(42) -- print(43)
expensive_computation_debounced:call(42) -- does nothing

vim.defer_fn(function()
    expensive_computation_debounced:call(43) -- print(44)
    expensive_computation_debounced:call(43) -- does nothing
end, 1500)
```

# Builtin Sections

## datetime

Prints the current date and time using. You can define multiple clocks with different timezones or offsets.

NOTE: In order to use timezones you need to install `luatz` from luarocks, like the following if using `packer`:

```lua
use {
    "sidebar-nvim/sidebar.nvim",
    rocks = {'luatz'}
}
```

This dependency is optional, you can use the `offset` parameter to change the clock, which does not require extra dependencies.

Example configuration:

```lua
require("sidebar-nvim").setup({
    ...,
    datetime = {
        icon = "",
        format = "%a %b %d, %H:%M",
        clocks = {
            { name = "local" }
        }
    },
    ...
})
```

Clock options:
```lua
{
    name = "clock name", -- defaults to `tz`
    tz = "America/Los_Angeles", -- only works if using `luatz`, defaults to current timezone
    offset = -8, -- this is ignored if tz is present, defaults to 0
}
```

You can see a list of all [available timezones here](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)

### git

Prints the status of the repo as returned by `git status --porcelain`

Example configuration:

```lua
require("sidebar-nvim").setup({
    ["git"] = {
        icon = "",
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `e` | hovering filename | open file in the previous window

## diagnostics

Prints the current status of the builtin lsp grouper by file. It shows only loaded buffers

```lua
require("sidebar-nvim").setup({
    ["diagnostics"] = {
        icon = "",
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `e` | hovering diagnostic message | open file in the previous window at the diagnostic position
| `t` | hovering filename | toggle collapse on the group

## todos

Shows the TODOs in source. Provided by RipGrep.

```lua
require("sidebar-nvim").setup({
    todos = {
        icon = "",
        ignored_paths = {'~'}, -- ignore certain paths, this will prevent huge folders like $HOME to hog Neovim with TODO searching
        initially_closed = false, -- whether the groups should be initially closed on start. You can manually open/close groups later.
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `e` | hovering todo location | open file in the previous window at the todo position
| `t` | hovering the group | toggle collapse on the group

Functions:

The following functions are available to the user to control this specific section elements. Call like the following: `require("sidebar-nvim.builtin.todos").<function>`

- `toggle_all()`: Toggle all groups, i.e.: NOTE, TODO, FIXME etc.

- `close_all()`: Close all groups.

- `open_all()`: Open all groups.

- `open(group_name)`: Opens the group with name `group_name`. 

    ```lua
    require("sidebar-nvim.builtin.todos").open("NOTE")
    ```

- `close(group_name)`: Closes the group with name `group_name`

    ```lua
    require("sidebar-nvim.builtin.todos").close("NOTE")
    ```

- `toggle(group_name)`: Toggle the group with name `group_name`.

    ```lua
    require("sidebar-nvim.builtin.todos").toggle("NOTE")
    ```

## containers

Shows the system docker containers. Collected from `docker ps -a '--format=\'{"Names": {{json .Names}}, "State": {{json .State}}, "ID": {{json .ID}} }\''`

NOTE: in some environments this can be a very intensive command to run. You may see increased cpu usage when this section is enabled.

```lua
require("sidebar-nvim").setup({
    containers = {
        icon = "",
        use_podman = false,
        attach_shell = "/bin/sh",
        show_all = true, -- whether to run `docker ps` or `docker ps -a`
        interval = 5000, -- the debouncer time frame to limit requests to the docker daemon
    }
})
```

Keybinding:

| key | when | action |
|-----|------|--------|
| `e` | hovering a container location | open a new terminal and attach to the container with `docker exec -it <container id> ${config.containers.attach_shell}`

## buffers

Shows current loaded buffers.

```lua
require("sidebar-nvim").setup({
    buffers = {
        icon = "",
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `e` | hovering an item | open the identified buffer in a window


## files

Shows/manage current directory structure.

```lua
require("sidebar-nvim").setup({
    files = {
        icon = "",
        show_hidden = false,
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `t` | hovering an item | open/close a folder
| `d` | hovering an item | delete file/folder
| `y` | hovering an item | yank/copy a file/folder
| `x` | hovering an item | cut a file/folder
| `p` | hovering an item | paste a file/folder
| `c` | hovering an item | create a new file
| `e` | hovering an item | open the current file
| `r` | hovering an item | rename file/folder
| `u` | hovering the section | undo operation
| `<C-r>` | hovering the section | redo operation
| `<CR>` | hovering an item | open file/folder


## symbols

Shows lsp symbols for the current buffer.

```lua
require("sidebar-nvim").setup({
    symbols = {
        icon = "ƒ",
    }
})
```

Keybindings:

| key | when | action |
|-----|------|--------|
| `t` | hovering an item | toggle group
| `e` | hovering an item | open location


# Colors

| Highlight Group | Defaults To |
| --------------- | ----------- |
| *SidebarNvimSectionTitle* | Directory |
| *SidebarNvimSectionSeparator* | Comment |
| *SidebarNvimNormal* | Normal |
| *SidebarNvimLabel* | Label |
| *SidebarNvimComment* | Comment |
| *SidebarNvimLineNr* | LineNr |
| *SidebarNvimKeyword* | Keyword |
| *SidebarNvimGitStatusState* | SidebarNvimKeyword |
| *SidebarNvimGitStatusFileName* | SidebarNvimNormal |
| *SidebarNvimLspDiagnosticsError* | LspDiagnosticsDefaultError |
| *SidebarNvimLspDiagnosticsWarn* | LspDiagnosticsDefaultWarning |
| *SidebarNvimLspDiagnosticsInfo* | LspDiagnosticsDefaultInformation |
| *SidebarNvimLspDiagnosticsHint* | LspDiagnosticsDefaultHint |
| *SidebarNvimLspDiagnosticsLineNumber* | SidebarNvimLineNr |
| *SidebarNvimLspDiagnosticsColNumber* | SidebarNvimLineNr |
| *SidebarNvimLspDiagnosticsFilename* | SidebarNvimLabel |
| *SidebarNvimLspDiagnosticsTotalNumber* | LspTroubleCount |
| *SidebarNvimLspDiagnosticsMessage* | SidebarNvimNormal |
| *SidebarNvimTodoTag* | SidebarNvimLabel |
| *SidebarNvimTodoTotalNumber* | SidebarNvimNormal |
| *SidebarNvimTodoFilename* | SidebarNvimNormal |
| *SidebarNvimTodoLineNumber* | SidebarNvimLineNr |
| *SidebarNvimTodoColNumber* | SidebarNvimLineNr |
| *SidebarNvimDockerContainerStatusRunning* | LspDiagnosticsDefaultInformation |
| *SidebarNvimDockerContainerStatusExited* | LspDiagnosticsDefaultError |
| *SidebarNvimDockerContainerName* | SidebarNvimNormal |
| *SidebarNvimDatetimeClockName* | SidebarNvimComment |
| *SidebarNvimDatetimeClockValue* | SidebarNvimNormal |
