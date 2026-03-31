#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
if [[ "${1:-}" == '--verbose' || "${1:-}" == '-v' ]]; then export ID_VERBOSE=1; shift; fi
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/menu.sh"
require_project_version
usage() {
  cat <<'EOU'
Usage:
  idtool
  idtool [--verbose]
  idtool bootstrap
  idtool list [--names-only]
  idtool status [profile]
  idtool analyze <profile> [mode]
  idtool install <profile> [mode]
  idtool update <profile> [mode]
  idtool verify <profile>
  idtool start <profile>
  idtool shell <profile>
  idtool launcher create <profile>
  idtool session create <profile> [--scope user|system] [--type x11|wayland]
  idtool open <home|repo|logs|reports|dotfiles|workspace> <profile>
  idtool links <prepare|link|adopt|repair|status> ...
  idtool workspace <create|open|status> <profile>
  idtool sync <profile> [remote] [branch] [push]
  idtool export <profile> [output.tar.gz]
  idtool import <archive.tar.gz> [profile-name]
  idtool preset <list|show|install> ...
  idtool trash <list|restore|purge> ...
  idtool completion <show|install> [destination-file]
  idtool self-update [--force]
  idtool extract <profile> <module-or-path> [destination]
  idtool compare <profile-a> <profile-b>
  idtool remove <profile> [--purge] [--yes]
EOU
}
cmd="${1:-}"
if [[ -z "$cmd" ]]; then show_main_menu; exit 0; fi
shift || true
case "$cmd" in
  bootstrap) exec "$ID_ROOT/scripts/commands/bootstrap.sh" "$@" ;;
  list) exec "$ID_ROOT/scripts/commands/list-profiles.sh" "$@" ;;
  status) exec "$ID_ROOT/scripts/commands/status-profiles.sh" "$@" ;;
  analyze) exec "$ID_ROOT/scripts/commands/analyze.sh" "$@" ;;
  install) exec "$ID_ROOT/scripts/commands/install-profile.sh" "$@" ;;
  update) exec "$ID_ROOT/scripts/commands/update-profile.sh" "$@" ;;
  verify) exec "$ID_ROOT/scripts/commands/verify-profile.sh" "$@" ;;
  start) exec "$ID_ROOT/scripts/commands/start-profile.sh" "$@" ;;
  shell) exec "$ID_ROOT/scripts/commands/shell-profile.sh" "$@" ;;
  launcher) sub="${1:-}"; shift || true; case "$sub" in create) exec "$ID_ROOT/scripts/commands/create-launcher.sh" "$@" ;; *) usage; exit "$EX_USAGE" ;; esac ;;
  session) sub="${1:-}"; shift || true; case "$sub" in create) exec "$ID_ROOT/scripts/commands/create-session.sh" "$@" ;; *) usage; exit "$EX_USAGE" ;; esac ;;
  open) exec "$ID_ROOT/scripts/commands/open-profile.sh" "$@" ;;
  links) exec "$ID_ROOT/scripts/commands/links-profile.sh" "$@" ;;
  workspace) exec "$ID_ROOT/scripts/commands/workspace-profile.sh" "$@" ;;
  sync) exec "$ID_ROOT/scripts/commands/sync-profile.sh" "$@" ;;
  export) exec "$ID_ROOT/scripts/commands/export-profile.sh" "$@" ;;
  import) exec "$ID_ROOT/scripts/commands/import-profile.sh" "$@" ;;
  preset) exec "$ID_ROOT/scripts/commands/preset-profile.sh" "$@" ;;
  trash) exec "$ID_ROOT/scripts/commands/trash-profile.sh" "$@" ;;
  completion) exec "$ID_ROOT/scripts/commands/completion.sh" "$@" ;;
  self-update) exec "$ID_ROOT/scripts/commands/self-update.sh" "$@" ;;
  extract) exec "$ID_ROOT/scripts/commands/extract-module.sh" "$@" ;;
  compare) exec "$ID_ROOT/scripts/commands/compare-profiles.sh" "$@" ;;
  remove) exec "$ID_ROOT/scripts/commands/remove-profile.sh" "$@" ;;
  help|-h|--help) usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
