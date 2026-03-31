# State Layout

Project state is stored under:

```text
~/.local/share/isolated-desktops/
```

## Top-level layout

```text
isolated-desktops/
├── profiles/            # installed profiles
├── trash/               # removed profiles kept for restore
├── exports/             # generated export archives
└── metrics/             # optional local metrics log if enabled
```

## Per-profile layout

```text
profiles/<name>/
├── home/                # live HOME used by the session
├── repo/                # cloned upstream repository
├── logs/                # install and runtime logs
├── reports/             # package diffs and changed-file reports
├── snapshots/           # Git snapshots of selected profile content
├── runtime/             # runtime-only helper data
├── dotfiles/            # managed dotfiles state and metadata
│   ├── home/            # managed files and directories
│   └── links.json       # recorded managed paths
├── workspace/           # generated editor workspace files
├── backups/             # safety backups created during adopt/repair
└── meta.json            # install metadata
```

## Live vs managed paths

Live profile home example:

```text
profiles/omarchy/home/.config
```

Managed target example:

```text
profiles/omarchy/dotfiles/home/.config
```

If `.config` is managed, the live path is a symlink to the managed target.

## Config root

Custom manifest overrides live under:

```text
~/.config/isolated-desktops/profiles.d/
```

## User launchers and user sessions

Launchers are written to:

```text
~/.local/bin/id-start-<name>
```

User-scoped session files are written to:

```text
~/.local/share/xsessions/
~/.local/share/wayland-sessions/
```
