# Changelog

## 1.6.0

- fixed rollback snapshot logging so command-substitution callers do not receive mixed log output
- fixed `idtool remove` option parsing for `--purge` and `--yes`
- hardened verification with repo integrity checks, broken-link scans, permission checks, and better start-command parsing
- added `idtool completion` and installable Bash completion support
- added `idtool self-update` for git-based project checkouts
- added host cleanup helper generation to install reports when package, service, or tracked system drift is detected
- expanded automated test coverage with resilience and lifecycle tests

## 1.5.0

- hardened fallback locking with stale-lock recovery
- moved rollback snapshots outside the live profile tree
- made first repository clone atomic by cloning into a temporary checkout first
- strengthened managed-dotfiles adoption with staged copies, backups, and restore-on-failure
- expanded default managed paths and transactional link operations
- improved verification checks for launcher syntax, session format, permissions, and command availability
- improved update flow by chaining post-update verification
- improved export/import validation and archive verification
- improved remove and trash flows for custom manifests and external dotfiles roots
- improved smoke coverage using a local file-based test repository

## 1.4.0

- added per-profile locking to reduce concurrent-install corruption
- added rollback snapshots before install and update operations
- added free-space checks before install and export operations
- added safer managed-dotfiles adoption with automatic backups
- changed profile removal to use internal trash by default
- added trash restore and purge commands
- added profile health checks with `idtool verify`
- added status dashboard with `idtool status`
- added `idtool update` for installed profiles
- added profile export and import commands
- added preset support for multi-profile installs
- added semantic exit codes and version checks
- added optional local metrics logging for personal debugging
- improved session startup supervision and launcher/session management
- expanded documentation and added troubleshooting, FAQ, and contribution guides

## 1.3.0

- clarified the project concept as **session-profile isolation** instead of full system isolation
- kept the repository name `isolated-desktops` but made the docs much more precise
- added managed dotfiles support inside each profile by default
- added recorded link state and `repair` support for broken or replaced symlinks
- added real VS Code / VSCodium workspace generation per profile
- expanded `idtool open` to support `dotfiles` and `workspace`
- added `idtool links ...` commands
- added `idtool workspace ...` commands
- improved `dev-open.sh` to open managed dotfiles or a generated workspace
- improved snapshots so they sync recorded managed paths, not only `.config`
- changed internal file-copy helpers so normal copy and mirror/sync are separate operations
- updated documentation so the project layout, workflow, and warnings match the real behavior

## 1.2.0

- cleaned the repository for `main`
- moved migration notes under `docs/`
- renamed lightweight test scripts from `.bats` to `.sh`
- normalized permissions and documentation layout

## 1.1.0

- stabilized the v1 line
- fixed the launcher path and bootstrap behavior
- improved snapshot Git setup
- improved non-interactive bootstrap handling
