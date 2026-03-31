# Architecture

The project is built around these layers:

1. **manifests**
   - JSON definitions for each supported desktop project
2. **adapters**
   - project-specific install and startup behavior
3. **profiles**
   - the real per-session state on disk
4. **managed dotfiles**
   - optional symlink-managed paths such as `.config` or `.local/bin`
5. **editor workspaces**
   - generated `.code-workspace` files for profile editing
6. **safety controls**
   - locks, rollback snapshots, backups, verify reports, and trash-based removal

## Core idea

One Linux user can log into multiple desktop sessions.

Each session points to a different profile home:

```text
~/.local/share/isolated-desktops/profiles/<name>/home
```

That lets the same installed program read different config files depending on the chosen session.

## Important boundary

This architecture isolates **profile state**, not the whole operating system.

Packages, services, `/etc`, `/usr`, and display-manager behavior remain shared unless an upstream project behaves differently.

## Why adapters exist

Third-party desktop projects do not install the same way.

A single generic installer runner was not enough, so the current design uses one adapter per upstream project.

## Managed dotfiles

Managed dotfiles are tracked separately from the live profile home.

The default managed root is:

```text
~/.local/share/isolated-desktops/profiles/<name>/dotfiles/home
```

A small JSON file records which home-relative paths are actively managed.

That enables:

- link status
- link repair
- safer editor workflows
- snapshotting the managed parts of the profile
- backup before adoption

## Safety model

### Locks

Install, update, remove, link-adopt, and other profile-mutating operations use a per-profile lock.

If `flock` is available, it is used. Otherwise the project falls back to a lock-directory strategy.

### Rollback snapshots

Before a profile install or update runs its adapter, the project saves a rollback snapshot of the profile tree. If the install step fails, the profile is restored.

### Trash and restore

Profile removal does not hard-delete by default. Instead, the full profile tree is moved into the internal trash area under the state root.

### Verification

`idtool verify <profile>` checks the profile layout, launcher, session file presence, managed links, and start command availability.

## Editor workspaces

Each profile can have a generated editor workspace file under:

```text
~/.local/share/isolated-desktops/profiles/<name>/workspace/<name>.code-workspace
```

The workspace includes the live profile home, repo checkout, managed dotfiles, logs, reports, and snapshots.
