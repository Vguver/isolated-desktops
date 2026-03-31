# Installation Guide

## Requirements

Required:

- Bash 4+
- Git
- Python 3

Recommended:

- `pacman` on Arch-based systems for package diff reports
- VS Code or VSCodium for the workspace-based editing flow
- a display manager such as SDDM, GDM, or LightDM
- `flock` for stronger per-profile locking

## Install the project

### Option 1: local clone

```bash
git clone https://github.com/Vguver/isolated-desktops.git
cd isolated-desktops
./install.sh --bootstrap
```

That installs the `idtool` wrapper into `~/.local/bin/idtool` for the current checkout.

### Option 2: remote bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/Vguver/isolated-desktops/main/install.sh | bash
```

That clones or updates the repo and then offers to install the wrapper.

If `~/.local/bin` is not already in your `PATH`, add it:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Recommended first workflow

### 1. List built-in profiles

```bash
idtool list
```

### 2. Analyze the profile first

```bash
idtool analyze omarchy
```

### 3. Install a profile

```bash
idtool install omarchy
```

### 4. Verify the profile

```bash
idtool verify omarchy
```

### 5. Prepare managed dotfiles targets

```bash
idtool links prepare omarchy
```

### 6. Create a launcher

```bash
idtool launcher create omarchy
```

### 7. Create a session entry

System scope:

```bash
idtool session create omarchy --scope system
```

User scope:

```bash
idtool session create omarchy --scope user
```

### 8. Create and open an editor workspace

```bash
idtool workspace create omarchy
idtool workspace open omarchy
```

### 9. Test the profile directly

```bash
idtool start omarchy
```

## Safety and recovery workflow

This version adds more defensive behavior around installs and removal.

### Rollback on install failure

Profile installs and updates now create a rollback snapshot before the adapter runs. If the install step fails, the profile is restored to the pre-install state.

### Trash instead of direct delete

By default:

```bash
idtool remove omarchy
```

moves the profile into the internal trash area instead of deleting it forever.

List trash:

```bash
idtool trash list
```

Restore a trashed profile:

```bash
idtool trash restore 20260101-120000-omarchy
```

Purge old trash entries:

```bash
idtool trash purge
```

Hard delete a profile immediately:

```bash
idtool remove omarchy --purge
```

## Managed dotfiles workflow

By default, managed dotfiles are stored inside each profile:

```text
~/.local/share/isolated-desktops/profiles/<name>/dotfiles/home/
```

Common actions:

Prepare default targets:

```bash
idtool links prepare omarchy
```

Link `.config` to the managed dotfiles target:

```bash
idtool links link omarchy .config
```

Adopt an existing `.config` into the managed target:

```bash
idtool links adopt omarchy .config
```

Repair broken or replaced symlinks:

```bash
idtool links repair omarchy
```

Show link status:

```bash
idtool links status omarchy
```

## Health checks and status dashboard

General dashboard:

```bash
idtool status
```

Profile verification:

```bash
idtool verify omarchy
```

Verification writes a small JSON report under:

```text
~/.local/share/isolated-desktops/profiles/omarchy/reports/verify.json
```

## Update flow

To pull the upstream repo again and re-run the adapter for an installed profile:

```bash
idtool update omarchy
```

By default, the last recorded install mode is reused.

## Export and import

Export a profile:

```bash
idtool export omarchy
```

Import it later:

```bash
idtool import ~/.local/share/isolated-desktops/exports/omarchy-20260101-120000.tar.gz
```

Import under a different profile name:

```bash
idtool import backup.tar.gz omarchy-copy
```

## Presets

Presets are plain text files with one profile name per line.

List presets:

```bash
idtool preset list
```

Show a preset:

```bash
idtool preset show hyprland-suite
```

Install all profiles from a preset:

```bash
idtool preset install hyprland-suite
```

## Custom desktop definitions

Built-in definitions live in `manifests/*.json`.

Custom definitions can be created under:

```text
~/.config/isolated-desktops/profiles.d/<name>.json
```

Compatibility helper:

```bash
./scripts/repos-desktops.sh add my-desktop https://github.com/user/project.git
```

That creates a custom manifest stub using the generic adapter. Review it before you trust it.

## State layout

Installed state lives under:

```text
~/.local/share/isolated-desktops/profiles/<name>/
```

Important subdirectories:

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

## Optional local metrics log

This project does **not** send telemetry anywhere by default.

If you want a local event log for your own debugging, you can enable it:

```bash
export ID_ENABLE_LOCAL_METRICS=1
```

That writes local events under:

```text
~/.local/share/isolated-desktops/metrics/events.log
```

## Validation scripts

Lightweight checks live in `tests/` and can be run with:

```bash
./tests/run-all.sh
```

## Strong warning

This project isolates **session homes**, not the full system.

Packages, services, display managers, and global system files can still be changed by upstream installers.


## Optional shell setup

```bash
idtool completion install
```

To update the local project checkout later:

```bash
idtool self-update
```
