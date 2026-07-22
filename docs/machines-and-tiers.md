# Machines and tiers

Each tier is a superset of the one below it (laptop ⊃ wsl ⊃ server):

| Tier  | Machines       | Programs                                          |
|-------|----------------|---------------------------------------------------|
| core  | all            | zsh (default shell), gopass (+ password store), gnupg (+ personal GPG key), starship, neovim (+ LazyVim config and its toolchain: build-essential, npm, luarocks, sqlite3, fd, tree-sitter via rust), vim-gtk3 (+ vimrc), tmux (+ config), ssh config, git (+ config), git-lfs, gh, lazygit, prompts, ripgrep, fzf, bat, zoxide, eza, fastfetch, jq, btop, bw (bitwarden CLI), restic, sshfs (+ fuse3), openssh-server, tailscale, rclone, Claude Code (+ bubblewrap), Codex CLI, Cursor Agent CLI, GitHub Copilot CLI, Pi CLI, opencode, uv, curl, chezmoi |
| extra | laptop, wsl    | gomi (+ config), conda (miniforge), yazi (+ config, previews: imagemagick, ffmpeg, poppler, chafa, 7z), rga (+ pandoc), dezoomify-rs, LaTeX (texlive + biber + latexmk), zathura, qt6-wayland |
| gui   | laptop         | Firefox Developer Edition, Thunderbird Beta, WezTerm (nightly), VS Code Insiders, Obsidian, Evolution (+ EWS), Google Chrome, Slack, Zoom, ParaView, VLC, Zotero, Clockify, LibreOffice (+ en-US help), Spotify, libfuse2t64 (AppImage support) |

The `.zshrc` is layered the same way: a core fragment for every machine
(vi-mode line editing, EDITOR=nvim, completion styles + `~/.dircolors`,
eza aliases with auto-listing on cd, a zoxide-backed `cd` (frecency
jumps), the acp/mkcd/scroll/showpath helpers, and a background
autopull that ff-pulls `~/.dotfiles` at most every 12h — pull only,
never an unattended `chezmoi apply`), a bitwarden fragment (bw_login /
bw_fetch_ssh, kept separate so it's easy to retire), a wsl fragment
(clip/start interop aliases, Windows VS Code on PATH), a workstation
fragment for laptop/wsl, and a server fragment for servers. The
fragments live in `home/.chezmoitemplates/` and are assembled by
`home/dot_zshrc.tmpl` based on the machine type stored in chezmoi's data;
the assembled file ends with a tmux autostart (attach/create session
"main" in local interactive terminals only — skipped over SSH, in VS
Code, in nvim terminals and inside tmux itself).

The interactive sugar is deliberately kept harmless to scripts and
coding agents (whose harnesses replay snapshotted functions into
non-interactive shells): the zoxide `cd` wrapper and the eza auto-listing
`chpwd` hook check `[[ -o interactive && -t 1 ]]` at call time and fall
back to the plain builtin / a no-op, fzf keybindings only load with a
TTY, and the tmux autostart additionally requires a TTY on stdin. A
mistyped `cd` path in a script therefore fails loudly instead of
frecency-jumping somewhere unexpected.

The core zshrc also sources every file in `~/.zsh/`, a machine-local
drop-in dir that chezmoi leaves unmanaged — with one exception:
`~/.zsh/neutronics.zsh` (OpenFOAM lazy-loader, OpenMC data paths) is
deployed by chezmoi on laptop and wsl (not servers), gated in
`home/.chezmoiignore`. A guarded `~/.config/secrets.env` is sourced too,
for machine-local secrets that never enter the repo.

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

`home/dot_scripts/` deploys to `~/.scripts/` on every machine — handy
standalone scripts that are **not** used by `bootstrap.sh`, organized into
category subfolders: `gpg/` (GPG key backup/import tools), `hetzner_mount/` (SSHFS
Storage Box user-systemd mount), `openmc_scripts/` (conda/OpenMC build +
neutronics tooling + data fetcher), `restic_b2_backups/`
(restic→Backblaze systemd backup, plus a restore script for pulling a
backed-up folder back after redeploying a system), and `deploy_api/` (writes
API-key env files from gopass secrets, e.g. `~/.hermes/.env`).
Unlike the `lib/` install scripts they are
self-contained and do not source `lib/common.sh`, since they run from
`~/.scripts/` rather than the repo. Secrets are never committed — the restic
scripts only write `CHANGE_ME` placeholders into `/etc/restic`.

The core `.zshrc` sources every file in `~/.zsh/` (a drop-in dir that is
**not** chezmoi-managed): put machine-local shell snippets there instead of
editing the generated `~/.zshrc`. For example
`~/.scripts/openmc_scripts/openmc_data_fetcher.sh` downloads nuclear data and
writes the `OPENMC_CROSS_SECTIONS` / `OPENMC_CHAIN_FILE` exports to
`~/.zsh/openmc.zsh`.

A few empty quiet-login markers (`~/.hushlogin`, `~/.motd_shown`,
`~/.sudo_as_admin_successful`) are deployed **only on wsl**, gated by
`home/.chezmoiignore` (which ignores them on server/laptop). They carry the
`empty_` attribute so chezmoi keeps the zero-byte files; no program is
associated with them.
