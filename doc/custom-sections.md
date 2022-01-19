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

### `icon` {#sidebar.icon()}

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

### `setup` {#sidebar.setup()}

This function is called only once *and* only if the section is being used
You can use this function to create timers, background jobs etc

### `update`

This plugin can request the section to update its internal state by calling this function. You may use this to avoid calling expensive functions during draw.

NOTE: This does not have any debouncing and it may be called multiples times, you may want to use a [debouncer](#debouncer)

Events that trigger section updates:

- `BufWritePost *`
- `VimResume *`
- `FocusGained *`

### `draw`

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

### `highlights`

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

### `bindings` {#custom-bindings}

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

Sections using it: [git](./builtin-sections.md#git), [diagnostics](./builtin-sections.md#diagnostics) and [todos](./builtin-sections.md#todos)

Example:
```lua
local Loclist = require("sidebar-nvim.components.loclist")
local loclist = Loclist:new({
    -- line and col numbers
    show_location = true,
    -- badge showing the number of items in each group
    show_group_count = true,
    -- if there's a single group, skip rendering the group controls
    omit_single_group = false,
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

