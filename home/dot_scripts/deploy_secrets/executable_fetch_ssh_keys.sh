#!/usr/bin/env bash
# Fetch one or more multiline SSH private keys from gopass, install them in
# ~/.ssh, and derive matching public keys. Entries are expected to have been
# stored with `gopass insert --multiline`.
#
# Usage:
#   fetch_ssh_keys.sh [ENTRY ...]
#
# With no arguments, choose one entry interactively from the gopass ssh/
# namespace. With arguments, process every exact entry in order and continue
# after individual failures.
#
# Self-contained on purpose (no lib/common.sh) since it is deployed to
# ~/.scripts/deploy_secrets/ and run outside the repo.
set -uo pipefail

log() { printf '\033[1;34m[gopass-ssh]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;31m[gopass-ssh]\033[0m %s\n' "$*" >&2; }
die() {
  warn "$*"
  exit 1
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

yes_or_no() {
  local prompt="$1"
  local answer

  [[ -t 0 ]] || return 2
  read -r -p "${prompt} [y/N]: " answer || return 1

  case "$answer" in
    y|Y|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

choose_entry() {
  local list_file="$TMP_DIR/ssh-entries"
  local choice
  local index
  local -a entries=()

  [[ -t 0 ]] || die "no entries supplied and no TTY available for interactive selection"

  if ! gopass list --flat ssh >"$list_file"; then
    die "could not list entries in the gopass ssh/ namespace"
  fi

  mapfile -t entries <"$list_file"
  ((${#entries[@]} > 0)) || die "no gopass entries found in the ssh/ namespace"

  printf 'SSH entries in gopass:\n'
  for index in "${!entries[@]}"; do
    printf '  %d) %s\n' "$((index + 1))" "${entries[$index]}"
  done

  while true; do
    read -r -p "Choose an entry [1-${#entries[@]}] (q to quit): " choice ||
      die "no entry selected"

    case "$choice" in
      q|Q)
        exit 0
        ;;
    esac

    if [[ "$choice" =~ ^[0-9]+$ ]] &&
      ((10#$choice >= 1 && 10#$choice <= ${#entries[@]})); then
      SELECTED_ENTRY="${entries[$((10#$choice - 1))]}"
      return 0
    fi

    warn "choose a number from 1 to ${#entries[@]}, or q to quit"
  done
}

choose_backup_path() {
  local original_path="$1"
  local candidate="${original_path}_bak"
  local number=1

  while path_exists "$candidate" || path_exists "${candidate}.pub"; do
    candidate="${original_path}_bak.${number}"
    ((number += 1))
  done

  BACKUP_PATH="$candidate"
}

deploy_entry() {
  local entry="$1"
  local basename="${entry##*/}"
  local private_tmp
  local public_tmp
  local destination
  local prompt_status

  if [[ -z "$entry" || -z "$basename" || "$basename" == "." || "$basename" == ".." ||
    "$basename" == *$'\n'* ]]; then
    warn "invalid gopass entry name: $entry"
    return 1
  fi

  private_tmp="$(mktemp "$TMP_DIR/private.XXXXXX")" || {
    warn "could not create a temporary file for $entry"
    return 1
  }
  public_tmp="${private_tmp}.pub"

  log "fetching $entry"
  if ! gopass show --unsafe --noparsing "$entry" >"$private_tmp"; then
    warn "could not fetch gopass entry: $entry"
    return 1
  fi
  if [[ ! -s "$private_tmp" ]]; then
    warn "gopass entry is empty: $entry"
    return 1
  fi
  if ! chmod 600 "$private_tmp"; then
    warn "could not secure the temporary private key for $entry"
    return 1
  fi

  if ! ssh-keygen -y -f "$private_tmp" >"$public_tmp"; then
    warn "could not derive a public key from $entry; no files installed"
    return 1
  fi
  if [[ ! -s "$public_tmp" ]]; then
    warn "ssh-keygen produced an empty public key for $entry; no files installed"
    return 1
  fi
  if ! chmod 644 "$public_tmp"; then
    warn "could not set permissions on the temporary public key for $entry"
    return 1
  fi

  destination="$DEST_DIR/$basename"
  if path_exists "$destination" || path_exists "${destination}.pub"; then
    yes_or_no "Overwrite $destination and ${destination}.pub?"
    prompt_status=$?
    case "$prompt_status" in
      0)
        ;;
      1)
        choose_backup_path "$destination"
        destination="$BACKUP_PATH"
        log "keeping existing key pair; using $destination"
        ;;
      2)
        warn "destination exists and no TTY is available to confirm overwrite: $destination"
        return 1
        ;;
    esac
  fi

  if ! install -T -m 600 "$private_tmp" "$destination"; then
    warn "could not install private key: $destination"
    return 1
  fi
  if ! install -T -m 644 "$public_tmp" "${destination}.pub"; then
    warn "private key was installed, but public-key installation failed: ${destination}.pub"
    return 1
  fi

  log "private key: $destination"
  log "public key:  ${destination}.pub"
}

for dependency in gopass ssh-keygen; do
  command -v "$dependency" >/dev/null 2>&1 || die "required command not found: $dependency"
done

umask 077
TMP_DIR="$(mktemp -d)" || die "could not create a temporary directory"
trap 'rm -rf "$TMP_DIR"' EXIT

DEST_DIR="$HOME/.ssh"
install -d -m 700 "$DEST_DIR" || die "could not create $DEST_DIR"

if (($# == 0)); then
  SELECTED_ENTRY=""
  choose_entry
  set -- "$SELECTED_ENTRY"
fi

successes=0
failures=0
for entry in "$@"; do
  if deploy_entry "$entry"; then
    ((successes += 1))
  else
    ((failures += 1))
  fi
done

log "completed: $successes succeeded, $failures failed"
((failures == 0))
