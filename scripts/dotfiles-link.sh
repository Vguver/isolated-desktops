#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"

cmd="${1:-help}"
case "$cmd" in
  prepare)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 prepare <name> [relative-home-path...]"
    shift 2 || true
    exec "$ID_ROOT/scripts/idtool.sh" links prepare "$name" "$@"
    ;;
  link-config)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 link-config <name>"
    exec "$ID_ROOT/scripts/idtool.sh" links link "$name" .config
    ;;
  adopt-config)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 adopt-config <name>"
    exec "$ID_ROOT/scripts/idtool.sh" links adopt "$name" .config
    ;;
  link)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 link <name> [relative-home-path...]"
    shift 2 || true
    exec "$ID_ROOT/scripts/idtool.sh" links link "$name" "$@"
    ;;
  adopt)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 adopt <name> [relative-home-path...]"
    shift 2 || true
    exec "$ID_ROOT/scripts/idtool.sh" links adopt "$name" "$@"
    ;;
  repair)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 repair <name>"
    exec "$ID_ROOT/scripts/idtool.sh" links repair "$name"
    ;;
  status)
    exec "$ID_ROOT/scripts/idtool.sh" links status "${2:-}"
    ;;
  help|-h|--help|'')
    cat <<'EOH'
Compatibility wrapper for the old dotfiles-link.sh name.

Commands:
  prepare <name> [relative-home-path...]
  link-config <name>
  adopt-config <name>
  link <name> [relative-home-path...]
  adopt <name> [relative-home-path...]
  repair <name>
  status [name]
EOH
    ;;
  *)
    die "Unknown command: $cmd"
    ;;
esac
