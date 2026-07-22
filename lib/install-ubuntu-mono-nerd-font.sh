#!/usr/bin/env bash
# Install the complete Ubuntu Mono Nerd Font family system-wide from the
# official Nerd Fonts release archive.
set -euo pipefail

LOG_TAG=ubuntu-mono-nerd-font
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

font_dir=/usr/local/share/fonts/UbuntuMonoNerdFont
marker="$font_dir/UbuntuMonoNerdFont-Regular.ttf"
if [[ -f "$marker" ]]; then
  log "already installed, skipping"
  exit 0
fi

url=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/UbuntuMono.tar.xz
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" -o "$tmp/UbuntuMono.tar.xz"
mkdir "$tmp/extracted"
tar -xJf "$tmp/UbuntuMono.tar.xz" -C "$tmp/extracted"

mapfile -d '' fonts < <(find "$tmp/extracted" -type f -name '*.ttf' -print0)
(( ${#fonts[@]} > 0 )) || die "no TTF files found in release archive"
regular="$tmp/extracted/UbuntuMonoNerdFont-Regular.ttf"
[[ -f "$regular" ]] || die "regular font not found in release archive"

$SUDO install -d -m 0755 "$font_dir"
for font in "${fonts[@]}"; do
  [[ "$font" == "$regular" ]] && continue
  $SUDO install -m 0644 "$font" "$font_dir/$(basename "$font")"
done
# Install the idempotency marker last so an interrupted copy is retried.
$SUDO install -m 0644 "$regular" "$marker"
$SUDO fc-cache -f "$font_dir"
log "installed ${#fonts[@]} font files"
