# shellcheck shell=sh
# Shared by the WSL-only chezmoi scripts that mirror configuration into the
# Windows filesystem. Callers keep their platform/executable guards and use
# windows_retry for every operation that crosses the WSL/Windows boundary.

windows_record_warning() {
  windows_warning_message=$1

  if [ -n "${DOTFILES_WINDOWS_WARNINGS_FILE:-}" ]; then
    if printf '%s\n' "$windows_warning_message" >>"$DOTFILES_WINDOWS_WARNINGS_FILE"; then
      return 0
    fi
  fi

  printf '\033[1;33m[windows-deploy] WARNING:\033[0m %s\n' \
    "$windows_warning_message" >&2
}

windows_retry() {
  windows_retry_label=$1
  shift
  windows_retry_attempt=1
  windows_retry_delay=1
  windows_retry_max_attempts=4

  while [ "$windows_retry_attempt" -le "$windows_retry_max_attempts" ]; do
    if "$@"; then
      return 0
    else
      windows_retry_status=$?
    fi

    if [ "$windows_retry_attempt" -eq "$windows_retry_max_attempts" ]; then
      windows_record_warning \
        "$windows_retry_label failed after $windows_retry_max_attempts attempts (exit $windows_retry_status); the Windows-side configuration may be stale"
      return 1
    fi

    printf '[windows-deploy] %s failed (attempt %s/%s); retrying in %ss\n' \
      "$windows_retry_label" "$windows_retry_attempt" \
      "$windows_retry_max_attempts" "$windows_retry_delay" >&2
    sleep "$windows_retry_delay"
    windows_retry_delay=$((windows_retry_delay * 2))
    windows_retry_attempt=$((windows_retry_attempt + 1))
  done
}

windows_atomic_copy_if_changed() {
  windows_copy_source=$1
  windows_copy_target=$2

  if [ -f "$windows_copy_target" ] &&
    cmp -s "$windows_copy_source" "$windows_copy_target"; then
    return 0
  fi

  windows_copy_tmp="${windows_copy_target}.tmp.$$"
  if cp "$windows_copy_source" "$windows_copy_tmp"; then
    :
  else
    windows_copy_status=$?
    rm -f "$windows_copy_tmp" 2>/dev/null || :
    return "$windows_copy_status"
  fi
  if mv -f "$windows_copy_tmp" "$windows_copy_target"; then
    :
  else
    windows_copy_status=$?
    rm -f "$windows_copy_tmp" 2>/dev/null || :
    return "$windows_copy_status"
  fi
}
