# --- bitwarden (all machines) ---
# bw_login / bw_fetch_ssh helpers (bw installed by lib/install-bw.sh).
# Kept in its own fragment so it is easy to delete once gopass replaces it.

_bw_status_value() {
  bw status 2>/dev/null | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

_bw_have_session() {
  [[ -n "${BW_SESSION:-}" ]] && bw unlock --check --session "$BW_SESSION" >/dev/null 2>&1
}

_bw_export_session_from() {
  local action="$1"
  local s=""

  case "$action" in
    login)
      s="$(bw login --raw)" || return 1
      ;;
    unlock)
      s="$(bw unlock --raw)" || return 1
      ;;
    *)
      echo "Unknown Bitwarden session action: $action"
      return 1
      ;;
  esac

  if [[ -z "$s" ]]; then
    echo "Bitwarden did not return a session key."
    return 1
  fi

  export BW_SESSION="$s"
}

# bw_fetch_ssh: fetch an SSH key from Bitwarden into ~/.ssh
bw_fetch_ssh() {
  local REF="$1"
  if [[ -z "$REF" ]]; then
    echo "Usage: bw_fetch_ssh <item_id_or_exact_item_name_or_ssh_host>"
    return 1
  fi

  local DEST_DIR="$HOME/.ssh"
  local SSH_CONFIG="$HOME/.ssh/config"
  mkdir -p "$DEST_DIR" && chmod 700 "$DEST_DIR" || return 1

  if ! _bw_have_session; then
    [[ -n "${BW_SESSION:-}" ]] && unset BW_SESSION
    bw_login || return 1
  fi

  if ! _bw_have_session; then
    echo "No valid Bitwarden session available. Run bw_login in an interactive shell."
    return 1
  fi

  bw sync --session "$BW_SESSION" >/dev/null 2>&1 || echo "Warning: bw sync failed; continuing with cached vault data."

  local ITEM_ID=""
  local RESOLVED_NAME="$REF"
  local PRIVATE_KEY=""

  _bw_find_exact_item_id() {
    local name="$1"
    bw list items --search "$name" --session "$BW_SESSION" \
      | jq -r --arg n "$name" '.[] | select(.name == $n) | .id' \
      | head -n 1
  }

  _bw_get_private_key() {
    local item_id="$1"
    local pk=""
    pk="$(bw get item "$item_id" --session "$BW_SESSION" | jq -r '.sshKey.privateKey // empty')" || pk=""
    if [[ -z "$pk" ]]; then
      local att_name
      att_name="$(bw get item "$item_id" --session "$BW_SESSION" | jq -r '.attachments[0].fileName // empty')" || att_name=""
      if [[ -n "$att_name" ]]; then
        pk="$(bw get attachment "$att_name" --itemid "$item_id" --output - --session "$BW_SESSION" 2>/dev/null)"
      fi
    fi
    printf '%s' "$pk"
  }

  # 1) UUID -> direct
  if [[ "$REF" =~ ^[0-9a-fA-F-]{36}$ ]]; then
    ITEM_ID="$REF"
  else
    # 2) exact item name
    ITEM_ID="$(_bw_find_exact_item_id "$REF")"
  fi

  if [[ -n "$ITEM_ID" && "$ITEM_ID" != "null" ]]; then
    PRIVATE_KEY="$(_bw_get_private_key "$ITEM_ID")"
  fi

  # 3) fallback: ssh host alias -> identityfile basename -> bitwarden exact item
  if [[ -z "$PRIVATE_KEY" && "$REF" != "" ]]; then
    local IDENTITY_FILE=""
    local IDENTITY_BASENAME=""

    if [[ -f "$SSH_CONFIG" ]]; then
      IDENTITY_FILE="$(
        ssh -G -F "$SSH_CONFIG" "$REF" 2>/dev/null \
          | grep '^identityfile ' \
          | tail -n 1 \
          | sed 's/^identityfile //'
      )"
    else
      IDENTITY_FILE="$(
        ssh -G "$REF" 2>/dev/null \
          | grep '^identityfile ' \
          | tail -n 1 \
          | sed 's/^identityfile //'
      )"
    fi

    if [[ -n "$IDENTITY_FILE" ]]; then
      IDENTITY_FILE="${IDENTITY_FILE/#\~/$HOME}"
      IDENTITY_BASENAME="$(basename "$IDENTITY_FILE")"

      if [[ -n "$IDENTITY_BASENAME" ]]; then
        ITEM_ID="$(_bw_find_exact_item_id "$IDENTITY_BASENAME")"
        if [[ -n "$ITEM_ID" && "$ITEM_ID" != "null" ]]; then
          PRIVATE_KEY="$(_bw_get_private_key "$ITEM_ID")"
          if [[ -n "$PRIVATE_KEY" ]]; then
            RESOLVED_NAME="$IDENTITY_BASENAME"
          fi
        fi
      fi
    fi
  fi

  if [[ -z "$ITEM_ID" || "$ITEM_ID" == "null" ]]; then
    echo "Couldn't find an item with exact name: $REF"
    echo "Also checked SSH-resolved IdentityFile and found no matching Bitwarden item."
    return 1
  fi

  if [[ -z "$PRIVATE_KEY" ]]; then
    echo "Found Bitwarden item, but no SSH private key found in it."
    echo "Checked .sshKey.privateKey and attachments[0]."
    return 1
  fi

  local RAW_NAME BASENAME
  RAW_NAME="$(bw get item "$ITEM_ID" --session "$BW_SESSION" | jq -r '.name // "bitwarden_key"')" || return 1
  BASENAME="${RAW_NAME// /_}"
  BASENAME="${BASENAME//[^A-Za-z0-9._-]/_}"
  [[ -z "$BASENAME" ]] && BASENAME="bitwarden_key"

  local DEST_PATH="$DEST_DIR/$BASENAME"
  if [[ -e "$DEST_PATH" ]]; then
    local N=1
    while [[ -e "${DEST_PATH}.frombw.$N" ]]; do ((N++)); done
    DEST_PATH="${DEST_PATH}.frombw.$N"
  fi

  umask 077
  printf '%s\n' "$PRIVATE_KEY" > "$DEST_PATH" || return 1
  chmod 600 "$DEST_PATH"

  if ! ssh-keygen -y -f "$DEST_PATH" > "${DEST_PATH}.pub" 2>/dev/null; then
    echo "Wrote private key, but failed to derive public key (bad key format or needs passphrase)."
    return 1
  fi
  chmod 644 "${DEST_PATH}.pub"

  echo "Fetched Bitwarden item: $RAW_NAME"
  [[ "$RESOLVED_NAME" != "$REF" ]] && echo "Resolved via SSH host '$REF' -> IdentityFile basename '$RESOLVED_NAME'"
  echo "Private key: $DEST_PATH"
  echo "Public  key: ${DEST_PATH}.pub"
}

# bw_login: login or unlock bitwarden and export BW_SESSION
bw_login() {
  # Options:
  #   --no-relock : if status is unlocked but BW_SESSION missing, fail instead of lock+unlock
  local no_relock=0
  if [ "${1:-}" = "--no-relock" ]; then
    no_relock=1
  fi

  if ! command -v bw >/dev/null 2>&1; then
    echo "Could not find the Bitwarden CLI (bw) on PATH."
    return 1
  fi

  local st
  st="$(_bw_status_value)"

  if [ -z "$st" ]; then
    echo "Could not read bw status. Is the Bitwarden CLI installed and on PATH?"
    return 1
  fi

  case "$st" in
    unauthenticated)
      _bw_export_session_from login || return 1
      echo "BW_SESSION exported (login)."
      ;;

    locked)
      _bw_export_session_from unlock || return 1
      echo "BW_SESSION exported (unlock)."
      ;;

    unlocked)
      if _bw_have_session; then
        echo "Vault is unlocked; BW_SESSION already set."
        return 0
      fi
      [[ -n "${BW_SESSION:-}" ]] && unset BW_SESSION

      if [ $no_relock -eq 1 ]; then
        echo "Vault is unlocked but BW_SESSION is not set. Re-run without --no-relock to lock+unlock."
        return 1
      fi

      bw lock >/dev/null 2>&1
      _bw_export_session_from unlock || return 1
      echo "BW_SESSION exported (forced lock+unlock)."
      ;;

    *)
      echo "Unknown status: $st"
      return 1
      ;;
  esac
}
