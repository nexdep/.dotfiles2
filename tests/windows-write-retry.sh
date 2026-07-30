#!/usr/bin/env bash
# Exercise Windows-side write retries without WSL interop or real delays.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir "$tmp_dir/bin"

cat >"$tmp_dir/bin/sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >>"$WINDOWS_RETRY_TEST_DIR/sleeps"
EOF
chmod +x "$tmp_dir/bin/sleep"
PATH="$tmp_dir/bin:$PATH"

# shellcheck disable=SC1091  # path is resolved from this repository at runtime
source "$repo_dir/home/.chezmoitemplates/windows-write-helpers.sh"

retry_action() {
  local attempts=0
  if [[ -f "$WINDOWS_RETRY_TEST_DIR/attempts" ]]; then
    read -r attempts <"$WINDOWS_RETRY_TEST_DIR/attempts"
  fi
  attempts=$((attempts + 1))
  printf '%s\n' "$attempts" >"$WINDOWS_RETRY_TEST_DIR/attempts"
  ((attempts > WINDOWS_RETRY_TEST_FAILURES))
}

assert_attempts_and_sleeps() {
  local expected_attempts="$1" expected_sleeps="$2" attempts
  local -a sleeps=()

  read -r attempts <"$WINDOWS_RETRY_TEST_DIR/attempts"
  [[ "$attempts" == "$expected_attempts" ]] || {
    printf 'expected %s attempts, got %s\n' "$expected_attempts" "$attempts" >&2
    exit 1
  }
  if [[ -f "$WINDOWS_RETRY_TEST_DIR/sleeps" ]]; then
    mapfile -t sleeps <"$WINDOWS_RETRY_TEST_DIR/sleeps"
  fi
  [[ "${sleeps[*]}" == "$expected_sleeps" ]] || {
    printf 'expected sleeps "%s", got "%s"\n' \
      "$expected_sleeps" "${sleeps[*]}" >&2
    exit 1
  }
}

mkdir "$tmp_dir/eventual-success"
export WINDOWS_RETRY_TEST_DIR="$tmp_dir/eventual-success"
export WINDOWS_RETRY_TEST_FAILURES=2
export DOTFILES_WINDOWS_WARNINGS_FILE="$tmp_dir/eventual-success/warnings"
windows_retry "eventual success" retry_action
assert_attempts_and_sleeps 3 "1 2"
[[ ! -e "$DOTFILES_WINDOWS_WARNINGS_FILE" ]]

mkdir "$tmp_dir/persistent-failure"
export WINDOWS_RETRY_TEST_DIR="$tmp_dir/persistent-failure"
export WINDOWS_RETRY_TEST_FAILURES=99
export DOTFILES_WINDOWS_WARNINGS_FILE="$tmp_dir/persistent-failure/warnings"
if windows_retry "persistent failure" retry_action; then
  printf 'expected a persistent failure after retry exhaustion\n' >&2
  exit 1
fi
assert_attempts_and_sleeps 4 "1 2 4"
[[ "$(wc -l <"$DOTFILES_WINDOWS_WARNINGS_FILE")" -eq 1 ]]
grep -Fq 'persistent failure failed after 4 attempts (exit 1)' \
  "$DOTFILES_WINDOWS_WARNINGS_FILE"

atomic_dir="$tmp_dir/atomic"
mkdir "$atomic_dir"
printf '%s\n' old >"$atomic_dir/source"
windows_atomic_copy_if_changed "$atomic_dir/source" "$atomic_dir/target"
target_inode="$(stat -c %i "$atomic_dir/target")"
windows_atomic_copy_if_changed "$atomic_dir/source" "$atomic_dir/target"
[[ "$(stat -c %i "$atomic_dir/target")" == "$target_inode" ]]
printf '%s\n' new >"$atomic_dir/source"
windows_atomic_copy_if_changed "$atomic_dir/source" "$atomic_dir/target"
grep -Fxq new "$atomic_dir/target"
if find "$atomic_dir" -maxdepth 1 -name '*.tmp.*' | grep -q .; then
  printf 'atomic copy left temporary files behind\n' >&2
  exit 1
fi

mkdir "$tmp_dir/standalone"
export WINDOWS_RETRY_TEST_DIR="$tmp_dir/standalone"
export WINDOWS_RETRY_TEST_FAILURES=99
unset DOTFILES_WINDOWS_WARNINGS_FILE
if windows_retry "standalone failure" retry_action 2>"$tmp_dir/standalone/stderr"; then
  printf 'expected standalone retry exhaustion\n' >&2
  exit 1
fi
grep -Fq '[windows-deploy] WARNING:' "$tmp_dir/standalone/stderr"

printf 'Windows write retry smoke test passed\n'
