# shellcheck shell=bash
# Laptop-only OneDrive apt repository setup. This file is sourced by
# bootstrap.sh after lib/common.sh, and kept as functions so the migration
# cleanup can be exercised without touching the host's apt configuration.

ONEDRIVE_OBS_REPO='https://download.opensuse.org/repositories/home:/npreining:/debian-ubuntu-onedrive/xUbuntu_26.04/'
ONEDRIVE_OBS_KEY="${ONEDRIVE_OBS_REPO}Release.key"
ONEDRIVE_LEGACY_PPA_PATTERN='ppa\.launchpad(content)?\.net/yann1ck/onedrive|ppa:yann1ck/onedrive'

onedrive_source_file_has_obs_repo() {
  local source_file="$1"

  if grep -Eiq '^[[:space:]]*Enabled:[[:space:]]*no([[:space:]]|$)' "$source_file"; then
    return 1
  fi
  awk -v repo="$ONEDRIVE_OBS_REPO" '
    /^[[:space:]]*#/ { next }
    index($0, repo) { found = 1 }
    END { exit !found }
  ' "$source_file"
}

onedrive_obs_repo_configured() {
  local main_sources="${APT_MAIN_SOURCES_FILE:-/etc/apt/sources.list}"
  local source_file

  for source_file in "$main_sources" "$APT_SOURCES_DIR"/*.list "$APT_SOURCES_DIR"/*.sources; do
    [[ -f "$source_file" ]] || continue
    if onedrive_source_file_has_obs_repo "$source_file"; then
      return 0
    fi
  done
  return 1
}

cleanup_legacy_onedrive() {
  local main_sources="${APT_MAIN_SOURCES_FILE:-/etc/apt/sources.list}"
  local service_link="${ONEDRIVE_USER_SERVICE_LINK:-/etc/systemd/user/default.target.wants/onedrive.service}"
  local source_file installed_status had_obs_repo=0

  if onedrive_obs_repo_configured; then
    had_obs_repo=1
  fi

  # The retired yann1ck PPA can make the very first apt-get update fail, so
  # remove it before bootstrap refreshes package metadata. add-apt-repository
  # creates a dedicated file under sources.list.d; handle an old inline entry
  # in /etc/apt/sources.list as well.
  if [[ -f "$main_sources" ]] && grep -Eq "$ONEDRIVE_LEGACY_PPA_PATTERN" "$main_sources"; then
    log "removing legacy yann1ck OneDrive PPA from $main_sources"
    $SUDO sed -i -E "\@${ONEDRIVE_LEGACY_PPA_PATTERN}@d" "$main_sources"
  fi
  for source_file in "$APT_SOURCES_DIR"/*; do
    [[ -f "$source_file" ]] || continue
    if grep -Eq "$ONEDRIVE_LEGACY_PPA_PATTERN" "$source_file"; then
      log "removing legacy yann1ck OneDrive PPA source $source_file"
      $SUDO rm -f "$source_file"
    fi
  done

  # A non-OBS Deb822 source named onedrive.sources would make add_apt_repo
  # preserve the wrong repository. Remove only that conflicting file.
  source_file="$APT_SOURCES_DIR/onedrive.sources"
  if [[ -f "$source_file" ]] && ! onedrive_source_file_has_obs_repo "$source_file"; then
    log "removing non-OBS OneDrive apt source $source_file"
    $SUDO rm -f "$source_file"
  fi

  installed_status="$(dpkg-query -W -f='${Status}' onedrive 2>/dev/null || true)"
  if ((had_obs_repo == 0)) && [[ "$installed_status" == 'install ok installed' ]]; then
    log "removing distribution-provided OneDrive package before OBS migration"
    $SUDO apt-get remove -y onedrive
  fi

  # Ubuntu's distribution package enables this user service automatically;
  # the upstream OBS package deliberately does not use that service model.
  if [[ -e "$service_link" || -L "$service_link" ]]; then
    log "removing legacy OneDrive user service link"
    $SUDO rm -f "$service_link"
  fi
}

register_onedrive_repo() {
  local onedrive_arch
  onedrive_arch="$(dpkg --print-architecture)"
  case "$onedrive_arch" in
    amd64 | armhf | arm64) ;;
    *) die "onedrive: unsupported architecture $onedrive_arch" ;;
  esac
  add_apt_repo onedrive "$ONEDRIVE_OBS_KEY" \
    "arch=$onedrive_arch" "$ONEDRIVE_OBS_REPO ./"
}
