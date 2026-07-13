#!/usr/bin/env bash
# Symlink Windows OneDrive sync folders into $HOME on WSL. The personal
# "OneDrive" folder becomes ~/onedrive; business "OneDrive - <Org>" folders
# become ~/onedrive_<slug>, where the slug is the org's initials
# ("Massachusetts Institute of Technology" -> mit; lowercase connectives
# like "of" are skipped) or the single org word lowercased. Only these
# canonical names are managed: symlinks under other names are left alone,
# and a real file/dir at a managed name is never clobbered.
# Self-skips on machines without a Windows filesystem (e.g. CI containers).
set -euo pipefail

LOG_TAG=onedrive-links
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

shopt -s nullglob

# --- resolve the Windows user profile ------------------------------------------
# Prefer asking Windows itself via WSL interop (same pattern as the
# deploy-windows-ssh-config chezmoi script); cd to a Windows filesystem path
# first because cmd.exe warns on a UNC/Linux cwd.
win_profile=""
if [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]] && command -v cmd.exe >/dev/null 2>&1; then
  win_profile="$(cd /mnt/c 2>/dev/null &&
    wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")" || win_profile=""
  [[ -d "$win_profile" ]] || win_profile=""
fi

# Fallback without interop: scan /mnt/c/Users, skipping Windows built-ins.
if [[ -z "$win_profile" ]]; then
  candidates=()
  for dir in /mnt/c/Users/*/; do
    case "$(basename "$dir")" in
      Default | "Default User" | "All Users" | Public | WsiAccount | defaultuser*) continue ;;
    esac
    candidates+=("${dir%/}")
  done
  if (( ${#candidates[@]} == 1 )); then
    win_profile="${candidates[0]}"
  elif (( ${#candidates[@]} > 1 )); then
    log "multiple Windows profiles (${candidates[*]}) and no interop to pick one, skipping"
    exit 0
  fi
fi

if [[ -z "$win_profile" ]]; then
  log "no Windows user profile found (no /mnt/c or not WSL), skipping"
  exit 0
fi
log "windows profile: $win_profile"

# --- link naming ----------------------------------------------------------------
# slug_for_org <org>: single word -> lowercased; multiple words -> initials of
# the words that start with an uppercase letter, lowercased.
slug_for_org() {
  local org="$1" slug="" w
  local -a words
  read -ra words <<<"$org"
  if (( ${#words[@]} == 1 )); then
    printf '%s\n' "${words[0],,}"
    return
  fi
  for w in "${words[@]}"; do
    [[ "$w" =~ ^[[:upper:]] ]] && slug+="${w:0:1}"
  done
  printf '%s\n' "${slug,,}"
}

# link_onedrive <src> <dest>: skip if already correct, repoint a stale symlink,
# never clobber a real file/dir.
link_onedrive() {
  local src="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    if [[ "$(readlink "$dest")" == "$src" ]]; then
      log "$dest -> $src already in place, skipping"
    else
      log "repointing $dest -> $src (was $(readlink "$dest"))"
      ln -sfn "$src" "$dest"
    fi
  elif [[ -e "$dest" ]]; then
    log "WARNING: $dest exists and is not a symlink, leaving it alone"
  else
    log "linking $dest -> $src"
    ln -s "$src" "$dest"
  fi
}

# --- find and link the OneDrive folders -----------------------------------------
found=0
seen_dests=" "
for src in "$win_profile"/OneDrive*/; do
  src="${src%/}"
  base="${src##*/}"
  if [[ "$base" == OneDrive ]]; then
    dest="$HOME/onedrive"
  else
    org="${base#OneDrive - }"
    slug="$(slug_for_org "$org")"
    if [[ -z "$slug" ]]; then
      log "WARNING: cannot derive a slug for '$org', skipping"
      continue
    fi
    dest="$HOME/onedrive_$slug"
  fi
  if [[ "$seen_dests" == *" $dest "* ]]; then
    log "WARNING: slug collision, $dest already claimed this run; skipping '$base'"
    continue
  fi
  seen_dests+="$dest "
  link_onedrive "$src" "$dest"
  found=1
done

(( found )) || log "no OneDrive folders in $win_profile"
