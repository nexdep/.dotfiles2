# --- wsl ---

# Windows interop shortcuts
alias clip="clip.exe "
alias start='cmd.exe /c start  '

# Windows-side VS Code launcher (`code`), when installed for the Windows user
if [[ -d "/mnt/c/Users/marco/AppData/Local/Programs/Microsoft VS Code/bin" ]]; then
  path+=("/mnt/c/Users/marco/AppData/Local/Programs/Microsoft VS Code/bin")
fi
