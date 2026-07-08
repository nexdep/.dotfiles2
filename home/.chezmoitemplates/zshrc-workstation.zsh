# --- workstation (laptop/wsl) ---

# gomi: send files to the trash instead of deleting them outright
if command -v gomi >/dev/null 2>&1; then
  alias rm='gomi'
fi

# conda (miniforge): base env auto-activated, PROMPT untouched (changeps1:
# false in ~/.condarc) since starship's conda module already shows the env
if [[ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]]; then
  . "$HOME/miniforge3/etc/profile.d/conda.sh"
  conda activate base
fi
