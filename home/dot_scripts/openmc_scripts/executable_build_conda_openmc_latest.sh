#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# OpenMC Development Environment Setup Script
# -----------------------------------------------------------------------------
# This script:
# 1. Creates a fresh conda environment with required dependencies
# 2. Clones the OpenMC repository (develop branch)
# 3. Creates a workspace at $PWD/$ENV_NAME and clones OpenMC into it
# 4. Optionally downloads OpenMC nuclear data into that workspace
# 5. If downloaded, sets its paths only in this conda environment
# 6. Builds and installs OpenMC from source into the conda environment
# 7. Installs Python bindings + testing extras
# 8. Verifies the installation
# -----------------------------------------------------------------------------

set -euo pipefail

# ---------------------------
# Configuration
# ---------------------------
ENV_NAME="openmc-dev-latest" # Name of the conda environment
GH_PROFILE="openmc-dev"
PY_VER="3.14"
DOWNLOAD_NUCLEAR_DATA=false


# Keep the repository, build tree, and optional nuclear data together.
ROOT_DIR="$PWD/$ENV_NAME"
mkdir -p "$ROOT_DIR"

# ---------------------------
# Create conda environment
# ---------------------------
echo "Creating conda environment: $ENV_NAME"

conda create -y -n "$ENV_NAME" \
  python="$PY_VER" \
  cmake make git compilers hdf5 pip numba wget curl \
  -c conda-forge

# ---------------------------
# Activate environment
# ---------------------------
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"

echo "Activated environment: $ENV_NAME"

# ---------------------------
# Clone OpenMC repository
# ---------------------------
echo "Cloning OpenMC (develop branch)"

git clone --recurse-submodules \
  --branch develop \
  "https://github.com/$GH_PROFILE/openmc.git" \
  "$ROOT_DIR/openmc"

cd "$ROOT_DIR/openmc"

git checkout develop
git submodule update --init --recursive

# ---------------------------
# Optionally download nuclear data locally
# ---------------------------
if [[ "$DOWNLOAD_NUCLEAR_DATA" == true ]]; then
  echo "Downloading OpenMC nuclear data into: $ROOT_DIR"

  HOME="$ROOT_DIR" bash tools/ci/download-xs.sh

  # Paths created by tools/ci/download-xs.sh when HOME is overridden
  NNDC_XS="$ROOT_DIR/nndc_hdf5/cross_sections.xml"
  ENDF_DATA="$ROOT_DIR/endf-b-vii.1"

  # Sanity checks
  test -f "$NNDC_XS"
  test -d "$ENDF_DATA"

  # Set data paths only in this conda environment.
  echo "Setting conda environment variables"

  conda env config vars set \
    XS_NNDC="$NNDC_XS" \
    OPENMC_ENDF_DATA="$ENDF_DATA"

  # Reload environment so variables take effect in this shell.
  conda deactivate
  conda activate "$ENV_NAME"

  echo "XS_NNDC=$XS_NNDC"
  echo "OPENMC_ENDF_DATA=$OPENMC_ENDF_DATA"
else
  echo "Skipping OpenMC nuclear data download (pass --download-nuclear-data to enable it)"
fi

# ---------------------------
# Build OpenMC
# ---------------------------
echo "Building OpenMC"

mkdir -p build
cd build

cmake -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" -DOPENMC_ENABLE_STRICT_FP=on ..

make -j"$(nproc)"
make install

# ---------------------------
# Install Python bindings
# ---------------------------
cd ..

echo "Installing Python package (editable mode with tests)"

pip install -e '.[test]'
pip install PySide6
pip install openmc-plotter --no-deps
pip install neutronics_material_maker



# ---------------------------
# Verification
# ---------------------------
echo "Verifying installation"

python - <<EOF
import os
import openmc
import numba

print("openmc:", openmc.__version__)
print("numba:", numba.__version__)
print("XS_NNDC:", os.environ.get("XS_NNDC"))
print("OPENMC_ENDF_DATA:", os.environ.get("OPENMC_ENDF_DATA"))
EOF

echo "OpenMC executable location:"
which openmc

echo "Setup complete!"
