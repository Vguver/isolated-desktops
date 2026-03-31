# Migration from v2 to the adapter based layout

## Old files to new equivalents

| Old file | New primary equivalent |
|---|---|
| `install.sh` | `install.sh` + `scripts/idtool.sh` |
| `scripts/setup_desktops.sh` | `scripts/commands/install-profile.sh` |
| `scripts/desktop-launch.sh` | `scripts/commands/create-launcher.sh` |
| `scripts/desktop-sessions.sh` | `scripts/commands/create-session.sh` |
| `scripts/repos-desktops.sh` | `manifests/*.json` + `~/.config/isolated-desktops/profiles.d/` |
| `scripts/dev-open.sh` | `scripts/commands/open-profile.sh` |
| `scripts/dev-sync.sh` | `scripts/commands/sync-profile.sh` |
| `scripts/dotfiles-link.sh` | optional compatibility wrapper |

## Directory layout change

Old profile locations:

```text
~/.omarchy
~/.jakoolit
```

New profile locations:

```text
~/.local/share/isolated-desktops/profiles/omarchy/home
~/.local/share/isolated-desktops/profiles/jakoolit/home
```

## Why the change

The old repo had two big structural problems:

1. it relied on a generic installer detector
2. it loaded extra repo definitions by sourcing Bash from a user config file

The new layout fixes both:

- adapters are explicit per upstream project
- manifests are JSON files, not sourced Bash

## Recommended migration order

1. replace the repo files
2. run `./install.sh --bootstrap`
3. run `idtool list`
4. run `idtool analyze <profile>`
5. reinstall profiles one by one with the new layout
6. recreate launchers and session files

If you want, you can manually copy selected config folders from the old fake homes into the new profile homes.
