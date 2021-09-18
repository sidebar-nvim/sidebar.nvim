if !has('nvim-0.5') || exists('g:loaded_sidebar_nvim') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

augroup SidebarNvim
au!
au ColorScheme * lua require'sidebar-nvim'.reset_highlight()
au TabEnter * lua require'sidebar-nvim'._on_tab_change()
au WinClosed * lua require'sidebar-nvim'._on_win_leave()
au VimEnter * lua require'sidebar-nvim'._vim_enter()
au VimLeavePre * lua require'sidebar-nvim'._vim_leave()
augroup end

command! SidebarNvimOpen lua require'sidebar-nvim'.open()
command! SidebarNvimClose lua require'sidebar-nvim'.close()
command! SidebarNvimToggle lua require'sidebar-nvim'.toggle()
command! SidebarNvimUpdate lua require'sidebar-nvim'.update()
command! -nargs=1 SidebarNvimResize lua require'sidebar-nvim'.resize(<args>)

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_sidebar_nvim = 1
