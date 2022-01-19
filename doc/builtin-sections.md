# Builtin Sections

### datetime

Prints the current date and time using. You can define multiple clocks with different timezones or offsets.

NOTE: In order to use timezones you need to install `luatz` from luarocks, like the following if using `packer`:
```lua
use {
    "GustavoKatel/sidebar.nvim",
    rocks = {'luatz'}
}
```

This dependency is optional, you can use the `offset` parameter to change the clock, which does not require extra dependencies.

#### config {#datetime-config}

Example configuration:

```lua
require("sidebar-nvim").setup({
    ...
    datetime = {
        icon = "",
        format = "%a %b %d, %H:%M",
        clocks = {
            { name = "local" }
        }
    }
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

#### config {#git-config}

Example configuration:

```lua
require("sidebar-nvim").setup({
    ...
    ["git"] = {
        icon = "",
    }
    ...
})
```

#### keybindings {#git-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering filename | open file in the previous window

### diagnostics

Prints the current status of the builtin lsp grouper by file. It shows only loaded buffers

#### config {#diagnostics-config}

```lua
require("sidebar-nvim").setup({
    ...
    ["diagnostics"] = {
        icon = "",
    }
    ...
})
```


#### keybindings {#diagnostics-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering diagnostic message | open file in the previous window at the diagnostic position
| `t` | hovering filename | toggle collapse on the group

### todos

Shows the TODOs in source. Provided by RipGrep.

#### config {#todos-config}

```lua
require("sidebar-nvim").setup({
    ...
    todos = {
        icon = "",
        ignored_paths = {'~'}, -- ignore certain paths, this will prevent huge folders like $HOME to hog Neovim with TODO searching
        initially_closed = false, -- whether the groups should be initially closed on start. You can manually open/close groups later.
    }
    ...
})
```

#### keybindings {#todos-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering todo location | open file in the previous window at the todo position
| `t` | hovering the group | toggle collapse on the group

#### functions {#todos-functions}

The following functions are available to the user to control this specific section elements.

##### toggle_all()

Toggle all groups, i.e.: NOTE, TODO, FIXME etc.

Call like the following: `require("sidebar-nvim.builtin.todos").<function>`

##### close_all()

Close all groups.

##### open_all()

Open all groups.

##### open(group_name)

Opens the group with name `group_name`. Example `require("sidebar-nvim.builtin.todos").open("NOTE")`

##### close(group_name)

Closes the group with name `group_name`. Example `require("sidebar-nvim.builtin.todos").close("NOTE")`

##### toggle(group_name)

Toggle the group with name `group_name`. Example `require("sidebar-nvim.builtin.todos").toggle("NOTE")`

### containers

Shows the system docker containers. Collected from `docker ps -a '--format=\'{"Names": {{json .Names}}, "State": {{json .State}}, "ID": {{json .ID}} }\''`

NOTE: in some environments this can be a very intensive command to run. You may see increased cpu usage when this section is enabled.

#### config {#containers-config}

```lua
require("sidebar-nvim").setup({
    ...
    containers = {
        icon = "",
        use_podman = false,
        attach_shell = "/bin/sh",
        show_all = true, -- whether to run `docker ps` or `docker ps -a`
        interval = 5000, -- the debouncer time frame to limit requests to the docker daemon
    }
    ...
})
```

#### keybindings {#containers-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering a container location | open a new terminal and attach to the container with `docker exec -it <container id> ${config.containers.attach_shell}`

### buffers

Shows current loaded buffers.


#### config {#buffers-config}

```lua
require("sidebar-nvim").setup({
    ...
    buffers = {
        icon = "",
        ignored_buffers = {} -- ignore buffers by regex
    }
    ...
})
```

#### keybindings {#buffers-keybindings}

| key | when | action |
|-----|------|--------|
| `d` | hovering an item | close the identified buffer
| `e` | hovering an item | open the identified buffer in a window
| `w` | hovering an item | save the identified buffer


### files

Shows/manage current directory structure.


#### config {#files-config}

```lua
require("sidebar-nvim").setup({
    ...
    files = {
        icon = "",
        show_hidden = false,
    }
    ...
})
```

#### keybindings {#files-keybindings}

| key | when | action |
|-----|------|--------|
| `d` | hovering an item | delete file/folder
| `y` | hovering an item | yank/copy a file/folder
| `x` | hovering an item | cut a file/folder
| `p` | hovering an item | paste a file/folder
| `c` | hovering an item | create a new file
| `e` | hovering an item | open the current file/folder
| `r` | hovering an item | rename file/folder
| `u` | hovering the section | undo operation
| `<C-r>` | hovering the section | redo operation
| `<CR>` | hovering an item | open file/folder


### symbols

Shows lsp symbols for the current buffer.


#### config {#symbols-config}

```lua
require("sidebar-nvim").setup({
    ...
    symbols = {
        icon = "ƒ",
    }
    ...
})
```

#### keybindings {#files-keybindings}

| key | when | action |
|-----|------|--------|
| `t` | hovering an item | toggle group
| `e` | hovering an item | open location
