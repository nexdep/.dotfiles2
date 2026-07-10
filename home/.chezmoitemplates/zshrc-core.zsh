# --- core (all machines) ---

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

# behaviour
setopt AUTO_CD INTERACTIVE_COMMENTS
bindkey -e

# completion
autoload -Uz compinit && compinit

# path
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH

# prompt
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# zoxide: adds the z/zi jump commands and tracks visited directories
# (also feeds yazi's zoxide plugin); cd itself is left untouched
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# fzf: ctrl-r history / ctrl-t file / alt-c cd keybindings and completion
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)

# aliases
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'

# gopass
if command -v gopass >/dev/null 2>&1; then
  source <(gopass completion zsh)
fi
