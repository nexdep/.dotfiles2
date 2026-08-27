#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_TAG=download-url-test
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"

deb_url='https://github.com/obsidianmd/obsidian-releases/releases/download/v1.13.7/obsidian_1.13.7_amd64.deb'
fixture="<a href=\"https://github.com/obsidianmd/obsidian-releases/releases/download/v1.13.8/Obsidian-1.13.8.apk\">APK</a>
<a href=\"$deb_url\">Deb</a>"

curl() { printf '%s\n' "$fixture"; }

resolved="$(resolve_url_from_page https://obsidian.md/download \
  'https://github\.com/obsidianmd/obsidian-releases/releases/download/v[0-9.]+/obsidian_[0-9.]+_amd64\.deb')"
[[ "$resolved" == "$deb_url" ]] || {
  printf 'expected %s, got %s\n' "$deb_url" "$resolved" >&2
  exit 1
}

fixture='<a href="https://example.test/Obsidian.apk">APK only</a>'
if resolve_url_from_page https://obsidian.md/download 'https://github\.com/.+_amd64\.deb' >/dev/null; then
  printf 'resolver unexpectedly accepted a page without an amd64 .deb\n' >&2
  exit 1
fi

printf 'download URL resolution smoke test passed\n'
