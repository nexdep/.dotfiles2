#!/usr/bin/env bash
# Tier-aware post-bootstrap assertions. Exits non-zero if any check fails.
# Usage: tests/verify.sh <wsl|server|laptop>
#
# Check strings are deliberately single-quoted so $HOME/$(mktemp) expand at
# check time via eval, not at table-definition time.
# shellcheck disable=SC2016
set -uo pipefail

machine="${1:?usage: $0 <wsl|server|laptop>}"
# Used by the eval-based chezmoi source-directory check below.
# shellcheck disable=SC2034
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# Invoked indirectly by check().
# shellcheck disable=SC2317,SC2329
no_ansi() {
  ! LC_ALL=C grep -q $'\033' "$1"
}

bootstrap_log="$(
  find "$HOME" -maxdepth 1 -type f -name 'bootstrap-*.log' -printf '%T@ %p\n' |
    sort -nr |
    head -n1 |
    cut -d' ' -f2-
)"
check "bootstrap log created" test -n "$bootstrap_log"
check "bootstrap log contains completion marker" grep -Fq '[bootstrap] done' "$bootstrap_log"
check "bootstrap log contains child installer output" grep -Fq '[starship]' "$bootstrap_log"
check "bootstrap log is plain text" no_ansi "$bootstrap_log"

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
#  - obsidian/slack/zoom/clockify/paraview/vlc/zotero/spotify/libreoffice:
#    running --version is not safe or meaningful headless as root (obsidian
#    launches the full app and hangs, vlc exits 1 with no output), so only
#    PATH presence is checked.
#  - opencode: same story headless — `opencode --version` produces no output
#    and hangs without a TTY, so only PATH presence is checked.
#  - evolution-ews, libreoffice-help-en-us and libreoffice-gnome have no
#    executable of their own, hence dpkg -s.
#  - the spotify row is named after its binary, not its package
#    (spotify-client), so the derived absent check asserts something.
apps=(
  'core|zsh|command -v zsh'
  'core|gnupg|command -v gpg'
  'core|scdaemon|test -x /usr/lib/gnupg/scdaemon'
  'core|gopass|command -v gopass'
  'core|chezmoi|command -v chezmoi'
  'core|starship|command -v starship'
  'core|fontconfig|command -v fc-cache'
  'core|xz-utils|command -v xz'
  'core|ubuntu-mono-nerd-font|test -f /usr/local/share/fonts/UbuntuMonoNerdFont/UbuntuMonoNerdFont-Regular.ttf'
  'core|neovim|/usr/local/bin/nvim --version'
  'core|tmux|command -v tmux'
  'core|vim-gtk3|command -v vim'
  'core|ripgrep|command -v rg'
  'core|fzf|command -v fzf'
  'core|bat|command -v bat' # also proves bootstrap's bat -> batcat shim
  'core|zoxide|command -v zoxide'
  'core|git-lfs|command -v git-lfs'
  'core|gh|command -v gh'
  'core|jq|command -v jq'
  'core|btop|command -v btop'
  'core|build-essential|command -v gcc'
  'core|npm|command -v npm'
  'core|luarocks|command -v luarocks'
  'core|sqlite3|command -v sqlite3'
  'core|fd-find|command -v fd' # also proves bootstrap's fd -> fdfind shim
  'core|restic|command -v restic'
  'core|sshfs|command -v sshfs'
  'core|openssh-server|test -x /usr/sbin/sshd'
  'core|bubblewrap|command -v bwrap'
  'core|eza|command -v eza'
  'core|fastfetch|command -v fastfetch'
  'core|tailscale|command -v tailscale'
  'core|rclone|command -v rclone'
  'core|lazygit|command -v lazygit'
  'core|rust|test -x "$HOME/.cargo/bin/cargo"'
  'core|tree-sitter|test -x "$HOME/.cargo/bin/tree-sitter"'
  'core|claude|test -x "$HOME/.local/bin/claude"'
  'core|codex|test -x "$HOME/.local/bin/codex"'
  'core|cursor-agent|test -x "$HOME/.local/bin/cursor-agent"'
  'core|copilot|command -v copilot'
  'core|pi|command -v pi'
  'core|opencode|command -v opencode'
  'core|herdr|test -x "$HOME/.local/bin/herdr"'
  'core|uv|test -x "$HOME/.local/bin/uv"'
  'core|bw|command -v bw'
  'extra|gomi|command -v gomi'
  'extra|conda|test -x "$HOME/miniforge3/bin/conda"|test ! -e "$HOME/miniforge3"'
  'extra|yazi|command -v yazi && command -v ya|! command -v yazi && ! command -v ya'
  'extra|imagemagick|command -v convert'
  'extra|ffmpeg|command -v ffmpeg'
  'extra|poppler-utils|command -v pdftoppm'
  'extra|chafa|command -v chafa'
  'extra|p7zip-full|command -v 7z'
  'extra|pandoc|command -v pandoc'
  'extra|rga|command -v rga'
  'extra|dezoomify-rs|command -v dezoomify-rs'
  'extra|latexmk|command -v latexmk'
  'extra|zathura|command -v zathura'
  'extra|qt6-wayland|dpkg -s qt6-wayland|! dpkg -s qt6-wayland'
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
  'gui|libfuse2t64|dpkg -s libfuse2t64|! dpkg -s libfuse2t64'
  'gui|libreoffice|command -v libreoffice'
  'gui|libreoffice-help-en-us|dpkg -s libreoffice-help-en-us|! dpkg -s libreoffice-help-en-us'
  'gui|libreoffice-gnome|dpkg -s libreoffice-gnome|! dpkg -s libreoffice-gnome'
  'gui|spotify|command -v spotify'
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
check "chezmoi source directory persisted" eval '[[ "$(chezmoi dump-config --format json | jq -r .sourceDir)" == "$repo_dir" ]]'
check "chezmoi umask persisted" eval '[[ "$(chezmoi dump-config --format json | jq -r .umask)" == "18" ]]'
check "core zshrc fragment" grep -q -- "--- core (all machines)" "$zshrc"
check "starship config deployed" test -f "$HOME/.config/starship.toml"
check "herdr config deployed" test -f "$HOME/.config/herdr/config.toml"
check "herdr config disables onboarding" grep -q '^onboarding = false$' "$HOME/.config/herdr/config.toml"
check "herdr config valid" env HERDR_CONFIG_PATH="$HOME/.config/herdr/config.toml" "$HOME/.local/bin/herdr" config check
check "nvim config deployed" test -f "$HOME/.config/nvim/init.lua"
check "nvim lazy-lock deployed" test -f "$HOME/.config/nvim/lazy-lock.json"
check "tmux config deployed" test -f "$HOME/.config/tmux/tmux.conf"
check "vimrc deployed" test -f "$HOME/.vimrc"
check "ssh config deployed" test -f "$HOME/.ssh/config"
check "gitconfig deployed" test -f "$HOME/.gitconfig"
check "gitconfig_nexdep deployed" test -f "$HOME/.gitconfig_nexdep"
check "gitconfig_marco deployed" test -f "$HOME/.gitconfig_marco"
check "gitignore_global deployed" test -f "$HOME/.gitignore_global"
# git parses the deployed config and the global excludesFile is wired up
check "gitconfig excludesFile set" eval '[[ "$(git config --file "$HOME/.gitconfig" --get core.excludesFile)" == *".gitignore_global" ]]'
check "prompts folder deployed" test -d "$HOME/.prompts/shared"
check "prompts folder has all files" eval '[[ $(find "$HOME/.prompts/shared" -maxdepth 1 -name "*.md" | wc -l) -eq 8 ]]'
check "gpg backup script deployed" test -x "$HOME/.scripts/gpg/generate-gpg-backup.sh"
check "gpg import script deployed" test -x "$HOME/.scripts/gpg/import-gpg-key.sh"
check "hetzner scripts deployed" test -x "$HOME/.scripts/hetzner_mount/setup_hetzner_storagebox_systemd.sh"
check "openmc scripts deployed" test -x "$HOME/.scripts/openmc_scripts/openmc_data_fetcher.sh"
check "restic scripts deployed" test -x "$HOME/.scripts/restic_b2_backups/setup-restic-systemd-backup.sh"
check "hermes script deployed" test -x "$HOME/.scripts/deploy_secrets/hermes_openrouter.sh"
check "openclaw script deployed" test -x "$HOME/.scripts/deploy_secrets/openclaw_openrouter.sh"
check "gopass SSH fetch script deployed" test -x "$HOME/.scripts/deploy_secrets/fetch_ssh_keys.sh"
check "zshrc sources ~/.zsh drop-ins" grep -q 'HOME/.zsh' "$zshrc"
# the ephemeral devcontainer credential helper must not have shipped
check "no ephemeral credential helper" eval '! grep -q vscode-remote-containers "$HOME/.gitconfig_marco"'
check "zshrc initializes starship" grep -q "starship init zsh" "$zshrc"
check "zshrc initializes zoxide" grep -q "zoxide init zsh" "$zshrc"
# the zoxide cd wrapper must keep the builtin for scripts and coding agents
check "zshrc cd wrapper falls back to builtin" grep -q 'builtin cd "$@"' "$zshrc"
check "zshrc initializes fzf" grep -q "fzf --zsh" "$zshrc"
check "zshrc enables vi mode" grep -q "bindkey -v" "$zshrc"
check "zshrc sets EDITOR=nvim" grep -q "EDITOR=nvim" "$zshrc"
check "zshrc aliases ll to eza" grep -q "alias ll='eza" "$zshrc"
check "zshrc has bitwarden helpers" grep -q "bw_login" "$zshrc"
check "zshrc has dotfiles autopull" grep -q "dotfiles-last-pull" "$zshrc"
check "zshrc does not autostart tmux" eval '! grep -q "tmux attach-session\\|tmux new-session" "$zshrc"'
check "dircolors deployed" test -f "$HOME/.dircolors"
check "login shell is zsh" test "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)"
# bootstrap never imports the personal GPG key (that's the manual
# ~/.scripts/gpg/import-gpg-key.sh), so no secret key may exist here.
check "no gpg secret key imported by bootstrap" eval '! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q "^sec"'
# The gopass store is a public repo cloned keylessly on every tier; the push
# URL must have been switched to SSH.
check "gopass store cloned" test -d "$HOME/.local/share/gopass/stores/root/.git"
check "gopass store push url is ssh" eval '[[ "$(git -C "$HOME/.local/share/gopass/stores/root" remote get-url --push origin)" == git@* ]]'
check "wezterm config deployed" test -f "$HOME/.wezterm.lua"
check "wezterm uses Ctrl-a leader" grep -q 'config.leader = {' "$HOME/.wezterm.lua"
check "wezterm has tmux-style splits" eval 'grep -q "act.SplitHorizontal" "$HOME/.wezterm.lua" && grep -q "act.SplitVertical" "$HOME/.wezterm.lua"'
check "wezterm has tmux-style pane navigation" grep -q 'act.ActivatePaneDirection' "$HOME/.wezterm.lua"
check "wezterm has tmux-style tab navigation" grep -q 'act.ActivateTabRelative' "$HOME/.wezterm.lua"
check "wezterm has tmux-style copy mode" grep -q 'act.ActivateCopyMode' "$HOME/.wezterm.lua"

if [[ "$machine" != server ]]; then
  check "condarc deployed" test -f "$HOME/.condarc"
  check "zshrc initializes conda" grep -q "miniforge3/etc/profile.d/conda.sh" "$zshrc"
  check "workstation zshrc fragment" grep -q -- "--- workstation (laptop/wsl)" "$zshrc"
  check "no server zshrc fragment" eval '! grep -q -- "--- server ---" "$zshrc"'
  check "zshrc defines y wrapper" grep -q "function y()" "$zshrc"
  check "yazi config deployed" test -f "$HOME/.config/yazi/yazi.toml"
  # proves the ya pkg run script installed the plugins pinned in package.toml
  check "yazi fg plugin installed" test -d "$HOME/.config/yazi/plugins/fg.yazi"
  check "yazi zsh completions installed" test -f /usr/local/share/zsh/site-functions/_yazi
  check "neutronics drop-in deployed" test -f "$HOME/.zsh/neutronics.zsh"
  check "gomi config deployed" test -f "$HOME/.config/gomi/config.yaml"
else
  check "server zshrc fragment" grep -q -- "--- server ---" "$zshrc"
  check "no workstation zshrc fragment" eval '! grep -q -- "--- workstation (laptop/wsl)" "$zshrc"'
  check "yazi config absent" test ! -e "$HOME/.config/yazi"
  check "neutronics drop-in absent" test ! -e "$HOME/.zsh/neutronics.zsh"
  check "gomi config absent" test ! -e "$HOME/.config/gomi"
fi

if [[ "$machine" == laptop ]]; then
  check "wezterm config parses" wezterm --config-file "$HOME/.wezterm.lua" show-keys
fi

# The yazi "open" opener is templated per machine: explorer.exe (via WSL
# interop) on wsl, xdg-open on the laptop.
if [[ "$machine" == wsl ]]; then
  check "yazi opener uses explorer.exe" grep -q "explorer.exe" "$HOME/.config/yazi/yazi.toml"
elif [[ "$machine" == laptop ]]; then
  check "yazi opener uses xdg-open" grep -Fq 'xdg-open %s1' "$HOME/.config/yazi/yazi.toml"
fi

# WSL-only quiet-login markers (deployed via home/.chezmoiignore). Present on
# wsl, absent on server/laptop.
for marker in .hushlogin .motd_shown .sudo_as_admin_successful; do
  if [[ "$machine" == wsl ]]; then
    check "wsl marker $marker deployed" test -f "$HOME/$marker"
  else
    check "wsl marker $marker absent" test ! -e "$HOME/$marker"
  fi
done

# WSL-only zshrc fragment.
if [[ "$machine" == wsl ]]; then
  check "zshrc has wsl clip alias" grep -q "clip.exe" "$zshrc"
else
  check "no wsl clip alias in zshrc" eval '! grep -q "clip.exe" "$zshrc"'
fi

# OneDrive symlinks (lib/install-onedrive-links.sh). Real WSL machines have a
# Windows profile under /mnt/c/Users with OneDrive folders; the CI wsl leg
# (plain ubuntu container, no /mnt/c) must have self-skipped and created
# nothing at the managed ~/onedrive* names.
if [[ "$machine" == wsl ]]; then
  onedrive_dirs=(/mnt/c/Users/*/OneDrive*/)
  if [[ -d "${onedrive_dirs[0]:-}" ]]; then
    check "onedrive symlink(s) created" eval 'find "$HOME" -maxdepth 1 -name "onedrive*" -type l | grep -q .'
    check "onedrive symlinks resolve" eval '! find "$HOME" -maxdepth 1 -name "onedrive*" -type l ! -exec test -d {}/. \; -print | grep -q .'
  else
    check "onedrive links skipped (no /mnt/c)" eval '! find "$HOME" -maxdepth 1 -name "onedrive*" | grep -q .'
  fi
fi

exit "$fail"
