#!/usr/bin/env bash
# Exercise the gh token deployment helper without reading real secrets or
# contacting GitHub.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/home/dot_scripts/deploy_secrets/executable_gh_tokens.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/gopass" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$GH_TOKEN_DEPLOY_TEST_DIR/gopass.calls"
entry="${3:-}"

if [[ "$entry" == "${GH_TOKEN_DEPLOY_FAIL_GOPASS:-}" ]]; then
  exit 1
fi

case "$entry" in
  gh/mdp-token-1)
    printf '%s\n' "mdp-test-token"
    ;;
  gh/nexdep-token-1)
    printf '%s\n' "nexdep-test-token"
    ;;
  *)
    printf 'unexpected gopass entry: %s\n' "$entry" >&2
    exit 1
    ;;
esac
EOF

cat >"$tmp_dir/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  "auth login")
    token=""
    IFS= read -r token || true
    case "$token" in
      mdp-test-token)
        account="marco-de-pietri"
        ;;
      nexdep-test-token)
        account="nexdep"
        ;;
      *)
        account="empty-or-unknown"
        ;;
    esac
    printf 'login|%s|%s\n' "$account" "$*" >>"$GH_TOKEN_DEPLOY_TEST_DIR/gh.calls"
    if [[ "$account" == "empty-or-unknown" ||
      "$account" == "${GH_TOKEN_DEPLOY_FAIL_GH_ACCOUNT:-}" ]]; then
      exit 1
    fi
    ;;
  "auth switch")
    printf 'switch|%s\n' "$*" >>"$GH_TOKEN_DEPLOY_TEST_DIR/gh.calls"
    ;;
  *)
    printf 'unexpected gh command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

chmod +x "$tmp_dir/bin/gopass" "$tmp_dir/bin/gh"

run_case() {
  local name="$1"
  local fail_gopass="$2"
  local fail_gh="$3"
  local expected_status="$4"
  local state_dir="$tmp_dir/$name"
  local status

  mkdir "$state_dir"
  : >"$state_dir/gopass.calls"
  : >"$state_dir/gh.calls"

  set +e
  PATH="$tmp_dir/bin:$PATH" \
    GH_TOKEN_DEPLOY_TEST_DIR="$state_dir" \
    GH_TOKEN_DEPLOY_FAIL_GOPASS="$fail_gopass" \
    GH_TOKEN_DEPLOY_FAIL_GH_ACCOUNT="$fail_gh" \
    bash "$script" >"$state_dir/output" 2>&1
  status=$?
  set -e

  if [[ "$status" -ne "$expected_status" ]]; then
    printf '%s: expected status %s, got %s\n' \
      "$name" "$expected_status" "$status" >&2
    return 1
  fi

  if grep -Eq 'mdp-test-token|nexdep-test-token' "$state_dir/output"; then
    printf '%s: script output exposed a token\n' "$name" >&2
    return 1
  fi

  if [[ "$(wc -l <"$state_dir/gopass.calls")" -ne 2 ]]; then
    printf '%s: expected both gopass entries to be attempted\n' "$name" >&2
    return 1
  fi
  if [[ "$(grep -c '^login|' "$state_dir/gh.calls")" -ne 2 ]]; then
    printf '%s: expected both gh logins to be attempted\n' "$name" >&2
    return 1
  fi
}

run_case success "" "" 0

cat >"$tmp_dir/expected-gopass.calls" <<'EOF'
show --password gh/mdp-token-1
show --password gh/nexdep-token-1
EOF
diff -u "$tmp_dir/expected-gopass.calls" "$tmp_dir/success/gopass.calls"

cat >"$tmp_dir/expected-gh.calls" <<'EOF'
login|marco-de-pietri|auth login --hostname github.com --git-protocol ssh --with-token --insecure-storage --skip-ssh-key
login|nexdep|auth login --hostname github.com --git-protocol ssh --with-token --insecure-storage --skip-ssh-key
switch|auth switch --hostname github.com --user nexdep
EOF
diff -u "$tmp_dir/expected-gh.calls" "$tmp_dir/success/gh.calls"

run_case gopass-failure "gh/mdp-token-1" "" 1
grep -Fq 'login|nexdep|' "$tmp_dir/gopass-failure/gh.calls"
grep -Fq 'switch|auth switch --hostname github.com --user nexdep' \
  "$tmp_dir/gopass-failure/gh.calls"

run_case gh-failure "" "marco-de-pietri" 1
grep -Fq 'login|nexdep|' "$tmp_dir/gh-failure/gh.calls"
grep -Fq 'switch|auth switch --hostname github.com --user nexdep' \
  "$tmp_dir/gh-failure/gh.calls"

run_case nexdep-failure "" "nexdep" 1
if grep -q '^switch|' "$tmp_dir/nexdep-failure/gh.calls"; then
  printf 'nexdep-failure: active account changed after nexdep login failed\n' >&2
  exit 1
fi

printf 'gh token deployment smoke test passed\n'
