# dotfiles2

Bootstrap + dotfiles for my Ubuntu 26.04 LTS machines. One command installs
the programs for the machine's tier and deploys configuration with
[chezmoi](https://chezmoi.io).

## Machine types and tiers

Each tier is a superset of the one below it (laptop ⊃ wsl ⊃ server):

| Tier  | Machines       | Programs                                          |
|-------|----------------|---------------------------------------------------|
| core  | all            | zsh (default shell), gopass, starship, git, curl, chezmoi |
| extra | laptop, wsl    | gomi, conda (miniforge)                           |
| gui   | laptop         | Firefox Developer Edition, Thunderbird Beta, WezTerm (nightly) |

The `.zshrc` is layered the same way: a core fragment for every machine, a
workstation fragment for laptop/wsl, and a server fragment for servers. The
fragments live in `home/.chezmoitemplates/` and are assembled by
`home/dot_zshrc.tmpl` based on the machine type stored in chezmoi's data.

## Usage

```sh
git clone https://github.com/marco-de-pietri/dotfiles2.git
cd dotfiles2
./bootstrap.sh laptop   # or: server | wsl (wsl is auto-detected if omitted)
```

Re-running is safe; everything is idempotent. After the first run the machine
type is remembered by chezmoi, so config changes are just `chezmoi apply`.

## Layout

```
bootstrap.sh                 entry point: tier-aware installs + chezmoi init
lib/packages-*.txt           apt package lists per tier
lib/install-gomi.sh          gomi from GitHub release binaries (laptop+wsl)
lib/install-conda.sh         Miniforge3 from the official installer script (laptop+wsl)
lib/install-gui.sh           Firefox Dev Edition + Thunderbird Beta (laptop)
home/                        chezmoi source directory (via .chezmoiroot)
tests/verify.sh              tier-aware assertions, used by CI
.github/workflows/ci.yml     lint + full bootstrap of all 3 machine types
```

## Install method notes

- **Firefox Developer Edition**: Mozilla's official apt repo
  (packages.mozilla.org), pinned above Ubuntu's snap-transition stubs, so it
  updates with `apt upgrade`.
- **Thunderbird Beta**: official Mozilla tarball in `/opt/thunderbird-beta`
  (symlinked as `thunderbird-beta`). Neither packages.mozilla.org nor a
  maintained PPA ships a Thunderbird beta channel for this release; the app
  self-updates through its internal updater.
- **gomi**: prebuilt binary from GitHub releases into `/usr/local/bin`.
- **starship**: prebuilt binary from GitHub releases into `/usr/local/bin`,
  same pattern as gomi. Config (`home/dot_config/starship.toml`) is the same
  on every machine and just disables the battery module.
- **conda**: Miniforge3 (conda-forge's installer, not Anaconda/Miniconda),
  installed per-user into `$HOME/miniforge3` via the official installer
  script in batch mode. Config (`home/dot_condarc`) is taken from the
  current system: conda-forge channel only, and `changeps1: false` since
  starship's conda module already shows the active env in the prompt.
  Base env is auto-activated in every shell by the workstation zshrc
  fragment, matching the current system's `auto_activate_base: true`.
- **WezTerm**: `wezterm-nightly` apt package from WezTerm's official Fury
  repo (apt.fury.io/wez), so it updates with `apt upgrade`.

## CI

GitHub Actions runs on every push/PR:

- **lint** — shellcheck on all scripts, plus a chezmoi render of `.zshrc` for
  all three machine types (syntax-checked with `zsh -n`).
- **bootstrap** — a 3-leg matrix (`server`, `wsl`, `laptop`) that runs
  `bootstrap.sh` inside an `ubuntu:26.04` container and then
  `tests/verify.sh`, asserting each tier's programs are present (and the
  higher tiers' programs are absent). The laptop leg installs everything.
