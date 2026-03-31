#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"

cmd="${1:-help}"
case "$cmd" in
  create)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 create <name>"
    exec "$ID_ROOT/scripts/idtool.sh" launcher create "$name"
    ;;
  create-interactive)
    read -r -p 'Desktop name: ' name
    [[ -n "$name" ]] || die 'Empty name'
    exec "$ID_ROOT/scripts/idtool.sh" launcher create "$name"
    ;;
  list)
    printf '%-18s %s\n' 'NAME' 'LAUNCHER'
    printf '%-18s %s\n' '----' '--------'
    while IFS= read -r path; do
      base="$(basename "$path")"
      name="${base#id-start-}"
      printf '%-18s %s\n' "$name" "$path"
    done < <(find "$ID_USER_BIN" -maxdepth 1 -type f -name 'id-start-*' 2>/dev/null | sort)
    ;;
  show-path)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 show-path <name>"
    printf '%s\n' "$(launcher_path "$name")"
    ;;
  remove)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 remove <name>"
    path="$(launcher_path "$name")"
    [[ -e "$path" ]] || die "Launcher not found: $path"
    rm -f "$path"
    info "Removed launcher: $path"
    ;;
  help|-h|--help|'')
    cat <<'EOH'
Compatibility wrapper for the old desktop-launch.sh name.

Commands:
  create <name>
  create-interactive
  list
  show-path <name>
  remove <name>
EOH
    ;;
  *)
    die "Unknown command: $cmd"
    ;;
esac
