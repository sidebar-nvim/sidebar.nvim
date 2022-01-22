## Options

Sidebar setup options.

Minimal configuration

```lua
require("sidebar-nvim").setup()
```

Defaults:

```lua
require("sidebar-nvim").setup({
    disable_default_keybindings = 0,
    bindings = nil,
    open = false,
    side = "left",
    initial_width = 35,
    hide_statusline = false,
    update_interval = 1000,
    sections = { "datetime", "git", "diagnostics" },
    section_separator = {"", "-----", ""},
    containers = {
        attach_shell = "/bin/sh", show_all = true, interval = 5000,
    },
    datetime = { format = "%a %b %d, %H:%M", clocks = { { name = "local" } } },
    todos = { ignored_paths = { "~" } },
    disable_closing_prompt = false
})
```

#### `disable_default_keybindings`

Default: 0

Enable/disable the default keybindings

#### `bindings` {#bindings}

Default: nil

Attach custom bindings to the sidebar buffer.

Example:

```lua
require("sidebar-nvim").setup({
    bindings = { ["q"] = function() require("sidebar-nvim").close() end }
})
```

Note sections can override these bindings, please see [Section Bindings](./custom-sections.md#bindings)

#### `side`

Default: `left`

#### `initial_width`

Default: 50

#### `hide_statusline`

Default: false

Show or hide Sidebar statusline

#### `update_interval`

Default: 1000

Update frequency in milliseconds

#### `sections`

Default: `{ "datetime", "git", "diagnostics" }`

Which sections should the sidebar render

See [Builtin Sections](./builtin-sections.md) and [Custom Sections](./custom-sections.md)

#### `section_separator`

Default: `{"", "-----", ""}`

Can be a string or a function with like the following:

```lua
function section_separator(section)
    return "-----"
end
```

`section` is the section definition. See [Custom Sections](./custom-sections.md) for more info

#### `disable_closing_prompt`

Default: false

Enable/disable the closing prompt when the sidebar is the last open window

## Api

Public api is available as:

`require("sidebar-nvim").<function>`

#### `toggle()` (`SidebarNvimToggle`)

Open/close the view

#### `close()` (`SidebarNvimClose`)

Close if open, otherwise no-op

#### `open()` (`SidebarNvimOpen`)

Open if closed, otherwise no-op

#### `update()` (`SidebarNvimUpdate`)

Immediately update the view and the sections

#### `resize(size)` (`SidebarNvimResize <size>`)

Resize the view width to `size`. `size` is a number

#### `focus(opts)` (`SidebarNvimFocus`)

Move the cursor to the sidebar window

```lua
require('sidebar-nvim').focus({
    section_index = 2, -- cursor will be in the second section

    -- if true, cursor will skip the section title and it will be placed at the first line of content
    -- otherwise it will be placed at the title. Default: true
    cursor_at_content = true,
})
```

#### `get_width(tabpage)`

Get the current width of the view from the current `tabpage`. `tabpage` is the tab page number, if null it will return the width in the current tab page

#### `reset_highlight`

Use in case of errors. Clear the current highlighting so it can be re-rendered

## Colors

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
| *SidebarNvimBuffersActive* | SidebarNvimSectionTitle |
| *SidebarNvimBuffersNumber* | SidebarNvimComment |

