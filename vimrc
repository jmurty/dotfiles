" Start pathogen
call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

set nocompatible
set backspace=indent,eol,start

" Remap leader character from \
let mapleader = ","

" 256 Color Mode
set t_Co=256
" Switch color modes to \8, \1[6] or \2[56] colors
nmap <silent> <Leader>8 :set t_Co=8<CR>
nmap <silent> <Leader>1 :set t_Co=16<CR>
nmap <silent> <Leader>2 :set t_Co=256<CR>

" NERDTreeToggle
nmap <Leader>f :NERDTreeToggle<CR>
imap <Leader>f <Esc>:NERDTreeToggle<CR>
nmap <Leader>F :NERDTreeFind<CR>
imap <Leader>F <Esc>:NERDTreeFind<CR>
" Ignore files in tree
let NERDTreeIgnore=['\~$', '\.pyc$']

" Ignore files in general
set wildignore+=*/build/*,*.pyc,*.o,*.obj,*.class,*.png,*.jpg,*.gif

" Display
set ruler
set showmode
set number
set wildmenu

" Always show the status line
set laststatus=2

" Status Line base
set statusline=%<%f%h%m%r\ 

" Formatting/wrapping options, see :help fo-table
set nowrap linebreak
set formatoptions=qrn1ltc

" jj == Escape
imap jj <Esc>

" Navigate windows
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Detect file updates and reload if no local changes
if has("autocmd")
    autocmd CursorHold * checktime
    set autoread
endif

" Searching
set incsearch
set hlsearch
set smartcase
set ignorecase
set gdefault
" Clear prior search highlighting
nnoremap <leader>/ :noh<cr>

" Spelling
nmap <silent> <leader>s :set spell! spelllang=en_au<CR>
" English US
"set spelllang=en_us
" English AU
set spelllang=en_au

" GUI Options (e.g. MacVim)
set guioptions=egmrLt

" Sytax coloring
syntax enable

" Color scheme
if has("autocmd")
    autocmd ColorScheme * highlight MyWarning ctermbg=darkred guibg=darkred
endif
colorscheme wombat256mod
"colorscheme oceanblack256
"colorscheme mustang
"colorscheme desert256
"colorscheme xoria256

" Colorized theme (in compatibility mode with 256-color terminal)
"set background=dark
"let g:solarized_termcolors=256
"colorschem solarized

" Show whitespace characters (toggle with \l)
set list
set listchars=tab:>\ ,eol:$,nbsp:.,trail:\ ,extends:>,precedes:<
nmap <silent> <Leader>l :set list!<CR>
" Highlight SpecialKey (nbsp, tab, trail)
"highlight SpecialKey ctermbg=darkred guibg=darkred

" Highlight max-width column (7.3+)
set colorcolumn=80

" Set text width for auto-wrapping (need 'tc' in formatoptions, see ,w/,W)
set textwidth=79

" Toggle automatic line-wrapping on and off
nmap <Leader>wr :set formatoptions+=tc<CR>
nmap <Leader>WR :set formatoptions-=tc<CR>

" Excess whitespace find with ,ws
"nmap <Leader>ws /\s\+$\\|\t<CR>

" Highlight current line
"set cursorline

" Coding (Tabs and indentation)
set tabstop=4 softtabstop=4 shiftwidth=4
set expandtab
set shiftround
" Improves PHP indentation
set nocindent
filetype plugin indent on

" History
set history=1000

" Save marks
set viminfo='100,f1

" Hidden buffers for easy buffer switching
set hidden

" Auto-apply changes to .vimrc file
if has("autocmd")
    autocmd bufwritepost .vimrc source $MYVIMRC
endif

" Quick-edit .vimrc
nmap <Leader>V :sp $MYVIMRC<CR>

" Bubble single lines
nmap <C-Up> [e
nmap <C-Down> ]e
" Bubble multiple lines
vmap <C-Up> [egv
vmap <C-Down> ]egv

" Visually select the text that was last edited/pasted
nmap gV `[v`]

" Change command map prefix for VCS plugin from <Leader>c to <Leader>v
let VCSCommandMapPrefix = "<Leader>v"

" Tlist/taglist ctags viewer
nmap <Leader>tl :TlistToggle<CR>
let Tlist_WinWidth = 50
"let Tlist_Ctags_Cmd = "/home/jmurty/local/bin/ctags"

" Enable omni-completion for Python
if has("autocmd")
    autocmd FileType python set omnifunc=pythoncomplete#Complete
endif

" YankRing config
" Show contents of YankRing
nmap <Leader>y :YRShow<CR>
" Don't use default C-N / C-P keys for paste cycling, this clobbers Ctrl-P
let g:yankring_replace_n_pkey = '<m-p>'
let g:yankring_replace_n_nkey = '<m-n>'

" Undo files (7.3+)
set undofile
set undodir=/tmp

" Show Gundo navigation window
nmap <Leader>u :GundoToggle<CR>

" Toggle mouse mode between a and nothing (work around PuTTY copy/paste weirdness)
nnoremap <silent> <Leader>m :set mouse=a<CR>
nnoremap <silent> <Leader>M :set mouse=<CR>

" Support mouse control
" https://wincent.com/blog/tweaking-command-t-and-vim-for-use-in-the-terminal-and-tmux
if has('mouse')
  set mouse=a
  if &term =~ "xterm" || &term =~ "screen"
    " for some reason, doing this directly with 'set ttymouse=xterm2'
    " doesn't work -- 'set ttymouse?' returns xterm2 but the mouse
    " makes tmux enter copy mode instead of selecting or scrolling
    " inside Vim -- but luckily, setting it up from within autocmds
    " works
    autocmd VimEnter * set ttymouse=xterm2
    autocmd FocusGained * set ttymouse=xterm2
    autocmd BufEnter * set ttymouse=xterm2
  endif
endif

" Disable mouse support
set mouse=

" Use OS X clipboard as yank buffer (7.3+)
"if has("mac")
"  set clipboard=unnamed
"endif

" Syntastic syntax checking
let g:syntastic_enable_signs=0
let g:syntastic_always_populate_loc_list=1
let g:syntastic_check_on_open=0
let g:syntastic_echo_current_error=1
let g:syntastic_enable_highlighting = 1
let g:syntastic_auto_jump=0
let g:syntastic_quiet_warnings=0
let g:syntastic_mode_map = { 'mode': 'active',
                           \ 'passive_filetypes': [],
                           \ 'active_filetypes': [] }
" Show syntastic warning in status line
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

" Add content to end of status line
set statusline+=%=%-10.(%l,%c%V%)\ %P

" vim-fugitive Git wrapper
if has("autocmd")
    " Auto-delete fugitive git buffers when you leave them
    autocmd BufReadPost fugitive://* set bufhidden=delete
endif
" Show git branch in status line
"set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" jedi-vim config
let g:jedi#use_tabs_not_buffers = 0
let g:jedi#autocompletion_command = "<C-Space>"
"" Don't auto-complete unless I ask for it with Ctrl-Space
let g:jedi#popup_on_dot = 0

" Unite.vim plugin
let g:unite_enable_start_insert = 0
let g:unite_split_rule = 'botright'
let g:unite_source_file_rec_max_cache_files = 30000
call unite#filters#matcher_default#use(['matcher_fuzzy'])
nnoremap <leader><Space> :<C-u>Unite buffer file_mru<cr>
nnoremap <leader>t :<C-u>Unite -start-insert file_rec/async<cr>
nnoremap <leader>T :<C-u>Unite -start-insert file<cr>
nnoremap <leader>o :<C-u>Unite outline<cr>
nnoremap <leader>a :<C-u>Unite grep:.<cr>
" Unite grep
if executable('ag')
  " Use ag in unite grep source.
  let g:unite_source_grep_command = 'ag'
  let g:unite_source_grep_default_opts = '--nocolor --nogroup --hidden'
  let g:unite_source_grep_recursive_opt = ''
elseif executable('ack-grep')
  " Use ack in unite grep source.
  let g:unite_source_grep_command = 'ack-grep'
  let g:unite_source_grep_default_opts = '--no-heading --no-color -a'
  let g:unite_source_grep_recursive_opt = ''
endif
" Custom mappings for the unite buffer
autocmd FileType unite call s:unite_settings()
function! s:unite_settings()
  " Enable navigation with control-j and control-k in insert mode
  imap <buffer> <C-j>   <Plug>(unite_select_next_line)
  imap <buffer> <C-k>   <Plug>(unite_select_previous_line)
  " Quick mappings for split and vsplit
  nnoremap <silent><buffer><expr> s unite#do_action('split')
  nnoremap <silent><buffer><expr> v unite#do_action('vsplit')
endfunction

" Dash.app quick search
nmap <silent> <Leader>D <Plug>DashSearch

" ixc whitespace styles: tabs with width 2 for html, otherwise spaces width 4
autocmd Filetype htmldjango setlocal ts=2 sts=2 sw=2 noet
autocmd Filetype html setlocal ts=2 sts=2 sw=2 noet
autocmd Filetype scss setlocal ts=2 sts=2 sw=2 noet
