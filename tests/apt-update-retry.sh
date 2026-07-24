#!/usr/bin/env bash
# Exercise apt_update without network access or real delays.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin" "$tmp_dir/success" "$tmp_dir/failure"

cat >"$tmp_dir/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

count_file="$APT_UPDATE_TEST_DIR/attempts"
attempt=0
if [[ -f "$count_file" ]]; then
  read -r attempt <"$count_file"
fi
attempt=$((attempt + 1))
printf '%s\n' "$attempt" >"$count_file"
printf '%s\n' "$*" >>"$APT_UPDATE_TEST_DIR/arguments"

if ((attempt <= APT_UPDATE_FAILS)); then
  exit 100
fi
EOF
chmod +x "$tmp_dir/bin/apt-get"

cat >"$tmp_dir/bin/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >>"$APT_UPDATE_TEST_DIR/sleeps"
EOF
chmod +x "$tmp_dir/bin/sleep"

PATH="$tmp_dir/bin:$PATH"
export LOG_TAG=apt-update-test
# shellcheck disable=SC1091  # path is resolved from this repository at runtime
source "$repo_dir/lib/common.sh"
export SUDO=""

export APT_UPDATE_TEST_DIR="$tmp_dir/success"
export APT_UPDATE_FAILS=2
apt_update

read -r attempts <"$APT_UPDATE_TEST_DIR/attempts"
[[ "$attempts" == 3 ]] || {
  printf 'expected success on attempt 3, got attempt %s\n' "$attempts" >&2
  exit 1
}
mapfile -t sleeps <"$APT_UPDATE_TEST_DIR/sleeps"
[[ "${sleeps[*]}" == "10 20" ]] || {
  printf 'expected success backoff "10 20", got "%s"\n' "${sleeps[*]}" >&2
  exit 1
}

export APT_UPDATE_TEST_DIR="$tmp_dir/failure"
export APT_UPDATE_FAILS=4
if apt_update; then
  printf 'expected apt_update to fail after four attempts\n' >&2
  exit 1
else
  status=$?
fi
[[ "$status" == 100 ]] || {
  printf 'expected final status 100, got %s\n' "$status" >&2
  exit 1
}
read -r attempts <"$APT_UPDATE_TEST_DIR/attempts"
[[ "$attempts" == 4 ]] || {
  printf 'expected four failed attempts, got %s\n' "$attempts" >&2
  exit 1
}
mapfile -t sleeps <"$APT_UPDATE_TEST_DIR/sleeps"
[[ "${sleeps[*]}" == "10 20 40" ]] || {
  printf 'expected failure backoff "10 20 40", got "%s"\n' "${sleeps[*]}" >&2
  exit 1
}

if grep -Fvxq -- '-o Acquire::Retries=3 update' \
  "$tmp_dir/success/arguments" "$tmp_dir/failure/arguments"; then
  printf 'apt_update invoked apt-get with unexpected arguments\n' >&2
  exit 1
fi

printf 'apt update retry smoke test passed\n'
