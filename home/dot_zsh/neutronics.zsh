# Neutronics helpers (laptop/wsl; deployed by chezmoi — the rest of ~/.zsh is
# manual machine-local drop-ins).

# lazy load openfoam12
if [[ -f /opt/openfoam12/etc/bashrc ]]; then
  of12() {
    . /opt/openfoam12/etc/bashrc
  }
fi

# OpenMC data paths (endf/b viii.0 cross sections + endfb81 fast chain, as
# downloaded by ~/.scripts/openmc_scripts/openmc_data_fetcher.sh)
export OPENMC_CROSS_SECTIONS="$HOME/openmc_data/endfb-viii.0-hdf5/cross_sections.xml"
export OPENMC_CHAIN_FILE="$HOME/openmc_data/chain_endfb81_fast/chain_endfb81_fast.xml"
export ENDFB81_XS="$OPENMC_CROSS_SECTIONS"
