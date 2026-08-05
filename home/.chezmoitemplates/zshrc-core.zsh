# --- core (all machines) ---

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS

# behaviour
setopt AUTO_CD AUTO_PUSHD INTERACTIVE_COMMENTS CORRECT NULL_GLOB
unsetopt BEEP

# vi line editing (Esc to enter command mode); keep backspace sane in insert mode
bindkey -v
bindkey -M viins '^H' backward-delete-char
bindkey -M viins '^?' backward-delete-char

# editor
export EDITOR=nvim
export VISUAL=nvim

# completion
autoload -Uz compinit && compinit

# after a trailing digit, complete directories (jump into numbered run folders)
_my_number_completer() {
  if [[ $LBUFFER =~ '[0-9]$' ]]; then
    _files -/
  else
    _complete
  fi
}

# dircolors: colored ls and completion lists (~/.dircolors is deployed by chezmoi)
if command -v dircolors >/dev/null 2>&1; then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
fi

# eza metadata colors are not supported by GNU dircolors. Keep permissions,
# sizes, owners, and dates on the terminal's default foreground while retaining
# the LS_COLORS file palette.
export EZA_COLORS='oc=0:ur=0:uw=0:ux=0:ue=0:gr=0:gw=0:gx=0:tr=0:tw=0:tx=0:su=0:sf=0:xx=0:sn=0:sb=0:uu=0:uR=0:un=0:da=0'

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _my_number_completer _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:ssh:*:hosts' menu select
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# path
typeset -U path
path=("$HOME/.local/bin" "$HOME/.cargo/bin" $path)
export PATH

# prompt
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# Mark each prompt, command line and command output as OSC 133 semantic zones.
# WezTerm uses these boundaries for Prefix+Shift-V, while tmux 3.4+ uses the raw
# markers for its own prompt navigation. Inside tmux, send a second wrapped
# copy through to the host terminal as well. Direct shells keep WezTerm's
# packaged integration when it is already active; inside tmux, replace just
# its semantic hooks so one marker pair serves both tmux and the host terminal.
if [[ -o interactive && -t 1 && "$TERM" != linux && "$TERM" != dumb ]] &&
  { (( ! ${+functions[__wezterm_semantic_precmd]} )) || [[ -n "${TMUX:-}" ]]; }; then
  typeset -g _dotfiles_wezterm_semantic_running=
  typeset -g _dotfiles_wezterm_semantic_emit_raw=1

  if [[ -n "${TMUX:-}" ]] &&
    (( ${+functions[__wezterm_semantic_precmd]} )); then
    precmd_functions=("${(@)precmd_functions:#__wezterm_semantic_precmd}")
    preexec_functions=("${(@)preexec_functions:#__wezterm_semantic_preexec}")
  fi

  _dotfiles_wezterm_semantic_sequence() {
    local payload="$1"

    if (( _dotfiles_wezterm_semantic_emit_raw )); then
      printf '\033]133;%s\007' "$payload"
    fi
    if [[ -n "${TMUX:-}" ]]; then
      printf '\033Ptmux;\033\033]133;%s\007\033\\' "$payload"
    fi
  }

  _dotfiles_wezterm_semantic_precmd() {
    local last_status=$?

    if [[ "$_dotfiles_wezterm_semantic_running" != 0 ]]; then
      typeset -g _dotfiles_wezterm_saved_ps1="$PS1"
      typeset -g _dotfiles_wezterm_saved_ps2="$PS2"
      local primary_start secondary_start input_start
      primary_start="$(_dotfiles_wezterm_semantic_sequence 'P;k=i')"
      secondary_start="$(_dotfiles_wezterm_semantic_sequence 'P;k=s')"
      input_start="$(_dotfiles_wezterm_semantic_sequence B)"
      PS1="%{${primary_start}%}${PS1}%{${input_start}%}"
      PS2="%{${secondary_start}%}${PS2}%{${input_start}%}"
      typeset -g _dotfiles_wezterm_wrapped_ps1="$PS1"
    fi

    if [[ -n "$_dotfiles_wezterm_semantic_running" ]]; then
      _dotfiles_wezterm_semantic_sequence "D;${last_status};aid=$$"
    fi
    _dotfiles_wezterm_semantic_sequence "A;cl=m;aid=$$"
    _dotfiles_wezterm_semantic_running=0
  }

  _dotfiles_wezterm_semantic_preexec() {
    if [[ -n "${_dotfiles_wezterm_saved_ps1+x}" &&
      "${_dotfiles_wezterm_wrapped_ps1:-}" == "$PS1" ]]; then
      PS1="$_dotfiles_wezterm_saved_ps1"
      PS2="$_dotfiles_wezterm_saved_ps2"
    fi
    unset _dotfiles_wezterm_saved_ps1 _dotfiles_wezterm_saved_ps2
    unset _dotfiles_wezterm_wrapped_ps1
    _dotfiles_wezterm_semantic_sequence 'C;'
    _dotfiles_wezterm_semantic_running=1
  }

  precmd_functions+=(_dotfiles_wezterm_semantic_precmd)
  preexec_functions+=(_dotfiles_wezterm_semantic_preexec)
fi

# zoxide: adds the z/zi jump commands and tracks visited directories
# (also feeds yazi's zoxide plugin)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  # cd: frecency-jump via zoxide in interactive TTY shells only; scripts and
  # coding agents get the plain builtin (a mistyped path must fail loudly,
  # not jump to some other frecent directory)
  cd() {
    if [[ -o interactive && -t 1 ]]; then
      __zoxide_z "$@"
    else
      builtin cd "$@"
    fi
  }
fi

# fzf: ctrl-r history / ctrl-t file / alt-c cd keybindings and completion
# (binds into the vi keymaps set up above; pointless without a TTY, and
# sourcing it in TTY-less shells just prints zle warnings)
if command -v fzf >/dev/null 2>&1 && [[ -t 1 ]]; then
  source <(fzf --zsh)
fi

# keybindings: ctrl-x clears the screen; ctrl-l/ctrl-h and the alt-h/l pairs
# are disabled (terminal-quirk guards)
bindkey '^X' clear-screen
noop() {}
zle -N noop
bindkey -r '^L'
bindkey -r '^H'
bindkey -r '^[h'
bindkey -r '^[l'
bindkey -r '^[H'
bindkey -r '^[L'
for keymap in emacs viins vicmd; do
  bindkey -M "$keymap" '^[h' noop
  bindkey -M "$keymap" '^[l' noop
  bindkey -M "$keymap" '^[H' noop
  bindkey -M "$keymap" '^[L' noop
done

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
if command -v eza >/dev/null 2>&1; then
  alias ll='eza -ahloF --git --git-repos'
  # show the directory contents after cd'ing into it — interactive TTY
  # shells only, so scripts, pipes and coding agents' shells don't get the
  # listing (or hang on eza) after every cd
  chpwd() {
    [[ -o interactive && -t 1 ]] || return 0
    eza -aholF --git --git-repos
  }
else
  alias ll='ls -lah --color=auto'
fi
alias la='ls -A'
alias l='ls -CF'
alias ...='cd ../..'
alias ....='cd ../../..'

# acp: stage everything, commit with the given message, push the current branch
acp() {
  [ $# -eq 0 ] && { echo "Usage: acp <commit-message>"; return 1; }
  git add -A
  git commit -m "$*"
  git push -u origin HEAD
}

# mkcd: create a folder and enter it
mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}

# scroll: open the tmux scrollback in neovim
scroll() {
  nvim <(tmux capture-pane -pS - -J \
             | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba')
}

# showpath: print PATH-like variables one entry per line
# Usage: showpath [VAR_NAME] [-s|--sort]
function showpath() {
    local SORT_FLAG=0
    local varName="PATH"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--sort)
                SORT_FLAG=1
                shift
                ;;
            -*)
                echo "Usage: showpath [VAR_NAME] [-s|--sort]"
                return 1
                ;;
            *)
                varName="$1"
                shift
                ;;
        esac
    done

    local rawValue=${(P)varName}
    local -a paths

    if [[ ${(t)varName} == *array* ]]; then
        paths=( ${(P)varName} )
    else
        if [[ "$rawValue" == *:* ]]; then
            paths=( ${(s/:/)rawValue} )
        else
            paths=( ${(s/ /)rawValue} )
        fi
    fi

    if (( SORT_FLAG )); then
        printf '%s\n' "${paths[@]}" | sort
    else
        printf '%s\n' "${paths[@]}"
    fi
}

# gopass
if command -v gopass >/dev/null 2>&1; then
  source <(gopass completion zsh)
fi

# machine-local secrets, not managed by chezmoi
[[ -f "$HOME/.config/secrets.env" ]] && source "$HOME/.config/secrets.env"

# ~/.zsh: machine-local shell drop-ins (e.g. OpenMC data paths written by
# ~/.scripts/openmc_scripts/openmc_data_fetcher.sh), sourced if present.
# Not chezmoi-managed — put per-machine snippets here instead of editing ~/.zshrc.
if [[ -d "$HOME/.zsh" ]]; then
  for _zsh_dropin in "$HOME"/.zsh/*(N.); do
    source "$_zsh_dropin"
  done
  unset _zsh_dropin
fi

# autopull: refresh the dotfiles repo in the background at most every 12h;
# pull only (never an unattended `chezmoi apply`), and only when the tree is
# clean and the pull fast-forwards
if [[ -d "$HOME/.dotfiles/.git" ]]; then
  _dotfiles_stamp="$HOME/.cache/dotfiles-last-pull"
  mkdir -p "$HOME/.cache"
  if [[ ! -f "$_dotfiles_stamp" ]] || [[ -n "$(find "$_dotfiles_stamp" -mmin +720 2>/dev/null)" ]]; then
    {
      git -C "$HOME/.dotfiles" fetch --quiet &&
      git -C "$HOME/.dotfiles" diff --quiet &&
      git -C "$HOME/.dotfiles" diff --cached --quiet &&
      git -C "$HOME/.dotfiles" pull --ff-only --quiet &&
      touch "$_dotfiles_stamp"
    } >/dev/null 2>&1 &!
  fi
  unset _dotfiles_stamp
fi
