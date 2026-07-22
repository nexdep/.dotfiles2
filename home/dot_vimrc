"MDP configuration file for VIM - wsl

"fix a color bug in wsl
highlight Visual    ctermfg=NONE  ctermbg=grey guifg=NONE  guibg=grey
highlight Search    ctermfg=black ctermbg=grey guifg=black guibg=grey
highlight IncSearch ctermfg=black ctermbg=grey guifg=black guibg=grey

" send to windows clipboard
set clipboard=unnamedplus
set nowrap

"Mode Settings
let &t_SI.="\e[2 q" "SI = INSERT mode
let &t_SR.="\e[4 q" "SR = REPLACE mode
let &t_EI.="\e[2 q" "EI = NORMAL mode (ELSE)

"silence the vim bell
set noerrorbells
set visualbell
set t_vb=

"set the new fold on the right automatically
set splitright

"makes vim recognize and work with python
filetype indent plugin on

"set atomatic view save
augroup QuickNotes
  au BufWinLeave ?*.py mkview
  au BufWinEnter ?*.py silent loadview
augroup END

