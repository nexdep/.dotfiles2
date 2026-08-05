#!/usr/bin/env bash
# Exercise tmux's OSC 133 prompt navigation against the deployed yank helper.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_dir/home/dot_scripts/executable_tmux-yank-last-command.sh"
tmux_config="$repo_dir/home/dot_config/tmux/tmux.conf"
tmux_tmpdir="$(mktemp -d)"

unset TMUX TMUX_PANE
export TMUX_TMPDIR="$tmux_tmpdir"

cleanup() {
  tmux kill-server 2>/dev/null || true
  rm -rf -- "$tmux_tmpdir"
}
trap cleanup EXIT

wait_for_pane_text() {
  local pane="$1" expected="$2"
  local _

  for _ in {1..50}; do
    if tmux capture-pane -p -t "$pane" | grep -Fq "$expected"; then
      return 0
    fi
    sleep 0.02
  done

  printf 'timed out waiting for %q in tmux pane\n' "$expected" >&2
  return 1
}

assert_yank() {
  local session="$1" payload="$2" ready_text="$3" expected="$4"
  local pane actual

  # The pane's shell, not this test process, must expand the fixture variable.
  # shellcheck disable=SC2016
  tmux -f "$tmux_config" new-session -d -s "$session" -x 80 -y 24 \
    -e "DOTFILES_TMUX_FIXTURE=$payload" \
    'printf "%s" "$DOTFILES_TMUX_FIXTURE"; sleep 30'
  pane="$(tmux display-message -p -t "$session" '#{pane_id}')"
  wait_for_pane_text "$pane" "$ready_text"

  sh "$helper" "$pane"
  actual="$(tmux save-buffer -)"
  if [[ "$actual" != "$expected" ]]; then
    printf 'unexpected yank for %s\nexpected: <%s>\nactual:   <%s>\n' \
      "$session" "$expected" "$actual" >&2
    return 1
  fi

  tmux kill-session -t "$session"
}

complete_payload=$'\e]133;A\aPROMPT1> \e]133;B\aecho first\r\n'
complete_payload+=$'\e]133;C;\afirst output\r\n\e]133;D;0\a'
complete_payload+=$'\e]133;A\aPROMPT2> \e]133;B\a'
assert_yank complete "$complete_payload" "PROMPT2>" \
  $'PROMPT1> echo first\nfirst output'

running_payload=$'\e]133;A\aPROMPT> \e]133;B\along-job\r\n'
running_payload+=$'\e]133;C;\apartial output'
assert_yank running "$running_payload" "partial output" \
  $'PROMPT> long-job\npartial output'
