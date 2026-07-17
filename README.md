# dotfiles2

Bootstrap + dotfiles for my Ubuntu 26.04 LTS machines. One command installs
the programs for the machine's tier and deploys configuration with
[chezmoi](https://chezmoi.io).

## Machine types and tiers

Each tier is a strict superset of the one below it (laptop ⊃ wsl ⊃ server):

| Tier  | Machines    | Meaning                                  |
|-------|-------------|------------------------------------------|
| core  | all         | always-on CLI basics                     |
| extra | laptop, wsl | everyday dev tools not needed on servers |
| gui   | laptop      | desktop applications                     |

The full per-tier program list and the details of how config is layered
(zshrc fragments, SSH/git config, prompts, `~/.scripts/`, the `~/.zsh`
drop-in dir, quiet-login markers) live in
[docs/machines-and-tiers.md](docs/machines-and-tiers.md).

## Usage

```sh
git clone https://github.com/marco-de-pietri/dotfiles2.git
cd dotfiles2
./bootstrap.sh laptop   # or: server | wsl (wsl is auto-detected if omitted)
```

Re-running is safe; everything is idempotent. After the first run the machine
type is remembered by chezmoi, so config changes are just `chezmoi apply`.

On an interactive first run, bootstrap also asks for one passphrase to
decrypt and import the personal GPG key (see the "Personal GPG key" note in
[docs/install-methods.md](docs/install-methods.md)); unattended runs (CI, no
TTY) skip that step automatically.

## Layout

```
bootstrap.sh                 entry point: tier-aware installs + chezmoi init
lib/common.sh                shared helpers: SUDO/log/die, add_apt_repo, install_deb
lib/packages-*.txt           apt package lists per tier
lib/install-starship.sh      starship from GitHub release binaries (all machines)
lib/install-neovim.sh        Neovim from the official release tarball into /opt (all machines)
lib/install-gpg-key.sh       imports the personal GPG key from gpg/ (all machines, TTY only)
lib/install-gopass-store.sh  clones the gopass password store from GitHub (all machines)
gpg/private-key.asc.gpg      passphrase-encrypted backup of the personal GPG key
lib/install-tailscale.sh     tailscale via its official script (all machines)
lib/install-rclone.sh        rclone via its official script (all machines)
lib/install-rust.sh          rustup + cargo-built tree-sitter-cli, user-level (all machines)
lib/install-claude-code.sh   Claude Code, user-level ~/.local/bin (all machines)
lib/install-codex.sh         Codex CLI, user-level ~/.local/bin (all machines)
lib/install-cursor-agent.sh  Cursor Agent, user-level ~/.local/bin (all machines)
lib/install-copilot.sh       GitHub Copilot CLI via npm -g (all machines)
lib/install-pi.sh            Pi (pi.dev) coding agent via npm -g (all machines)
lib/install-opencode.sh      opencode agent from GitHub release binaries (all machines)
lib/install-uv.sh            uv, user-level ~/.local/bin (all machines)
lib/install-lazygit.sh       lazygit from GitHub release binaries (all machines)
lib/install-bw.sh            bitwarden CLI via npm -g (all machines)
lib/install-gomi.sh          gomi from GitHub release binaries (laptop+wsl)
lib/install-conda.sh         Miniforge3 from the official installer script (laptop+wsl)
lib/install-yazi.sh          yazi + ya + zsh completions from GitHub release binaries (laptop+wsl)
lib/install-rga.sh           ripgrep-all from GitHub release binaries (laptop+wsl)
lib/install-dezoomify-rs.sh  dezoomify-rs from GitHub release binaries (laptop+wsl)
lib/install-onedrive-links.sh  symlinks Windows OneDrive folders into ~ (wsl only)
lib/install-gui.sh           all laptop GUI apps (apt repos, tarballs, .debs)
home/                        chezmoi source directory (via .chezmoiroot)
home/dot_scripts/            non-bootstrap scripts deployed to ~/.scripts/ (gpg, hetzner_mount, openmc_scripts, restic_b2_backups)
home/.chezmoiscripts/        chezmoi run scripts (Windows-side ssh config, yazi plugins)
home/.chezmoiignore          per-machine deploy filter (quiet-login markers, yazi config)
tests/verify.sh              tier-aware assertions (data-driven app table), used by CI
.github/workflows/ci.yml     lint + full bootstrap of all 3 machine types
docs/machines-and-tiers.md   full per-tier program list + config-layering details
docs/install-methods.md      per-program install/update methods + migration notes
```

## Install method notes

How every non-trivial program is installed and kept updated — apt repos,
tarballs, .debs, GitHub-release binaries, install scripts — plus the
Recommends policy and what was deliberately not ported from the old setup,
is documented in [docs/install-methods.md](docs/install-methods.md).

## CI

GitHub Actions runs on every push/PR:

- **lint** — shellcheck on all scripts, plus a chezmoi render of `.zshrc` for
  all three machine types (syntax-checked with `zsh -n`).
- **bootstrap** — a 3-leg matrix (`server`, `wsl`, `laptop`) that runs
  `bootstrap.sh` inside an `ubuntu:26.04` container and then
  `tests/verify.sh`, asserting each tier's programs are present (and the
  higher tiers' programs are absent). The laptop leg installs everything.
