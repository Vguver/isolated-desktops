#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"

cmd="${1:-help}"
case "$cmd" in
  real-home)
    open_in_editor "$HOME"
    ;;
  fake-home)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 fake-home <name>"
    exec "$ID_ROOT/scripts/idtool.sh" open home "$name"
    ;;
  dotfiles)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 dotfiles <name>"
    exec "$ID_ROOT/scripts/idtool.sh" open dotfiles "$name"
    ;;
  workspace)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 workspace <name>"
    exec "$ID_ROOT/scripts/idtool.sh" workspace open "$name"
    ;;
  project|root)
    open_in_editor "$ID_ROOT"
    ;;
  interactive)
    echo '1) Real HOME'
    echo '2) Fake HOME'
    echo '3) Managed dotfiles'
    echo '4) Editor workspace'
    echo '5) Project root'
    read -r -p 'Choice [1-5]: ' choice
    case "$choice" in
      1) exec "$0" real-home ;;
      2) read -r -p 'Profile name: ' name; exec "$0" fake-home "$name" ;;
      3) read -r -p 'Profile name: ' name; exec "$0" dotfiles "$name" ;;
      4) read -r -p 'Profile name: ' name; exec "$0" workspace "$name" ;;
      5) exec "$0" project ;;
      *) die 'Invalid choice' ;;
    esac
    ;;
  list)
    exec "$ID_ROOT/scripts/idtool.sh" list
    ;;
  help|-h|--help|'')
    cat <<'EOH'
Compatibility wrapper for the old dev-open.sh name.

Commands:
  real-home
  fake-home <name>
  dotfiles <name>
  workspace <name>
  project
  interactive
  list
EOH
    ;;
  *)
    die "Unknown command: $cmd"
    ;;
esac
