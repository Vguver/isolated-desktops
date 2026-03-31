# isolated-desktops

Version: **1.6.0**

`isolated-desktops` is a **session-profile manager** for trying multiple Linux desktop setups on one machine with the **same Linux user** and **separate session homes**.

The repository name stays `isolated-desktops` because it is short and easy to remember, but the project is now documented more precisely:

- it **does isolate profile-level user files**
- it **does not isolate the whole operating system**

That means this project is best understood as **session-profile isolation**, not VM-style isolation.

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
├── install.sh
├── manifests/
├── presets/
├── scripts/
│   ├── adapters/
│   ├── commands/
│   └── lib/
├── docs/
├── examples/
├── tests/
├── CHANGELOG.md
├── CONTRIBUTING.md
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
idtool status
idtool list
idtool analyze omarchy
idtool install omarchy
idtool verify omarchy
idtool launcher create omarchy
idtool session create omarchy --scope system
idtool links prepare omarchy
idtool workspace open omarchy
idtool sync omarchy
idtool export omarchy
idtool start omarchy
idtool completion install
idtool self-update
```

## Safety features added in v1.5.0

- stale-lock recovery for fallback lock mode
- transaction-style rollback snapshots stored outside the live profile tree
- stronger managed-dotfiles adoption with staged copies and restore-on-failure behavior
- broader default managed paths (`.config`, `.local/bin`, `.local/share`)
- healthier verification checks for launcher syntax, session file format, and start-command availability
- atomic first clone into a temporary checkout before moving into place
- export archive verification and improved import checks
- better cleanup of custom manifests and external dotfiles when removing profiles
- safer shell argument handling and stricter validation helpers
- improved smoke tests with a fully local test adapter flow

## Additional operational features

New in v1.6.0:

- `idtool completion install` installs Bash completion for the wrapper
- `idtool self-update` updates the local project checkout safely
- install reports can now generate a **host cleanup helper script** when package, service, or tracked system-file drift is detected
- the test suite now includes lifecycle and resilience coverage for clone failures, disk-space guards, interrupted installs, and lock contention

## Managed dotfiles

By default, managed dotfiles live **inside the profile itself**:

```text
~/.local/share/isolated-desktops/profiles/<name>/dotfiles/home/
```

That keeps the whole profile easier to understand.

Useful commands:

```bash
idtool links prepare omarchy
idtool links link omarchy .config
idtool links adopt omarchy .config
idtool links repair omarchy
idtool links status omarchy
```

You can still override the dotfiles base with `ID_DOTFILES_ROOT` if you really want an external tree.

## Editor workflow

The project now generates real editor workspace files.

```bash
idtool workspace create omarchy
idtool workspace open omarchy
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
idtool analyze omarchy
idtool verify omarchy
```

To re-run installation logic against an already installed profile:

```bash
idtool update omarchy
```

## Export, import, trash, and presets

```bash
idtool export omarchy
idtool import ~/.local/share/isolated-desktops/exports/omarchy-20260101-120000.tar.gz
idtool remove omarchy
idtool trash list
idtool trash restore 20260101-120000-omarchy
idtool preset list
idtool preset install hyprland-suite
```

## Legacy wrappers kept for compatibility

These old names still exist and forward to the new structure:

- `scripts/setup_desktops.sh`
- `scripts/desktop-launch.sh`
- `scripts/desktop-sessions.sh`
- `scripts/dev-open.sh`
- `scripts/dev-sync.sh`
- `scripts/repos-desktops.sh`
- `scripts/dotfiles-link.sh`

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
idtool analyze <name>
idtool verify <name>
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

## Requirements

Required:

- Bash 4+
- Git
- Python 3

Recommended:

- `pacman` on Arch-based systems for package diff reports
- VS Code or VSCodium for editing profiles
- a display manager such as SDDM, GDM, or LightDM
- `flock` for stronger per-profile locking where available

## License

MIT
