# dotfiles2

Bootstrap + dotfiles for my Ubuntu 26.04 LTS machines. One command installs
the programs for the machine's tier and deploys configuration with
[chezmoi](https://chezmoi.io).

## Machine types and tiers

Each tier is a superset of the one below it (laptop ⊃ wsl ⊃ server):

| Tier  | Machines       | Programs                                          |
|-------|----------------|---------------------------------------------------|
| core  | all            | zsh (default shell), gopass (+ password store), gnupg (+ personal GPG key), starship, neovim (+ LazyVim config), vim-gtk3 (+ vimrc), tmux (+ config), ssh config, git (+ config), prompts, ripgrep, fzf, bat, zoxide, curl, chezmoi |
| extra | laptop, wsl    | gomi, conda (miniforge), yazi (+ config)          |
| gui   | laptop         | Firefox Developer Edition, Thunderbird Beta, WezTerm (nightly), VS Code Insiders, Obsidian, Evolution (+ EWS), Google Chrome, Slack, Zoom, ParaView, VLC, Zotero, Clockify |

The `.zshrc` is layered the same way: a core fragment for every machine, a
workstation fragment for laptop/wsl, and a server fragment for servers. The
fragments live in `home/.chezmoitemplates/` and are assembled by
`home/dot_zshrc.tmpl` based on the machine type stored in chezmoi's data.

The SSH client config (`home/private_dot_ssh/config`) is deployed to
`~/.ssh/config` on every machine — only the config (host aliases) is
versioned, never private keys. The `private_` prefix keeps `~/.ssh` at mode
`0700`, and chezmoi manages just that one file, leaving existing keys and
`known_hosts` in place. On WSL, a chezmoi `run_onchange` script
(`home/.chezmoiscripts/`) additionally mirrors the config into the Windows
user's home as `.ssh/config_dotfiles` and prepends
`Include config_dotfiles` to the Windows `.ssh/config` (creating it if
missing), so Windows-side tools resolve the same host aliases while
Windows-only hosts stay in the Windows file. The script no-ops when WSL
interop is unavailable (as in CI containers).

The git config is deployed on every machine from `home/dot_gitconfig`,
`home/dot_gitconfig_nexdep`, `home/dot_gitconfig_marco` and
`home/dot_gitignore_global` — plain static files, identical everywhere. The
top-level `~/.gitconfig` picks a per-account identity file with
`includeIf "hasconfig:remote.*.url:…"`, so a repo whose remote is under
`nexdep/**` uses `~/.gitconfig_nexdep` and one under `marco-de-pietri/**` uses
`~/.gitconfig_marco` (each sets its own name/email and a `core.sshCommand`
selecting that account's key). Only config is versioned, never the
`~/.ssh/marco-dev-*` keys those `sshCommand`s point at (same policy as the SSH
config). An ephemeral VS Code dev-container credential helper that had been
injected into the marco identity was intentionally dropped, since its path
only exists inside that throwaway container.

`home/dot_prompts/shared/` deploys to `~/.prompts/shared/` on every
machine — personal reference prompts for research reading/writing (paper
proofreading, replication, summarization, etc.), plain static markdown
files with no associated program.

A few empty quiet-login markers (`~/.hushlogin`, `~/.motd_shown`,
`~/.sudo_as_admin_successful`) are deployed **only on wsl**, gated by
`home/.chezmoiignore` (which ignores them on server/laptop). They carry the
`empty_` attribute so chezmoi keeps the zero-byte files; no program is
associated with them.

## Usage

```sh
git clone https://github.com/marco-de-pietri/dotfiles2.git
cd dotfiles2
./bootstrap.sh laptop   # or: server | wsl (wsl is auto-detected if omitted)
```

Re-running is safe; everything is idempotent. After the first run the machine
type is remembered by chezmoi, so config changes are just `chezmoi apply`.

On an interactive first run, bootstrap also asks for one passphrase to
decrypt and import the personal GPG key (see "Personal GPG key" below);
unattended runs (CI, no TTY) skip that step automatically.

## Layout

```
bootstrap.sh                 entry point: tier-aware installs + chezmoi init
lib/common.sh                shared helpers: SUDO/log/die, add_apt_repo, install_deb
lib/packages-*.txt           apt package lists per tier
lib/install-starship.sh      starship from GitHub release binaries (all machines)
lib/install-neovim.sh        Neovim from the official release tarball into /opt (all machines)
lib/install-gpg-key.sh       imports the personal GPG key from gpg/ (all machines, TTY only)
lib/install-gopass-store.sh  clones the gopass password store from GitHub (all machines)
lib/generate-gpg-backup.sh   manual tool: re-export the key into gpg/ (never run by bootstrap)
gpg/private-key.asc.gpg      passphrase-encrypted backup of the personal GPG key
lib/install-gomi.sh          gomi from GitHub release binaries (laptop+wsl)
lib/install-conda.sh         Miniforge3 from the official installer script (laptop+wsl)
lib/install-yazi.sh          yazi + ya from GitHub release binaries (laptop+wsl)
lib/install-gui.sh           all laptop GUI apps (apt repos, tarballs, .debs)
home/                        chezmoi source directory (via .chezmoiroot)
home/.chezmoiscripts/        chezmoi run scripts (Windows-side ssh config, yazi plugins)
home/.chezmoiignore          per-machine deploy filter (quiet-login markers, yazi config)
tests/verify.sh              tier-aware assertions (data-driven app table), used by CI
.github/workflows/ci.yml     lint + full bootstrap of all 3 machine types
```

## Install method notes

Note on Recommends: packages from the `lib/packages-*.txt` lists are
installed with `--no-install-recommends` to keep servers and CI lean, while
the GUI apps below (both repo- and .deb-based) deliberately keep apt's
default Recommends handling — desktop apps often rely on them (e.g. Zoom
pulls in ibus and mesa extras).

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
  passphrase. `lib/install-gpg-key.sh` (called by `bootstrap.sh` on every
  tier) decrypts it, imports it, and marks it ultimately trusted. It skips
  itself when the key is already in the keyring or when there is no TTY, so
  CI never imports it (`tests/verify.sh` asserts this). The public key and
  ownertrust are derived from the private key on import, so the backup is a
  single file. To rotate or refresh the backup, run
  `lib/generate-gpg-backup.sh` on a machine that has the key and commit the
  new blob; the key id is pinned in both scripts (override with
  `GPG_KEY_ID`).
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
- **gomi**: prebuilt binary from GitHub releases into `/usr/local/bin`.
- **starship**: prebuilt binary from GitHub releases into `/usr/local/bin`,
  same pattern as gomi. Config (`home/dot_config/starship.toml`) is the same
  on every machine and just disables the battery module.
- **bat**: plain Ubuntu apt package, but Ubuntu names the binary `batcat`;
  `bootstrap.sh` symlinks it as `bat` in `/usr/local/bin` so scripts that
  call `bat` by its upstream name (yazi's fg plugin previews) work.
- **yazi**: prebuilt `yazi` + `ya` binaries from the GitHub release zip
  (fixed-name assets, unpacked with `unzip`) into `/usr/local/bin`, same
  pattern as gomi. The config (`home/dot_config/yazi/`) deploys on
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

## CI

GitHub Actions runs on every push/PR:

- **lint** — shellcheck on all scripts, plus a chezmoi render of `.zshrc` for
  all three machine types (syntax-checked with `zsh -n`).
- **bootstrap** — a 3-leg matrix (`server`, `wsl`, `laptop`) that runs
  `bootstrap.sh` inside an `ubuntu:26.04` container and then
  `tests/verify.sh`, asserting each tier's programs are present (and the
  higher tiers' programs are absent). The laptop leg installs everything.
