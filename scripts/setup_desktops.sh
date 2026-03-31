#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/manifest.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/profile.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/runtime.sh"

cmd="${1:-help}"
case "$cmd" in
  create)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 create <name> [mode]"
    exec "$ID_ROOT/scripts/idtool.sh" install "$name" "${3:-}"
    ;;
  list)
    exec "$ID_ROOT/scripts/idtool.sh" list
    ;;
  show-path)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 show-path <name>"
    printf '%s\n' "$(profile_home_dir "$name")"
    ;;
  shell)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 shell <name>"
    exec "$ID_ROOT/scripts/idtool.sh" shell "$name"
    ;;
  remove)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 remove <name>"
    exec "$ID_ROOT/scripts/idtool.sh" remove "$name"
    ;;
  help|-h|--help|'')
    cat <<'EOH'
Compatibility wrapper for the old setup_desktops.sh name.

Commands:
  create <name> [mode]
  list
  show-path <name>
  shell <name>
  remove <name>
EOH
    ;;
  *)
    die "Unknown command: $cmd"
    ;;
esac
