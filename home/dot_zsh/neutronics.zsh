# Neutronics helpers (laptop/wsl; deployed by chezmoi — the rest of ~/.zsh is
# manual machine-local drop-ins).

# lazy load openfoam12
if [[ -f /opt/openfoam12/etc/bashrc ]]; then
  of12() {
    . /opt/openfoam12/etc/bashrc
  }
fi

