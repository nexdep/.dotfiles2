# Contributor guide (humans and AI agents)

This repo bootstraps three kinds of Ubuntu machines and deploys dotfiles with
chezmoi. Everything below is about keeping extensions consistent with the
existing patterns — read this before adding a program or config.

## The tier model

Tiers are strict supersets: `laptop ⊃ wsl ⊃ server`.

| Tier  | Machines     | Meaning                                   |
|-------|--------------|-------------------------------------------|
| core  | all          | always-on CLI basics                       |
| extra | laptop, wsl  | everyday dev tools not needed on servers   |
| gui   | laptop       | desktop applications                       |

Everything is keyed off this: package lists, installer scripts, zshrc
fragments, and the verify checks.

## Adding a program — decision tree

1. **Plain Ubuntu archive package** (check `apt-cache policy <pkg>`):
   add one line to `lib/packages-<tier>.txt`. Done. Inline `# comments`
   after package names are allowed.
2. **Third-party apt repo** (vendor publishes one): call
   `add_apt_repo <name> <key_url> <options> "<repo suite components>"`
   (from `lib/common.sh`) in the repo-registration section of the right
   installer script, and add the package to the batched
   `apt-get install` there. Don't add your own `apt-get update` — repos
   are registered first and updated once.
3. **Official .deb but no repo**: add a block in `lib/install-gui.sh`:
   already-installed guard (`command -v <bin>`) → architecture check
   (`die` loudly on unsupported arches) → resolve the URL if the filename
   embeds a version → one `install_deb <name> <url>` call.
4. **Tarball only** (no .deb at all): follow the Thunderbird Beta /
   ParaView pattern — extract to `/opt/<name>`, symlink the binary into
   `/usr/local/bin`, write a `.desktop` file to
   `/usr/local/share/applications`, and `chown` the /opt dir to the user
   if the app self-updates.
5. **Single static binary** (GitHub releases): follow
   `lib/install-gomi.sh` / `lib/install-starship.sh` — its own script in
   `lib/`, called from `bootstrap.sh` under the right tier condition.

Prefer `releases/latest/download/<fixed-name>` URLs over the GitHub API
(rate limits in CI); resolve versioned filenames via the
`releases/latest` redirect (see obsidian) or by scraping the vendor's own
page (see slack, paraview) with a loud `die` if the scrape comes back empty.

## Every program addition MUST also update

1. **`tests/verify.sh`**: one row in the `apps` table
   (`tier|name|present-check[|absent-check]`). The loop derives both the
   "installed on its tier" and "absent below its tier" assertions from
   that single row.
   - Prefer `command -v <bin>` as the present check for GUI/Electron
     apps: running `--version` headless as root is unreliable (obsidian
     launches the full app and hangs; vlc exits 1 silently; Electron
     needs `--no-sandbox --user-data-dir`). This was learned the hard
     way — don't rediscover it.
2. **`docs/machines-and-tiers.md`**: the tier table row (the program table
   under "Machines and tiers"). And, for anything that isn't a plain
   archive package, a bullet in **`docs/install-methods.md`** saying where
   it comes from and how it updates.

## Invariants

- **Idempotent**: re-running `bootstrap.sh` must be safe. Guard non-apt
  installs; apt handles its own.
- **Root and sudo both work**: scripts run as root in CI containers and
  via sudo on real machines. Use `$SUDO` (from `lib/common.sh`) for
  privileged commands; never bare `sudo`.
- **No snap**: CI runs in containers without snapd, so snap-based installs
  can't be tested and are not used.
- **Recommends policy**: package-list installs use
  `--no-install-recommends`; GUI app installs deliberately keep apt's
  default Recommends handling (see docs/install-methods.md).
- **Boilerplate lives in `lib/common.sh`** (`LOG_TAG=<name>` then
  `source .../common.sh`); don't re-declare `log`/`die`/`SUDO`.

## Before pushing

- `shellcheck bootstrap.sh lib/*.sh tests/*.sh $(find home/dot_scripts -type f -name '*.sh')`
  must be clean (CI runs it; note the runner's shellcheck may use different
  codes for the same finding — disable both, e.g. `SC2317,SC2329`).
- Render the dotfiles for all three machine types and syntax-check:
  `HOME=$(mktemp -d) MACHINE_TYPE=<m> chezmoi init --apply --source $PWD`
  then `zsh -n $HOME/.zshrc`.
- CI (push to main) runs 4 jobs: lint + a bootstrap/verify matrix leg per
  machine type in `ubuntu:26.04` containers. All 4 must be green; the
  laptop leg installs everything and is the real end-to-end test.
