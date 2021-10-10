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

### git-status

Prints the status of the repo as returned by `git status --porcelain`

#### keybindings {#git-status-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering filename | open file in the previous window

### lsp-diagnostics

Prints the current status of the builtin lsp grouper by file. It shows only loaded buffers

#### keybindings {#lsp-diagnostics-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering diagnostic message | open file in the previous window at the diagnostic position
| `t` | hovering filename | toggle collapse on the group

### todos

Shows the TODOs in source. Provided by [todo-comments](https://github.com/folke/todo-comments.nvim)

There are some small issues using this section see https://github.com/folke/todo-comments.nvim/pull/63
So you might want to consider using my fork instead https://github.com/GustavoKatel/todo-comments.nvim

#### config {#todos-config}

```lua
require("sidebar-nvim").setup({
    ...
    todos = {
        ignored_paths = {'~'}, -- ignore certain paths, this will prevent huge folders like $HOME to hog Neovim with TODO searching
    }
    ...
})
```

#### keybindings {#todos-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering todo location | open file in the previous window at the todo position
| `t` | hovering the group | toggle collapse on the group

### containers

Shows the system docker containers. Collected from `docker ps -a '--format=\'{"Names": {{json .Names}}, "State": {{json .State}}, "ID": {{json .ID}} }\''`

NOTE: in some environments this can be a very intensive command to run. You may see increased cpu usage when this section is enabled.

#### config {#containers-config}

```lua
require("sidebar-nvim").setup({
    ...
    docker = {
        use_podman = false,
        attach_shell = "/bin/sh",
        show_all = true, -- whether to run `docker ps` or `docker ps -a`
        interval = 5000, -- container update interval. The fetch command will run every 5s
    }
    ...
})
```

#### keybindings {#containers-keybindings}

| key | when | action |
|-----|------|--------|
| `e` | hovering a container location | open a new terminal and attach to the container with `docker exec -it <container id> ${config.docker.attach_shell}`

