# --- workstation (laptop/wsl) ---

# gomi: send files to the trash instead of deleting them outright
if command -v gomi >/dev/null 2>&1; then
  alias rm='gomi'
fi
