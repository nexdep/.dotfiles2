#!/usr/bin/env bash
# GUI programs (laptop only):
#   - Firefox Developer Edition from Mozilla's official apt repository
#     (packages.mozilla.org), pinned above Ubuntu's snap-transition stubs.
#   - Thunderbird Beta from the official Mozilla tarball into /opt.
#     Neither packages.mozilla.org nor a maintained PPA ships a Thunderbird
#     beta channel for this Ubuntu release, so the tarball is the supported
#     path; the app keeps itself updated via its internal updater.
#   - WezTerm (wezterm-nightly) from WezTerm's official apt repository
#     (apt.fury.io/wez), a flat Gemfury repo (Codename/Component both "*").
set -euo pipefail

log() { printf '\033[1;34m[gui]\033[0m %s\n' "$*"; }

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi
export DEBIAN_FRONTEND=noninteractive

# --- Firefox Developer Edition (apt) -----------------------------------------
keyring=/etc/apt/keyrings/packages.mozilla.org.asc
if [[ ! -f "$keyring" ]]; then
  log "adding Mozilla apt repository"
  $SUDO install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | $SUDO tee "$keyring" >/dev/null
fi
echo "deb [signed-by=$keyring] https://packages.mozilla.org/apt mozilla main" |
  $SUDO tee /etc/apt/sources.list.d/mozilla.list >/dev/null
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' |
  $SUDO tee /etc/apt/preferences.d/mozilla >/dev/null

$SUDO apt-get update
log "installing firefox-devedition"
$SUDO apt-get install -y firefox-devedition

# --- Thunderbird Beta (Mozilla tarball) ---------------------------------------
if [[ -x /opt/thunderbird-beta/thunderbird ]]; then
  log "thunderbird beta already installed, skipping (it self-updates)"
else
  url='https://download.mozilla.org/?product=thunderbird-beta-latest-SSL&os=linux64&lang=en-US'
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  log "downloading thunderbird beta tarball"
  curl -fsSL -o "$tmp/thunderbird.tar" "$url"
  mkdir "$tmp/extract"
  tar -xf "$tmp/thunderbird.tar" -C "$tmp/extract"
  $SUDO rm -rf /opt/thunderbird-beta
  $SUDO mv "$tmp/extract/thunderbird" /opt/thunderbird-beta
  $SUDO ln -sf /opt/thunderbird-beta/thunderbird /usr/local/bin/thunderbird-beta

  $SUDO install -d -m 0755 /usr/local/share/applications
  $SUDO tee /usr/local/share/applications/thunderbird-beta.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Thunderbird Beta
Comment=Mail client (beta channel)
Exec=/opt/thunderbird-beta/thunderbird %u
Icon=/opt/thunderbird-beta/chrome/icons/default/default256.png
Type=Application
Terminal=false
Categories=Network;Email;
MimeType=x-scheme-handler/mailto;message/rfc822;
EOF
  log "installed thunderbird beta to /opt/thunderbird-beta"
fi

# --- WezTerm nightly (apt) -----------------------------------------------------
keyring=/etc/apt/keyrings/wezterm-fury.asc
if [[ ! -f "$keyring" ]]; then
  log "adding WezTerm apt repository"
  $SUDO install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://apt.fury.io/wez/gpg.key | $SUDO tee "$keyring" >/dev/null
fi
echo "deb [signed-by=$keyring] https://apt.fury.io/wez/ * *" |
  $SUDO tee /etc/apt/sources.list.d/wezterm.list >/dev/null

$SUDO apt-get update
log "installing wezterm-nightly"
$SUDO apt-get install -y wezterm-nightly
