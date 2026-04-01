# isolated-desktops

Version: **1.6.1**

`isolated-desktops` is a **session-profile manager** for trying multiple Linux desktop setups on one machine with the **same Linux user** and **separate session homes**.

The repository name stays `isolated-desktops` because it is short and easy to remember, but the project is intentionally documented more precisely:

- it **does isolate profile-level user files**
- it **does not isolate the whole operating system**

That means this project is best understood as **session-profile isolation**, not VM-style isolation.

## Quick start

```bash
git clone https://github.com/Vguver/isolated-desktops.git
cd isolated-desktops
chmod +x install.sh
./install.sh --bootstrap

# Then use the CLI wrapper from the local checkout
scripts/idtool.sh status
scripts/idtool.sh analyze omarchy
scripts/idtool.sh install omarchy
scripts/idtool.sh verify omarchy
scripts/idtool.sh launcher create omarchy
scripts/idtool.sh session create omarchy --scope user --type wayland
```

## Screenshots

### Status dashboard

![Status dashboard](assets/screenshots/status-dashboard.svg)

### Available profile list

![Profile list](assets/screenshots/profile-list.svg)

## What is isolated

Separated per profile:

- `HOME`
- `.config`
- `.local/share`
- `.cache`
- `.local/state`
- profile-specific logs, reports, snapshots, backups, workspaces, managed dotfiles, and runtime helpers

Still shared system-wide:

- installed packages
- services
- `/etc`
- `/usr`
- display-manager behavior
- anything an upstream installer decides to change outside the profile home

## What problem this solves

Many third-party desktop setups assume a fresh install. When you try several of them on one real machine, their user configs mix together.

This project keeps **one Linux account** but lets you start **different sessions** that each point to a different profile home. That makes it much easier to:

- test Omarchy, JaKooLit, ML4W, DWM Titus, and similar projects
- compare how their configs are structured
- keep what you like and discard what you do not
- edit everything from VS Code or VSCodium through generated workspaces
- export, import, verify, update, and snapshot profiles with a cleaner workflow

## Main ideas

The project is organized around these layers:

1. **manifests** describe each supported desktop project
2. **adapters** handle project-specific install behavior
3. **profiles** store the real per-session state on disk
4. **managed dotfiles** make symlink-based editing and recovery clearer
5. **editor workspaces** make the project genuinely usable from VS Code or VSCodium
6. **verification, rollback, trash, export, and presets** make the workflow safer

This replaces the older generic approach of “find any `install.sh` and run it”.

## Current project layout

```text
isolated-desktops/
├── assets/
│   └── screenshots/
├── install.sh
├── manifests/
├── presets/
├── scripts/
│   ├── adapters/
│   ├── commands/
│   ├── completions/
│   └── lib/
├── docs/
├── examples/
├── tests/
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── INSTALLATION.md
├── LICENSE
├── SECURITY.md
└── VERSION
```

Installed profile state lives outside the repo under:

```text
~/.local/share/isolated-desktops/profiles/<name>/
```

Each profile contains:

```text
home/
repo/
logs/
reports/
snapshots/
runtime/
dotfiles/
workspace/
backups/
meta.json
```

## Main commands

```bash
./install.sh --bootstrap
scripts/idtool.sh status
scripts/idtool.sh list
scripts/idtool.sh analyze omarchy
scripts/idtool.sh install omarchy
scripts/idtool.sh update omarchy
scripts/idtool.sh verify omarchy
scripts/idtool.sh launcher create omarchy
scripts/idtool.sh session create omarchy --scope system
scripts/idtool.sh links prepare omarchy
scripts/idtool.sh workspace open omarchy
scripts/idtool.sh sync omarchy
scripts/idtool.sh export omarchy
scripts/idtool.sh start omarchy
scripts/idtool.sh completion install
scripts/idtool.sh self-update
```

## Safety features

Highlights from the hardened 1.5.x and 1.6.x line:

- stale-lock recovery for fallback lock mode
- transaction-style rollback snapshots stored outside the live profile tree
- stronger managed-dotfiles adoption with staged copies and restore-on-failure behavior
- broader default managed paths (`.config`, `.local/bin`, `.local/share`)
- healthier verification checks for launcher syntax, session file format, repo integrity, and start-command availability
- atomic first clone into a temporary checkout before moving into place
- export archive verification and improved import checks
- safer cleanup of custom manifests and external dotfiles when removing profiles
- Bash completion support and git-based project self-update
- lifecycle and resilience tests for clone failures, disk-space guards, interrupted installs, and lock contention

## Managed dotfiles

By default, managed dotfiles live **inside the profile itself**:

```text
~/.local/share/isolated-desktops/profiles/<name>/dotfiles/home/
```

Useful commands:

```bash
scripts/idtool.sh links prepare omarchy
scripts/idtool.sh links link omarchy .config
scripts/idtool.sh links adopt omarchy .config
scripts/idtool.sh links repair omarchy
scripts/idtool.sh links status omarchy
```

You can still override the dotfiles base with `ID_DOTFILES_ROOT` if you really want an external tree.

## Editor workflow

The project generates real VS Code / VSCodium workspace files.

```bash
scripts/idtool.sh workspace create omarchy
scripts/idtool.sh workspace open omarchy
```

The generated workspace includes:

- profile home
- cloned repo
- managed dotfiles
- logs
- reports
- snapshots
- backups

## Health checks and updates

Before trusting a profile, use:

```bash
scripts/idtool.sh analyze omarchy
scripts/idtool.sh verify omarchy
```

To re-run installation logic against an already installed profile:

```bash
scripts/idtool.sh update omarchy
```

## Export, import, trash, and presets

```bash
scripts/idtool.sh export omarchy
scripts/idtool.sh import ~/.local/share/isolated-desktops/exports/omarchy-20260101-120000.tar.gz
scripts/idtool.sh remove omarchy
scripts/idtool.sh trash list
scripts/idtool.sh trash restore 20260101-120000-omarchy
scripts/idtool.sh preset list
scripts/idtool.sh preset install hyprland-suite
```

## Strong warning

This project is much safer and cleaner than the original generic-script approach, but it still **cannot guarantee** that every third-party installer will stay inside the profile.

If an upstream installer:

- installs packages
- edits `/etc`
- enables services
- writes into `/usr/share`
- changes display manager settings

those are still **host-wide changes**.

Always run:

```bash
scripts/idtool.sh analyze <name>
scripts/idtool.sh verify <name>
```

before trusting a profile on your main machine.

## Included documentation

- `INSTALLATION.md`
- `docs/ARCHITECTURE.md`
- `docs/ADAPTERS.md`
- `docs/MANIFESTS.md`
- `docs/STATE-LAYOUT.md`
- `docs/TROUBLESHOOTING.md`
- `docs/FAQ.md`
- `docs/MIGRATION_FROM_V2.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `CODE_OF_CONDUCT.md`

## Requirements

Required:

- Bash 4+
- Git
- curl

Recommended:

- Arch-based host if you want to test Arch-specific desktop installers
- VS Code or VSCodium for workspace editing
- a display manager such as SDDM, GDM, or LightDM if you want login-screen sessions

## Publishing and legal notes

This repository uses the MIT License for the project code itself. Third-party desktop projects referenced by manifests keep their **own licenses, trademarks, assets, and install logic**. If you later add screenshots, wallpapers, themes, fonts, or copied upstream files, review the license of each upstream project before redistributing them.

## Community files

This repository includes:

- `LICENSE`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `CODE_OF_CONDUCT.md`

These files help GitHub show a healthier public project profile and make expectations clearer for contributors and users.

## License

Released under the MIT License. See `LICENSE`.
