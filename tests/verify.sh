#!/usr/bin/env bash
# Tier-aware post-bootstrap assertions. Exits non-zero if any check fails.
# Usage: tests/verify.sh <wsl|server|laptop>
set -uo pipefail

machine="${1:?usage: $0 <wsl|server|laptop>}"
zshrc="$HOME/.zshrc"
fail=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'ok    %s\n' "$desc"
  else
    printf 'FAIL  %s\n' "$desc"
    fail=1
  fi
}

# invoked indirectly through check()
# shellcheck disable=SC2317,SC2329
absent() { ! command -v "$1" >/dev/null 2>&1; }
# shellcheck disable=SC2317,SC2329
has_fragment() { grep -q -- "--- $1" "$zshrc"; }
# shellcheck disable=SC2317,SC2329
no_fragment() { ! grep -q -- "--- $1" "$zshrc"; }
# shellcheck disable=SC2317,SC2329
pkg_absent() { ! dpkg -s "$1" >/dev/null 2>&1; }

echo "== verify machine=$machine =="

# core tier: every machine
check "zsh installed" command -v zsh
check "gopass installed" command -v gopass
check "chezmoi installed" command -v chezmoi
check ".zshrc deployed" test -f "$zshrc"
check ".zshrc parses" zsh -n "$zshrc"
check "core zshrc fragment" has_fragment "core (all machines)"
check "login shell is zsh" test "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)"
check "starship installed" command -v starship
check "starship config deployed" test -f "$HOME/.config/starship.toml"
check "zshrc initializes starship" grep -q "starship init zsh" "$zshrc"

# extra tier: laptop + wsl
if [[ "$machine" != server ]]; then
  check "gomi installed" command -v gomi
  check "conda installed" test -x "$HOME/miniforge3/bin/conda"
  check "condarc deployed" test -f "$HOME/.condarc"
  check "zshrc initializes conda" grep -q "miniforge3/etc/profile.d/conda.sh" "$zshrc"
  check "workstation zshrc fragment" has_fragment "workstation (laptop/wsl)"
  check "no server zshrc fragment" no_fragment "server ---"
else
  check "gomi absent" absent gomi
  check "conda absent" test ! -e "$HOME/miniforge3"
  check "server zshrc fragment" has_fragment "server ---"
  check "no workstation zshrc fragment" no_fragment "workstation (laptop/wsl)"
fi

# gui tier: laptop only
if [[ "$machine" == laptop ]]; then
  check "firefox-devedition installed" firefox-devedition --version
  check "thunderbird beta installed" /usr/local/bin/thunderbird-beta --version
  check "wezterm-nightly installed" wezterm --version
  # --no-sandbox + --user-data-dir: Electron refuses to run as root (this CI
  # container) without both; not needed for normal (non-root) use on the
  # real machine.
  check "code-insiders installed" \
    code-insiders --version --no-sandbox --user-data-dir="$(mktemp -d)"
  # obsidian ignores --version and launches the full app instead of exiting,
  # so (unlike the other GUI apps here) just check the binary is on PATH.
  check "obsidian installed" command -v obsidian
  check "evolution installed" command -v evolution
  # evolution-ews is a backend module with no executable of its own.
  check "evolution-ews installed" dpkg -s evolution-ews
else
  check "firefox-devedition absent" absent firefox-devedition
  check "thunderbird beta absent" test ! -e /usr/local/bin/thunderbird-beta
  check "wezterm absent" absent wezterm
  check "code-insiders absent" absent code-insiders
  check "obsidian absent" absent obsidian
  check "evolution absent" absent evolution
  check "evolution-ews absent" pkg_absent evolution-ews
fi

exit "$fail"
