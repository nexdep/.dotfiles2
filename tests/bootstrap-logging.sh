#!/usr/bin/env bash
# Exercise bootstrap's logging and failure cleanup without installing anything:
# an invalid machine type exits before the first installation action.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir "$tmp_dir/home" "$tmp_dir/bin"

# Make bootstrap's temporary paths predictable and seed a Windows warning so
# this failure-path test also proves cleanup reports collected warnings.
cat >"$tmp_dir/bin/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-d" ]]; then
  log_pipe_dir="$BOOTSTRAP_LOGGING_TEST_DIR/log-pipe"
  mkdir "$log_pipe_dir"
  printf '%s\n' 'simulated Windows write failure' >"$log_pipe_dir/windows-warnings"
  printf '%s\n' "$log_pipe_dir"
else
  log_file="$BOOTSTRAP_LOGGING_TEST_DIR/home/bootstrap-test.log"
  : >"$log_file"
  printf '%s\n' "$log_file"
fi
EOF
chmod +x "$tmp_dir/bin/mktemp"
export BOOTSTRAP_LOGGING_TEST_DIR="$tmp_dir"

set +e
HOME="$tmp_dir/home" PATH="$tmp_dir/bin:$PATH" \
  "$repo_dir/bootstrap.sh" invalid >"$tmp_dir/terminal" 2>&1
status=$?
set -e

if [[ "$status" -ne 1 ]]; then
  printf 'expected bootstrap to exit 1, got %s\n' "$status" >&2
  exit 1
fi

mapfile -t logs < <(find "$tmp_dir/home" -maxdepth 1 -type f -name 'bootstrap-*.log')
if [[ "${#logs[@]}" -ne 1 ]]; then
  printf 'expected one bootstrap log, found %s\n' "${#logs[@]}" >&2
  exit 1
fi
log_file="${logs[0]}"

grep -Fq "[bootstrap] saving install log to $log_file" "$log_file"
grep -Fq "[bootstrap] unknown machine type 'invalid'" "$log_file"
grep -Fq '[bootstrap] failed with exit status 1' "$log_file"
grep -Fq '[bootstrap] WARNING: simulated Windows write failure' "$log_file"
grep -Fq "[bootstrap] install log saved to $log_file" "$tmp_dir/terminal"
grep -Fq 'simulated Windows write failure' "$tmp_dir/terminal"

if LC_ALL=C grep -q $'\033' "$log_file"; then
  printf 'bootstrap log contains ANSI escape sequences\n' >&2
  exit 1
fi
if ! LC_ALL=C grep -q $'\033' "$tmp_dir/terminal"; then
  printf 'live bootstrap output lost its ANSI color sequences\n' >&2
  exit 1
fi

printf 'bootstrap logging smoke test passed\n'
