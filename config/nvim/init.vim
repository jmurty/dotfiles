""""""""""""""""""
" General Settings
""""""""""""""""""

" Remap leader character from \
let mapleader = ","

" Ignore files in general
set wildignore+=*/build/*,*.pyc,*.o,*.obj,*.class,*.png,*.jpg,*.gif

" Display
set ruler
set showmode
" Toggle 'number' with vim-unimpaired `con` and 'relativenumber' with `cor`
set nonumber
set wildmenu

" Always show the status line
set laststatus=2

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

" Spelling - toggle 'spell' with vim-unimpaired `cos`

" English US
"set spelllang=en_us
" English AU
set spelllang=en_au

" GUI Options (e.g. MacVim)
set guioptions=egmrLt

" Syntax coloring
syntax enable

" Show whitespace characters (toggle with `col`)
set list
set listchars=tab:>\ ,eol:$,nbsp:.,trail:\ ,extends:>,precedes:<

" Highlight max-width column (7.3+)
set colorcolumn=80

" Set text width for auto-wrapping (need 'tc' in formatoptions, see ,wr/,WR)
set textwidth=79

" Toggle 'wrap' with vim-unimpaired `cow`
" Toggle automatic line-wrapping on and off
nmap <Leader>wr :set formatoptions+=tc<CR>
nmap <Leader>WR :set formatoptions-=tc<CR>

" Don't highlight current line - toggle with vim-unimpaired `coc`
set nocursorline

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

" Visually select the text that was last edited/pasted
nmap gV `[v`]

" Undo files (7.3+)
set undofile
set undodir=/tmp

" Tlist/taglist ctags viewer
nmap <Leader>c :TlistToggle<CR>
let Tlist_WinWidth = 50
"let Tlist_Ctags_Cmd = "/home/jmurty/local/bin/ctags"


""""""""""""""""""
" Whitespace Rules
""""""""""""""""""

" ixc whitespace styles: tabs with width 2 for html, otherwise spaces width 4
autocmd Filetype htmldjango setlocal ts=2 sts=2 sw=2 noet colorcolumn=0
autocmd Filetype html setlocal ts=2 sts=2 sw=2 noet colorcolumn=0
autocmd Filetype scss setlocal ts=2 sts=2 sw=2 noet colorcolumn=0


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Python Provider
" See https://neovim.io/doc/user/provider.html#provider-python
"""""""""""""""""

let g:python_host_prog = '/Users/jmurty/Documents/code/virtualenvs/py2neovim/bin/python'
let g:python3_host_prog = '/Users/jmurty/Documents/code/virtualenvs/py3neovim/bin/python'


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" minpac package manager, see https://github.com/k-takata/minpac
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
packadd minpac

call minpac#init()

" minpac must have {'type': 'opt'} so that it can be loaded with `packadd`.
call minpac#add('k-takata/minpac', {'type': 'opt'})

" Packages
call minpac#add('sjl/gundo.vim')
call minpac#add('scrooloose/nerdcommenter')
call minpac#add('scrooloose/nerdtree')
call minpac#add('neomake/neomake')
call minpac#add('vim-scripts/taglist.vim')
call minpac#add('vim-scripts/bad-whitespace')
call minpac#add('iCyMind/NeoSolarized')
call minpac#add('tommcdo/vim-exchange')
call minpac#add('tpope/vim-fugitive')
call minpac#add('michaeljsmith/vim-indent-object')
call minpac#add('tmhedberg/matchit')
call minpac#add('tpope/vim-repeat')
call minpac#add('tpope/vim-speeddating')
call minpac#add('tpope/vim-surround')
call minpac#add('tpope/vim-unimpaired')
call minpac#add('nelstrom/vim-visual-star-search')
call minpac#add('vim-scripts/YankRing.vim')
call minpac#add('Shougo/denite.nvim')
call minpac#add('chemzqm/unite-location')
call minpac#add('vim-airline/vim-airline')
call minpac#add('vim-airline/vim-airline-themes')
call minpac#add('christoomey/vim-tmux-navigator')

" Define user commands for updating/cleaning the plugins.
" Each of them loads minpac, reloads config to register the
" information of plugins, then performs the task.
command! PackUpdate packadd minpac | source $MYVIMRC | call minpac#update()
command! PackClean  packadd minpac | source $MYVIMRC | call minpac#clean()

" TODO A hack, but necessary for later `call` commands to work on load
packloadall


""""""""""""""
" NeoSolarized
""""""""""""""

set background=dark
colorscheme NeoSolarized


"""""""""""""
" vim-airline
"""""""""""""

" TODO Not working?
let g:airline_powerline_fonts = 1


""""""""""""""""""""
" vim-airline-themes
""""""""""""""""""""

AirlineTheme powerlineish
"let g:airline_solarized_bg='dark'  " For solarized theme


"""""""
" Gundo
"""""""
" Show Gundo navigation window
nmap <Leader>u :GundoToggle<CR>


"""""""""""
" NERD Tree
"""""""""""

" NERDTreeToggle
nmap <Leader>f :NERDTreeToggle<CR>
imap <Leader>f <Esc>:NERDTreeToggle<CR>
nmap <Leader>F :NERDTreeFind<CR>
imap <Leader>F <Esc>:NERDTreeFind<CR>

" Ignore files in tree
let NERDTreeIgnore=['\~$', '\.pyc$']


"""""""""
" Neomake
"""""""""

" When writing a buffer.
call neomake#configure#automake('w')


""""""""""
" YankRing
""""""""""

" Show contents of YankRing
nmap <Leader>y :YRShow<CR>


""""""""
" Denite
""""""""

call denite#custom#option('default', {
    \ 'prompt': '❯',
    \ 'highlight_mode_insert': 'PmenuSel',
    \ 'highlight_mode_normal': 'PmenuSel',
    \ 'highlight_matched_char': 'Todo',
    \ 'source_names': 'short',
    \ })

" Override default matchers for file recursive
call denite#custom#source(
    \ 'file_rec', 'matchers', ['matcher_fuzzy', 'matcher_ignore_globs'])

" Define git file recursive search alias
call denite#custom#alias('source', 'file_rec/git', 'file_rec')
call denite#custom#var('file_rec/git', 'command',
    \ ['git', 'ls-files', '--cached', '--others', '--exclude-standard'])

" Denite grep
if executable('ag')
  " Ag command on grep source
  call denite#custom#var('grep', 'command', ['ag'])
  call denite#custom#var('grep', 'default_opts',
          \ ['-i', '--vimgrep'])
  call denite#custom#var('grep', 'recursive_opts', [])
  call denite#custom#var('grep', 'pattern_opt', [])
  call denite#custom#var('grep', 'separator', ['--'])
  call denite#custom#var('grep', 'final_opts', [])
elseif executable('ack-grep')
  " Ack command on grep source
  call denite#custom#var('grep', 'command', ['ack'])
  call denite#custom#var('grep', 'default_opts',
      \ ['--ackrc', $HOME.'/.ackrc', '-H',
      \  '--nopager', '--nocolor', '--nogroup', '--column'])
  call denite#custom#var('grep', 'recursive_opts', [])
  call denite#custom#var('grep', 'pattern_opt', ['--match'])
  call denite#custom#var('grep', 'separator', ['--'])
  call denite#custom#var('grep', 'final_opts', [])
  call denite#custom#var('grep', 'command', ['ag'])
endif

" Change mappings for Denite buffer
" Enable navigation with control-j and control-k in insert mode
call denite#custom#map(
      \ 'insert',
      \ '<C-j>',
      \ '<denite:move_to_next_line>',
      \ 'noremap'
      \)
call denite#custom#map(
      \ 'insert',
      \ '<C-k>',
      \ '<denite:move_to_previous_line>',
      \ 'noremap'
      \)
"" Switch to normal mode on <ESC> in insert mode
call denite#custom#map('insert', '<Esc>', '<denite:enter_mode:normal>',
      \'noremap')
"" Exit Denite when <ESC> in normal mode
call denite#custom#map('normal', '<Esc>', '<denite:quit>',
      \'noremap')
" Quit quickly while in insert mode
call denite#custom#map(
      \ 'insert',
      \ '<Esc><Esc>',
      \ '<denite:quit>',
      \ 'noremap'
      \)

" Define Denite commands
nnoremap <leader><Space> :<C-u>Denite buffer<cr>
nnoremap <leader>t :<C-u>Denite file_rec<cr>
nnoremap <leader>g :<C-u>Denite file_rec/git<cr>
nnoremap <leader>T :<C-u>Denite file<cr>
nnoremap <leader>o :<C-u>Denite outline<cr>
nnoremap <leader>a :<C-u>Denite grep:. -mode=normal<cr>
nnoremap <leader>h :<C-u>Denite command_history<cr>


""""""""""""""""""""""""""""""""
" unite-location (Denite plugin)
""""""""""""""""""""""""""""""""

nnoremap <leader>L :<C-u>Denite location_list<cr>
nnoremap <leader>Q :<C-u>Denite quickfix_list<cr>
