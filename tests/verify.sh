#!/usr/bin/env bash
# Tier-aware post-bootstrap assertions. Exits non-zero if any check fails.
# Usage: tests/verify.sh <wsl|server|laptop>
#
# Check strings are deliberately single-quoted so $HOME/$(mktemp) expand at
# check time via eval, not at table-definition time.
# shellcheck disable=SC2016
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

# Tiers and machines share a rank: an app is asserted present on machines at
# or above its tier and absent below it (laptop ⊃ wsl ⊃ server).
rank() {
  case "$1" in
    core | server) echo 0 ;;
    extra | wsl) echo 1 ;;
    gui | laptop) echo 2 ;;
    *) echo "unknown tier/machine: $1" >&2; exit 1 ;;
  esac
}

# One row per program: 'tier|name|present-check[|absent-check]'.
# Default absent check: the command is not on PATH.
# Notes on the present checks:
#  - code-insiders: Electron refuses to run as root (this CI container)
#    without --no-sandbox and an explicit --user-data-dir; both flags are
#    harmless for normal (non-root) use on the real machine.
#  - obsidian/slack/zoom/clockify/paraview/vlc/zotero: running --version is
#    not safe or meaningful headless as root (obsidian launches the full app
#    and hangs, vlc exits 1 with no output), so only PATH presence is checked.
#  - evolution-ews is a backend module with no executable, hence dpkg -s.
apps=(
  'core|zsh|command -v zsh'
  'core|gnupg|command -v gpg'
  'core|gopass|command -v gopass'
  'core|chezmoi|command -v chezmoi'
  'core|starship|command -v starship'
  'extra|gomi|command -v gomi'
  'extra|conda|test -x "$HOME/miniforge3/bin/conda"|test ! -e "$HOME/miniforge3"'
  'gui|firefox-devedition|firefox-devedition --version'
  'gui|thunderbird-beta|/usr/local/bin/thunderbird-beta --version|test ! -e /usr/local/bin/thunderbird-beta'
  'gui|wezterm|wezterm --version'
  'gui|code-insiders|code-insiders --version --no-sandbox --user-data-dir="$(mktemp -d)"'
  'gui|obsidian|command -v obsidian'
  'gui|evolution|command -v evolution'
  'gui|evolution-ews|dpkg -s evolution-ews|! dpkg -s evolution-ews'
  'gui|google-chrome|google-chrome --version'
  'gui|slack|command -v slack'
  'gui|zoom|command -v zoom'
  'gui|paraview|command -v paraview'
  'gui|vlc|command -v vlc'
  'gui|zotero|command -v zotero'
  'gui|clockify|command -v clockify'
)

echo "== verify machine=$machine =="
machine_rank="$(rank "$machine")"

for entry in "${apps[@]}"; do
  IFS='|' read -r tier name present absent <<<"$entry"
  if (( machine_rank >= $(rank "$tier") )); then
    check "$name installed" eval "$present"
  else
    check "$name absent" eval "${absent:-! command -v $name}"
  fi
done

# --- configuration checks (not simple present/absent pairs) --------------------
check ".zshrc deployed" test -f "$zshrc"
check ".zshrc parses" zsh -n "$zshrc"
check "core zshrc fragment" grep -q -- "--- core (all machines)" "$zshrc"
check "starship config deployed" test -f "$HOME/.config/starship.toml"
check "zshrc initializes starship" grep -q "starship init zsh" "$zshrc"
check "login shell is zsh" test "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)"
# install-gpg-key.sh must skip the personal key import when there is no TTY
# (as in CI), so no secret key may exist here.
check "gpg key import skipped (no TTY)" eval '! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q "^sec"'

if [[ "$machine" != server ]]; then
  check "condarc deployed" test -f "$HOME/.condarc"
  check "zshrc initializes conda" grep -q "miniforge3/etc/profile.d/conda.sh" "$zshrc"
  check "workstation zshrc fragment" grep -q -- "--- workstation (laptop/wsl)" "$zshrc"
  check "no server zshrc fragment" eval '! grep -q -- "--- server ---" "$zshrc"'
else
  check "server zshrc fragment" grep -q -- "--- server ---" "$zshrc"
  check "no workstation zshrc fragment" eval '! grep -q -- "--- workstation (laptop/wsl)" "$zshrc"'
fi

exit "$fail"
