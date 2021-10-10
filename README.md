# sidebar.nvim

A generic and modular lua sidebar inspired by [lualine](https://github.com/hoob3rt/lualine.nvim)

Development status: Alpha - bugs are expected

![screenshot](./demo/screenshot.png)

## Quick start

```lua
local sidebar = require("sidebar-nvim")
local opts = {open = true}
sidebar.setup(opts)
```

See [options](#options) for a full list of setup options

## TODOs (Need help)

- [ ] Better section icons
- [ ] Improve docs + write vim help files
- [ ] See repo issues, any contribution is really appreciated

## Quick links

- [Options, commands, api and colors](./doc/general.md)
- [Builtin sections](./doc/builtin-sections.md)
- [Custom sections](./doc/custom-sections.md)

## Third party sections

- [dap-sidebar.nvim](https://github.com/GustavoKatel/dap-sidebar.nvim) - Show Dap breakpoints in the sidebar

## References

We based most of the code from the awesome work of @kyazdani42 in [nvim-tree](https://github.com/kyazdani42/nvim-tree.lua)

## Contributors

[@GustavoKatel](https://github.com/GustavoKatel/)
[@davysson](https://github.com/davysson/)
