# --- workstation (laptop/wsl) ---

# yazi: `y` opens the file manager and cd's to where you quit
if command -v yazi >/dev/null 2>&1; then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
  }
fi

# conda (miniforge): base env auto-activated, PROMPT untouched (changeps1:
# false in ~/.condarc) since starship's conda module already shows the env
if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
  . "$HOME/miniforge3/etc/profile.d/conda.sh"
  conda activate base
fi
