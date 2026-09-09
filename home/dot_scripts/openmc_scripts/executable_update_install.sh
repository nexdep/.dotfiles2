#!/usr/bin/env bash
# Update an OpenMC source checkout and refresh its development installation.
#
# Run from anywhere inside the repository. Set OPENMC_BUILD_DIR to reuse a
# non-default build directory, or OPENMC_BUILD_TYPE when creating a new one.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Refusing to update: tracked files have local changes." >&2
  echo "Commit or stash them, then run this script again." >&2
  exit 1
fi

git pull --ff-only --recurse-submodules
git submodule update --init --recursive

build_dir=${OPENMC_BUILD_DIR:-"$repo_root/build"}
if [[ ! -f "$build_dir/CMakeCache.txt" ]]; then
  cmake -S "$repo_root" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE="${OPENMC_BUILD_TYPE:-RelWithDebInfo}"
else
  cmake -S "$repo_root" -B "$build_dir"
fi

cmake --build "$build_dir" --parallel

python3 -m pip install --editable .
