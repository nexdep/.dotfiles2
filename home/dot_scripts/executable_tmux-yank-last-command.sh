#!/bin/sh
# Select the latest OSC 133 command block in tmux copy mode and copy it to the
# tmux paste buffer. With set-clipboard=external, tmux also publishes it to the
# host terminal over OSC 52.
set -eu

target_pane=${1:-${TMUX_PANE:-}}
[ -n "$target_pane" ] || {
  printf 'usage: %s PANE_ID\n' "$0" >&2
  exit 2
}

copy_position() {
  tmux display-message -p -t "$target_pane" \
    '#{copy_cursor_x}:#{copy_cursor_y}:#{scroll_position}'
}

cancel_with_message() {
  tmux send-keys -t "$target_pane" -X cancel 2>/dev/null || :
  tmux display-message -t "$target_pane" "$1"
  exit 1
}

tmux copy-mode -t "$target_pane"
initial_position=$(copy_position)
tmux send-keys -t "$target_pane" -X previous-prompt
prompt_position=$(copy_position)

[ "$prompt_position" != "$initial_position" ] ||
  cancel_with_message "No previous command prompt found"

tmux send-keys -t "$target_pane" -X begin-selection
tmux send-keys -t "$target_pane" -X next-prompt
next_position=$(copy_position)

if [ "$next_position" = "$prompt_position" ]; then
  # The command is still running, so no following prompt exists yet.
  tmux send-keys -t "$target_pane" -X history-bottom
  tmux send-keys -t "$target_pane" -X end-of-line
else
  # next-prompt lands on the first cell of the new prompt; exclude that cell.
  tmux send-keys -t "$target_pane" -X cursor-left
fi

tmux send-keys -t "$target_pane" -X copy-selection-and-cancel
tmux display-message -t "$target_pane" "Copied last command block"
