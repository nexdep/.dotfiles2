#!/usr/bin/env bash
# GUI programs (laptop only). Structure: register all third-party apt repos,
# run ONE apt-get update, install the apt-based apps together, then handle
# the tarball/.deb apps. Per-app install-method notes:
#   - Firefox Developer Edition from Mozilla's official apt repository
#     (packages.mozilla.org), with firefox* pinned above Ubuntu's
#     snap-transition stubs.
#   - WezTerm (wezterm-nightly) from WezTerm's official apt repository
#     (apt.fury.io/wez), a flat Gemfury repo (Codename/Component both "*").
#   - VS Code Insiders (code-insiders) from Microsoft's official apt
#     repository (packages.microsoft.com/repos/code).
#   - Spotify (spotify-client) from Spotify's official apt repository
#     (repository.spotify.com), which publishes amd64 only.
#   - Zotero via the community apt repo's own install script, exactly as
#     documented at https://zotero.retorque.re/file/apt-package-archive/
#     (zotero.org itself only distributes a tarball; this repo is the
#     de facto standard apt source, referenced from zotero.org's own docs).
#   - Thunderbird Beta from the official Mozilla tarball into /opt: no apt
#     source ships a beta channel for this release. The install dir is
#     chowned to the user so the app's internal updater can write to it.
#   - Obsidian from the official .deb release on GitHub: no apt repo, and
#     release filenames embed the version, so the latest tag is resolved
#     via GitHub's releases/latest redirect (no jq dependency).
#   - Google Chrome from the official .deb at dl.google.com (fixed URL).
#     Its postinst self-registers Google's apt repo, so unlike the other
#     .deb apps it updates with a normal apt upgrade afterwards.
#   - Slack from the official .deb at downloads.slack-edge.com: no apt repo
#     or GitHub releases, so the latest URL is scraped from Slack's own
#     downloads page.
#   - Zoom from the official .deb at zoom.us/client/latest (fixed URL).
#   - Clockify from the official .deb at clockify.me/downloads (fixed URL
#     per arch), per clockify.me/linux-time-tracking.
set -euo pipefail

LOG_TAG=gui
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# --- third-party apt repositories ----------------------------------------------
add_apt_repo mozilla https://packages.mozilla.org/apt/repo-signing-key.gpg \
  "" "https://packages.mozilla.org/apt mozilla main"
printf 'Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' |
  $SUDO tee /etc/apt/preferences.d/mozilla >/dev/null

add_apt_repo wezterm https://apt.fury.io/wez/gpg.key \
  "" "https://apt.fury.io/wez/ * *"

add_apt_repo vscode https://packages.microsoft.com/keys/microsoft.asc \
  "arch=amd64,arm64,armhf" "https://packages.microsoft.com/repos/code stable main"

add_apt_repo spotify https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
  "arch=amd64" "https://repository.spotify.com stable non-free"

# Zotero's repo ships its own installer that writes zotero.list plus the
# keyring; use it as documented. It calls `sudo` internally regardless of
# how it's invoked, so make sure sudo exists even when already root (bare
# containers usually don't ship it).
if [[ ! -f /etc/apt/sources.list.d/zotero.list ]]; then
  command -v sudo >/dev/null 2>&1 || $SUDO apt-get install -y sudo
  log "adding zotero apt repository"
  curl -sL https://raw.githubusercontent.com/retorquere/zotero-pkg/master/install.sh | sudo bash
fi

# --- apt-installed GUI apps ------------------------------------------------------
apt_update
log "installing firefox-devedition, wezterm-nightly, code-insiders, zotero, spotify-client"
# libasound2t64 is named explicitly for spotify-client's sake: spotify depends
# on the pre-t64 name `libasound2`, which two packages provide — libasound2t64
# (real ALSA) and liboss4-salsa-asound2 (an OSS4 shim that Conflicts with it).
# apt picks the OSS4 shim when nothing has pulled ALSA in yet, so pin the real
# one rather than rely on an earlier package list having done it.
$SUDO apt-get install -y firefox-devedition wezterm-nightly code-insiders zotero \
  libasound2t64 spotify-client

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
  # the internal updater runs as the user, so it needs write access to /opt
  $SUDO chown -R "$(id -un):$(id -gn)" /opt/thunderbird-beta
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

# --- ParaView (official Kitware tarball) -------------------------------------------
# No .deb or apt repo exists; /opt + symlink like Thunderbird Beta. The
# newest complete stable Linux build is resolved from paraview.org's directory
# listing; newly created release directories may initially contain only RCs.
if [[ -x /opt/paraview/bin/paraview ]]; then
  log "paraview already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "paraview: unsupported architecture $(uname -m) (only x86_64 builds are published)"

  root_index="$(curl -fsSL https://www.paraview.org/files/)" ||
    die "paraview: could not fetch the release index"
  minor_versions=()
  mapfile -t minor_versions < <(
    printf '%s\n' "$root_index" |
      grep -oE 'href="v[0-9]+\.[0-9]+/"' |
      sed -E 's/^href="v([^"]+)\/"$/\1/' |
      sort -Vr
  )
  ((${#minor_versions[@]} > 0)) ||
    die "paraview: release index contains no version directories"

  minor=
  filename=
  for candidate_minor in "${minor_versions[@]}"; do
    release_index="$(curl -fsSL "https://www.paraview.org/files/v${candidate_minor}/")" ||
      die "paraview: could not fetch the release index for v${candidate_minor}"
    candidate_filenames=()
    mapfile -t candidate_filenames < <(
      printf '%s\n' "$release_index" |
        grep -oE 'href="ParaView-[0-9]+(\.[0-9]+)+-MPI-Linux-Python3\.[0-9]+-x86_64\.tar\.gz"' |
        sed -E 's/^href="([^"]+)"$/\1/' |
        sort -V
    )
    if ((${#candidate_filenames[@]} > 0)); then
      minor="$candidate_minor"
      filename="${candidate_filenames[-1]}"
      break
    fi
  done
  [[ -n "$minor" && -n "$filename" ]] ||
    die "paraview: could not find a stable Linux build"

  tmp="$(mktemp -d)"
  log "downloading paraview ($filename)"
  curl -fsSL "https://www.paraview.org/files/v${minor}/${filename}" -o "$tmp/paraview.tar.gz"
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

# --- apps installed from an official .deb ------------------------------------------
if command -v obsidian >/dev/null 2>&1; then
  log "obsidian already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "obsidian: unsupported architecture $(uname -m) (only amd64 .deb is published)"
  tag="$(curl -fsSL -I -o /dev/null -w '%{url_effective}' \
    https://github.com/obsidianmd/obsidian-releases/releases/latest | sed 's#.*/tag/##')"
  install_deb obsidian "https://github.com/obsidianmd/obsidian-releases/releases/download/${tag}/obsidian_${tag#v}_amd64.deb"
fi

if command -v google-chrome >/dev/null 2>&1; then
  log "google chrome already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "google-chrome: unsupported architecture $(uname -m) (only amd64 .deb is published)"
  install_deb google-chrome https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
fi

if command -v slack >/dev/null 2>&1; then
  log "slack already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "slack: unsupported architecture $(uname -m) (only amd64 .deb is published)"
  url="$(curl -fsSL 'https://slack.com/downloads/instructions/linux?ddl=1&build=deb' |
    grep -oE 'https://downloads\.slack-edge\.com/desktop-releases/linux/x64/[0-9.]+/slack-desktop-[0-9.]+-amd64\.deb' |
    head -n1)"
  [[ -n "$url" ]] || die "slack: could not find the latest .deb download URL"
  install_deb slack "$url"
fi

if command -v zoom >/dev/null 2>&1; then
  log "zoom already installed, skipping"
else
  [[ "$(uname -m)" == x86_64 ]] || die "zoom: unsupported architecture $(uname -m) (only amd64 .deb is published)"
  install_deb zoom https://zoom.us/client/latest/zoom_amd64.deb
fi

if command -v clockify >/dev/null 2>&1; then
  log "clockify already installed, skipping"
else
  case "$(uname -m)" in
    x86_64) arch=x64 ;;
    aarch64) arch=arm64 ;;
    *) die "clockify: unsupported architecture $(uname -m)" ;;
  esac
  install_deb clockify "https://clockify.me/downloads/Clockify_Setup_${arch}.deb"
fi
