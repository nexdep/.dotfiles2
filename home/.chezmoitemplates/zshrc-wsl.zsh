# --- wsl ---

# Tell Windows WezTerm the real Linux working directory. Without OSC 7,
# WezTerm can only inspect wsl.exe and may report its Windows cwd instead.
_wezterm_osc7_cwd() {
  [[ -o interactive && -t 1 && "${TERM_PROGRAM:-}" == WezTerm ]] || return 0
  printf '\033]7;file://%s%s\033\\' "$HOST" "$PWD"
}
precmd_functions+=(_wezterm_osc7_cwd)

# Windows interop shortcuts
alias clip="clip.exe "
alias explorer='explorer.exe'
alias start='cmd.exe /c start  '

# Windows-side VS Code launcher (`code`), when installed for the Windows user
if [[ -d "/mnt/c/Users/marco/AppData/Local/Programs/Microsoft VS Code/bin" ]]; then
  path+=("/mnt/c/Users/marco/AppData/Local/Programs/Microsoft VS Code/bin")
fi
