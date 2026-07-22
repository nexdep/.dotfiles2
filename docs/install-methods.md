# Install method notes

Note on Recommends: packages from the `lib/packages-*.txt` lists are
installed with `--no-install-recommends` to keep servers and CI lean, while
the GUI apps below (both repo- and .deb-based) deliberately keep apt's
default Recommends handling — desktop apps often rely on them (e.g. Zoom
pulls in ibus and mesa extras).

Note on service startup: for the duration of the run `bootstrap.sh` installs a
`policy-rc.d` (exit 101) so package postinst scripts don't start their daemons
via the systemd bus — on WSL that bus is often unavailable and a failed start
would abort bootstrap. Services are still *enabled* and start on next boot;
`ssh` is best-effort started at the end so it works without a restart, and
tailscale is left for its manual `tailscale up`.

- **Firefox Developer Edition**: Mozilla's official apt repo
  (packages.mozilla.org), pinned above Ubuntu's snap-transition stubs, so it
  updates with `apt upgrade`.
- **Thunderbird Beta**: official Mozilla tarball in `/opt/thunderbird-beta`
  (symlinked as `thunderbird-beta`). Neither packages.mozilla.org nor a
  maintained PPA ships a Thunderbird beta channel for this release; the app
  self-updates through its internal updater (the install dir is chowned to
  the bootstrapping user so the updater can write to it).
- **gopass**: from its official apt repo (packages.gopass.pw, registered by
  `bootstrap.sh`) since Ubuntu 26.04 dropped it from universe; updates with
  `apt upgrade`.
- **Personal GPG key**: the key the gopass store is encrypted to lives in
  the repo as `gpg/private-key.asc.gpg` — a symmetric, passphrase-encrypted
  (AES256) export of the private key; its security rests entirely on that
  passphrase. Importing it is deliberately **not** part of `bootstrap.sh`
  (the decrypt prompt is interactive, and gpg-agent's pinentry is unreliable
  on WSL): run `~/.scripts/gpg/import-gpg-key.sh` (deployed by chezmoi)
  manually after bootstrap — it works from anywhere, finding the backup in
  the cwd or via `chezmoi source-path` (set `GPG_BACKUP_FILE` if chezmoi
  isn't initialized yet). It decrypts the backup,
  imports the key, and marks it ultimately trusted; it skips itself when the
  key is already in the keyring, reads the backup passphrase itself and hands
  it to gpg over a pipe with `--pinentry-mode loopback` (no pinentry has to
  render; 3 attempts for typos), and CI never imports it (`tests/verify.sh`
  asserts no secret key exists after bootstrap). The public key and
  ownertrust are derived from the private key on import, so the backup is a
  single file. To rotate or refresh the backup, run
  `~/.scripts/gpg/generate-gpg-backup.sh` from the repo root on a machine
  that has the key, then commit the new blob — it writes the encrypted
  export to `./gpg/private-key.asc.gpg` (override the destination with
  `GPG_BACKUP_OUT`; the import source with `GPG_BACKUP_FILE`). The key id is
  pinned in both scripts (override with `GPG_KEY_ID`).
- **gopass store**: the password store itself is the public repo
  `github.com/nexdep/.gopass`, cloned keylessly over HTTPS by
  `lib/install-gopass-store.sh` (every tier, CI included) into gopass's
  default root-store path (`~/.local/share/gopass/stores/root`); re-runs
  skip if the store exists. The push URL is switched to SSH so
  `gopass sync` can push once an SSH key is set up, while pulls need no
  credentials. Being public, the repo exposes secret *names* (file paths)
  and git history; the contents are encrypted to the personal GPG key, so
  they are unreadable without it (as in CI, where the key import is
  skipped).
- **gomi**: prebuilt binary from GitHub releases into `/usr/local/bin`. Config
  ships as `home/dot_config/gomi/config.yaml.tmpl` (templated only for the
  absolute `gomi_dir` path) and is ignored on servers, where gomi isn't
  installed.
- **starship**: prebuilt binary from GitHub releases into `/usr/local/bin`,
  same pattern as gomi. Config (`home/dot_config/starship.toml`) is the same
  on every machine and just disables the battery module.
- **bat / fd**: plain Ubuntu apt packages (`bat`, `fd-find`), but Ubuntu names
  the binaries `batcat` and `fdfind`; `bootstrap.sh` symlinks them as `bat`
  and `fd` in `/usr/local/bin` so tools that call them by their upstream
  names (yazi's fg plugin previews, LazyVim's file finding) work.
- **rust / tree-sitter**: rustup via its official installer with
  `--no-modify-path` (so it never edits the chezmoi-managed shell profiles —
  `~/.cargo/bin` is added to PATH by the core zshrc fragment instead), then
  `cargo install --locked tree-sitter-cli` builds tree-sitter from source
  (needed by nvim-treesitter). Both live user-level under `~/.cargo`.
- **tailscale**: official install script, which registers tailscale's own apt
  repo, so it updates with `apt upgrade`. Joining the tailnet
  (`tailscale up`) stays manual.
- **rclone**: official install script into `/usr/bin`; no apt repo, so
  re-running `bootstrap.sh` only reinstalls if the command is missing.
- **lazygit**: prebuilt binary from GitHub releases into `/usr/local/bin`.
  Assets embed the version, which is resolved from the `releases/latest`
  redirect (no GitHub API).
- **ripgrep-all (rga)**: prebuilt binaries (`rga`, `rga-fzf`, `rga-preproc`)
  from GitHub releases into `/usr/local/bin`, version resolved like lazygit;
  `pandoc` (apt, extra tier) enables document search.
- **dezoomify-rs**: prebuilt binary from GitHub releases (fixed-name linux
  asset) into `/usr/local/bin`; x86_64 only.
- **Claude Code / uv**: official install scripts, user-level into
  `~/.local/bin` (Claude Code self-updates there; `bubblewrap` from core apt
  provides its Linux sandbox). Re-running `bootstrap.sh` only reinstalls if
  the command is missing.
- **Codex CLI**: prebuilt binary from the GitHub release assets (fixed
  names, fetched via the `releases/latest` redirect) into `~/.local/bin` —
  the official install script resolves versions through the GitHub API,
  which gets rate-limited in CI.
- **Cursor Agent CLI**: official installer script (`cursor.com/install`),
  user-level into `~/.local/bin` (symlinks both `cursor-agent` and `agent`;
  self-updates via `cursor-agent update`). The installer downloads from the
  Cursor CDN, not the GitHub API, so it is CI-safe.
- **GitHub Copilot CLI / Pi**: `npm install -g` (npm is a core package),
  matching bw. Copilot from `@github/copilot` (needs Node 22+, satisfied by
  the core `nodejs` package); Pi (pi.dev) from
  `@earendil-works/pi-coding-agent` with `--ignore-scripts` — its `curl | sh`
  installer is an interactive TUI unsuitable for a non-interactive bootstrap.
- **opencode**: prebuilt binary from the GitHub release assets (fixed-name
  `opencode-linux-<arch>.tar.gz`, fetched via the `releases/latest` redirect)
  into `/usr/local/bin`. The official installer (`opencode.ai/install`) is
  avoided: it unpacks into `~/.opencode/bin` and appends a PATH export to the
  shell rc file, which the chezmoi-managed `.zshrc` would overwrite.
  `opencode --version` hangs without a TTY, so bootstrap logs no version and
  verify only checks PATH presence.
- **bw (Bitwarden CLI)**: `npm install -g @bitwarden/cli` (npm is a core
  package). No apt package exists, and the bitwarden/clients GitHub
  releases mix per-product tags, so the redirect trick used elsewhere is
  unreliable. Backs the zshrc `bw_login`/`bw_fetch_ssh` helpers; planned
  for retirement once gopass fully replaces it.
- **imagemagick caveat**: if Ubuntu still ships ImageMagick 6 there is no
  `magick` binary, so yazi's `magick`-based previews (avif/heic/jxl/svg)
  won't run; the common image/video/pdf previews use their own previewers
  (image/ffmpeg/pdftoppm) and work regardless.
- **yazi**: prebuilt `yazi` + `ya` binaries from the GitHub release zip
  (fixed-name assets, unpacked with `unzip`) into `/usr/local/bin`, plus the
  `_ya`/`_yazi` zsh completions into `/usr/local/share/zsh/site-functions`,
  same pattern as gomi. The preview/archive helpers it calls (imagemagick,
  ffmpeg, poppler-utils, chafa, 7z from p7zip-full) come from the extra-tier
  package list. The config (`home/dot_config/yazi/`) deploys on
  laptop+wsl only (gated in `home/.chezmoiignore`); `yazi.toml` is a
  template because the "open" opener differs per machine — Windows
  Explorer via WSL interop on wsl, `xdg-open` on the laptop. Plugins are
  pinned in `package.toml` and installed/updated by a chezmoi
  `run_onchange` script that runs `ya pkg install` whenever the pin list
  changes; the plugin code itself (`~/.config/yazi/plugins/`) is not
  versioned here. `ya pkg` rewrites `~/.config/yazi/package.toml` in its
  own normalized form (array-of-tables, `hash` field, comments stripped),
  so the committed file must be exactly that form or every
  `chezmoi apply` would flag it as drifted — to change pins, edit the
  target file with `ya pkg add`/`ya pkg install` and
  `chezmoi re-add ~/.config/yazi/package.toml`. The `y` cd-on-quit wrapper lives in the workstation
  zshrc fragment; the plugins additionally rely on ripgrep, fzf, bat and
  zoxide from the core tier.
- **neovim**: official tarball from the latest GitHub release
  (fixed-name assets for x86_64 and arm64) into `/opt/nvim`, symlinked as
  `nvim` in `/usr/local/bin` — Ubuntu's apt package lags far behind
  upstream. No apt repo, so re-running `bootstrap.sh` only reinstalls if
  `/opt/nvim/bin/nvim` is missing. The config (`home/dot_config/nvim/`) is
  a [LazyVim](https://www.lazyvim.org) setup (based on the LazyVim
  starter), identical on every machine: the WSL-only clipboard integration
  is a runtime `vim.fn.has("wsl")` check in `lua/config/options.lua`, not
  a template. That clipboard block uses `win32yank.exe`, which this repo
  does **not** install — it's a Windows-side utility expected on the WSL
  interop PATH (e.g. shipped with a Windows Neovim install).
  `lazy-lock.json` (pinned plugin versions) is chezmoi-managed, so after a
  `:Lazy update` run `chezmoi re-add ~/.config/nvim/lazy-lock.json` to
  record the new pins.
- **conda**: Miniforge3 (conda-forge's installer, not Anaconda/Miniconda),
  installed per-user into `$HOME/miniforge3` via the official installer
  script in batch mode. Config (`home/dot_condarc`) is taken from the
  current system: conda-forge channel only, and `changeps1: false` since
  starship's conda module already shows the active env in the prompt.
  Base env is auto-activated in every shell by the workstation zshrc
  fragment, matching the current system's `auto_activate_base: true`.
- **WezTerm**: `wezterm-nightly` apt package from WezTerm's official Fury
  repo (apt.fury.io/wez), so it updates with `apt upgrade`.
- **VS Code Insiders**: `code-insiders` apt package from Microsoft's
  official repo (packages.microsoft.com/repos/code), so it updates with
  `apt upgrade`.
- **Obsidian**: official `.deb` from the latest GitHub release
  (obsidianmd/obsidian-releases), installed via `apt install ./obsidian.deb`
  so its declared dependencies resolve from the standard repos. No apt repo
  is published, so this doesn't auto-update with `apt upgrade` — re-running
  `bootstrap.sh` only reinstalls if the `obsidian` command is missing.
- **Evolution / evolution-ews**: plain Ubuntu universe apt packages, listed
  in `lib/packages-gui.txt` like any other apt package (no extra repo
  needed). `evolution-ews` adds the Exchange Web Services connector; it's a
  backend module with no executable of its own.
- **Google Chrome**: official `.deb` from `dl.google.com` (fixed URL, no
  version to resolve), installed via `apt install ./google-chrome.deb`.
  Unlike Obsidian, its postinst script self-registers Google's own apt
  repo, so it updates with a normal `apt upgrade` afterwards.
- **Slack**: official `.deb` from `downloads.slack-edge.com`. Like
  Obsidian, release filenames embed the version and Slack has no apt repo
  or GitHub releases, so the latest download URL is scraped from Slack's
  own downloads page. Re-running `bootstrap.sh` only reinstalls if the
  `slack` command is missing.
- **Zoom**: official `.deb` from `zoom.us/client/latest` (fixed URL, no
  version to resolve, like Google Chrome). No apt repo is published, so
  re-running `bootstrap.sh` only reinstalls if the `zoom` command is
  missing.
- **ParaView**: official Kitware tarball in `/opt/paraview` (symlinked as
  `paraview`), same pattern as Thunderbird Beta — no `.deb` or apt repo is
  published. The latest version is resolved from paraview.org's own
  directory listing at `paraview.org/files/`.
- **VLC**: plain Ubuntu universe apt package, listed in
  `lib/packages-gui.txt` like Evolution — no extra repo needed.
- **Zotero**: installed exactly per the community apt repo's own
  instructions (https://zotero.retorque.re/file/apt-package-archive/) —
  its `install.sh` sets up the apt repo/keyring, then `apt install zotero`.
  zotero.org itself only ships a tarball; this repo (referenced from
  zotero.org's own Linux install docs) is the de facto standard apt
  source and updates with a normal `apt upgrade`. `install.sh` calls
  `sudo` internally regardless of how it's invoked, so `sudo` is
  installed first if missing (bare containers usually lack it).
- **Clockify**: official `.deb` from `clockify.me/downloads` (fixed URL per
  architecture — both x64 and arm64 are published — no version to
  resolve), per the instructions at clockify.me/linux-time-tracking. No
  apt repo is published, so re-running `bootstrap.sh` only reinstalls if
  the `clockify` command is missing.
- **LibreOffice**: plain Ubuntu archive packages, listed in
  `lib/packages-gui.txt` like Evolution and VLC — no extra repo needed.
  `libreoffice-help-en-us` adds the offline English help (a data package
  with no executable). Because that list is installed with
  `--no-install-recommends` (see the Recommends note above), three things
  LibreOffice only *recommends* are named explicitly rather than lost:
  `libreoffice-gnome` (native GTK file dialogs and theming — without it the
  suite falls back to its generic backend and looks out of place) and
  `fonts-crosextra-caladea` / `fonts-crosextra-carlito` / `fonts-liberation`
  (metric-compatible replacements for Cambria, Calibri and
  Arial/Times/Courier, so `.docx` files keep their layout). The rest of
  LibreOffice's Recommends — the Noto font set, the Java stack, the
  mysql/postgresql SDBC drivers — are deliberately skipped.
- **Spotify**: `spotify-client` from Spotify's official apt repo
  (repository.spotify.com, signed by `pubkey_5384CE82BA52C83A`), so it
  updates with `apt upgrade`. The repo publishes amd64 (and i386) only —
  no arm64 — hence the `arch=amd64` option on the source line. Its
  dependencies still use the pre-t64 library names (`libasound2`,
  `libgtk-3-0`, `libglib2.0-0`, `libatk-bridge2.0-0`); these resolve
  through the `Provides:` on Ubuntu's `*t64` packages. One exception is
  pinned deliberately: `libasound2` is provided both by `libasound2t64`
  (real ALSA) and by `liboss4-salsa-asound2` (an OSS4 compatibility shim
  that `Conflicts` with it), and apt picks the *shim* when nothing has
  already pulled ALSA in. The bootstrap order hides this — the gui package
  list installs vlc, which pulls real ALSA, before `install-gui.sh` runs —
  so `libasound2t64` is listed explicitly in that `apt-get install` to make
  the choice deterministic instead of a side effect of vlc.
- **OneDrive links** (wsl only): `lib/install-onedrive-links.sh` resolves
  the logged-in Windows profile via cmd.exe interop (falling back to
  scanning `/mnt/c/Users`) and symlinks each `OneDrive*` folder into the
  home directory: personal `OneDrive` → `~/onedrive`, business
  `OneDrive - <Org>` → `~/onedrive_<org-initials>` (e.g. "Massachusetts
  Institute of Technology" → `~/onedrive_mit`). It only manages those
  canonical names — it never clobbers a real file/dir, repoints stale
  managed symlinks, leaves symlinks under other names alone, and
  self-skips where there is no Windows mount (CI).

## Not ported / dropped in migration

Deliberately **not** ported from the old pre-chezmoi setup scripts: stow
(replaced by chezmoi), the apt upgrade step (not bootstrap's job), the
fastfetch PPA and eza third-party repo (both are plain universe packages
now), rng-tools (obsolete), the version-pinned libclang-common-21-dev
(replaced by unversioned `libclang-dev`, which bindgen needs to build
tree-sitter-cli), fzf-from-git and zoxide-via-curl (both apt now), and the
`zsh_wsl_neutronics` shell fragment (superseded by the zshrc fragments and
the `~/.zsh` drop-in dir; its OpenMC exports pointed at a nonexistent
endfb-viii.1 data dir).

Likewise dropped from the old `.zshrc` during its migration into the
fragments: `prompt suse` (starship), the `/home/root/.local/bin` and
`/opt/nvim/bin` PATH entries (stale / covered by the /usr/local/bin
symlink), `export DISPLAY=:0.0` (WSL1-era hack that breaks WSLg), the
`~/.fzf.zsh` legacy source, the nvm lazy-load shims (npm comes from apt
now), the jupyter-notebook alias (no global jupyter install), and
`HISTDUP=erase` (a bash-ism, not a zsh option).
