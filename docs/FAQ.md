# FAQ

## Is this full isolation like a virtual machine?

No. This project isolates profile-level user state, not the full operating system.

## Why keep the name `isolated-desktops` if it is not a VM?

Because it is short and memorable. The docs now describe the behavior more precisely as session-profile isolation.

## Can third-party installers still touch the host system?

Yes. If an upstream installer installs packages, edits `/etc`, enables services, or writes into `/usr/share`, those changes are host-wide.

## Why do I need adapters?

Because different upstream projects expect different repository layouts, working directories, and install commands.

## Why did profile removal move my files to trash instead of deleting them?

That is the default safety behavior in v1.5.0. Use `idtool remove <profile> --purge` only if you want an immediate hard delete.

## Can I edit everything from VS Code or VSCodium?

Yes. Use `idtool workspace create <profile>` and `idtool workspace open <profile>`.

## Does `links adopt` make backups?

Yes. The project now creates a timestamped backup before moving a managed path.

## Is telemetry enabled?

No remote telemetry is enabled. Optional local metrics logging is available only if you explicitly set `ID_ENABLE_LOCAL_METRICS=1`.
