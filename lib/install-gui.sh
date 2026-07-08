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
#   - VS Code Insiders (code-insiders) from Microsoft's official apt
#     repository (packages.microsoft.com/repos/code).
#   - Obsidian from the official .deb release on GitHub. Obsidian has no
#     apt repo and release filenames embed the version, so the latest tag
#     is resolved via GitHub's releases/latest redirect (no jq dependency).
#   - Google Chrome from the official .deb at dl.google.com (fixed URL, no
#     version to resolve). Its postinst self-registers Google's apt repo,
#     so unlike Obsidian it updates with a normal apt upgrade afterwards.
#   - Slack from the official .deb at downloads.slack-edge.com. Like
#     Obsidian, release filenames embed the version and there's no apt
#     repo, so the latest version is scraped from Slack's own downloads
#     page (Slack publishes no versioned API or GitHub releases for this).
#   - Zoom from the official .deb at zoom.us/client/latest (fixed URL, no
#     version to resolve, like Google Chrome). No apt repo is published.
#   - ParaView from the official Kitware build: a tarball (no .deb/apt repo
#     exists), so it follows the Thunderbird Beta pattern (/opt + symlink).
#     The latest version is resolved from paraview.org's directory listing.
#   - Zotero via the community apt repo's own install script, exactly as
#     documented at https://zotero.retorque.re/file/apt-package-archive/
#     (zotero.org itself only distributes a tarball; this repo is the
#     de facto standard apt source, referenced from zotero.org's own docs).
set -euo pipefail

log() { printf '\033[1;34m[gui]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[gui]\033[0m %s\n' "$*" >&2; exit 1; }

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
  rm -rf "$tmp"
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

# --- VS Code Insiders (apt) -----------------------------------------------------
keyring=/etc/apt/keyrings/packages.microsoft.asc
if [[ ! -f "$keyring" ]]; then
  log "adding Microsoft apt repository"
  $SUDO install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | $SUDO tee "$keyring" >/dev/null
fi
echo "deb [arch=amd64,arm64,armhf signed-by=$keyring] https://packages.microsoft.com/repos/code stable main" |
  $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null

$SUDO apt-get update
log "installing code-insiders"
$SUDO apt-get install -y code-insiders

# --- Obsidian (official .deb) ---------------------------------------------------
if command -v obsidian >/dev/null 2>&1; then
  log "obsidian already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "obsidian: unsupported architecture $(uname -m) (only amd64 .deb is published)"

  tag="$(curl -fsSL -I -o /dev/null -w '%{url_effective}' \
    https://github.com/obsidianmd/obsidian-releases/releases/latest | sed 's#.*/tag/##')"
  version="${tag#v}"
  url="https://github.com/obsidianmd/obsidian-releases/releases/download/${tag}/obsidian_${version}_amd64.deb"

  tmp="$(mktemp -d)"
  log "downloading obsidian $version"
  curl -fsSL "$url" -o "$tmp/obsidian.deb"
  $SUDO apt-get install -y "$tmp/obsidian.deb"
  rm -rf "$tmp"
fi

# --- Google Chrome (official .deb) -----------------------------------------------
if command -v google-chrome >/dev/null 2>&1; then
  log "google chrome already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "google-chrome: unsupported architecture $(uname -m) (only amd64 .deb is published)"

  tmp="$(mktemp -d)"
  log "downloading google chrome"
  curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$tmp/google-chrome.deb"
  $SUDO apt-get install -y "$tmp/google-chrome.deb"
  rm -rf "$tmp"
fi

# --- Slack (official .deb) --------------------------------------------------------
if command -v slack >/dev/null 2>&1; then
  log "slack already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "slack: unsupported architecture $(uname -m) (only amd64 .deb is published)"

  url="$(curl -fsSL 'https://slack.com/downloads/instructions/linux?ddl=1&build=deb' |
    grep -oE 'https://downloads\.slack-edge\.com/desktop-releases/linux/x64/[0-9.]+/slack-desktop-[0-9.]+-amd64\.deb' |
    head -n1)"
  [[ -n "$url" ]] || die "slack: could not find the latest .deb download URL"

  tmp="$(mktemp -d)"
  log "downloading slack ($url)"
  curl -fsSL "$url" -o "$tmp/slack.deb"
  $SUDO apt-get install -y "$tmp/slack.deb"
  rm -rf "$tmp"
fi

# --- Zoom (official .deb) ---------------------------------------------------------
if command -v zoom >/dev/null 2>&1; then
  log "zoom already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "zoom: unsupported architecture $(uname -m) (only amd64 .deb is published)"

  tmp="$(mktemp -d)"
  log "downloading zoom"
  curl -fsSL https://zoom.us/client/latest/zoom_amd64.deb -o "$tmp/zoom.deb"
  $SUDO apt-get install -y "$tmp/zoom.deb"
  rm -rf "$tmp"
fi

# --- ParaView (official Kitware tarball) -------------------------------------------
if [[ -x /opt/paraview/bin/paraview ]]; then
  log "paraview already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "paraview: unsupported architecture $(uname -m) (only x86_64 builds are published)"

  minor="$(curl -fsSL https://www.paraview.org/files/ |
    grep -oE 'href="v[0-9]+\.[0-9]+/"' | sed -E 's/href="v(.*)\/"/\1/' | sort -V | tail -n1)"
  filename="$(curl -fsSL "https://www.paraview.org/files/v${minor}/" |
    grep -oE 'href="ParaView-[0-9.]+-MPI-Linux-Python3\.[0-9]+-x86_64\.tar\.gz"' |
    sed -E 's/href="(.*)"/\1/' | sort -V | tail -n1)"
  [[ -n "$minor" && -n "$filename" ]] || die "paraview: could not find the latest Linux build"
  url="https://www.paraview.org/files/v${minor}/${filename}"

  tmp="$(mktemp -d)"
  log "downloading paraview ($filename)"
  curl -fsSL "$url" -o "$tmp/paraview.tar.gz"
  mkdir "$tmp/extract"
  tar -xzf "$tmp/paraview.tar.gz" -C "$tmp/extract"
  extracted="$(find "$tmp/extract" -mindepth 1 -maxdepth 1 -type d)"
  $SUDO rm -rf /opt/paraview
  $SUDO mv "$extracted" /opt/paraview
  $SUDO ln -sf /opt/paraview/bin/paraview /usr/local/bin/paraview

  $SUDO install -d -m 0755 /usr/local/share/applications
  $SUDO tee /usr/local/share/applications/paraview.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=ParaView
Comment=Data analysis and visualization application
Exec=/opt/paraview/bin/paraview
Icon=/opt/paraview/share/icons/hicolor/96x96/apps/paraview.png
Type=Application
Terminal=false
Categories=Graphics;Science;
EOF
  rm -rf "$tmp"
  log "installed paraview $filename to /opt/paraview"
fi

# --- Zotero (official community apt repo) -------------------------------------------
if command -v zotero >/dev/null 2>&1; then
  log "zotero already installed, skipping"
else
  # zotero-pkg's install.sh calls `sudo` internally regardless of how it's
  # invoked, so make sure sudo exists even when we're already root (bare
  # containers usually don't ship it).
  command -v sudo >/dev/null 2>&1 || $SUDO apt-get install -y sudo

  log "installing zotero apt repository"
  curl -sL https://raw.githubusercontent.com/retorquere/zotero-pkg/master/install.sh | sudo bash

  $SUDO apt-get update
  log "installing zotero"
  $SUDO apt-get install -y zotero
fi
