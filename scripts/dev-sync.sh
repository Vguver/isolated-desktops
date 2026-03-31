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
  snapshot)
    name="${2:-}"
    remote="${3:-}"
    branch="${4:-main}"
    push="${5:-1}"
    [[ -n "$name" ]] || die "Usage: $0 snapshot <name> [remote] [branch] [push]"
    exec "$ID_ROOT/scripts/idtool.sh" sync "$name" "$remote" "$branch" "$push"
    ;;
  snapshot-interactive|interactive)
    read -r -p 'Desktop name: ' name
    read -r -p 'Remote URL (blank for local only): ' remote
    read -r -p 'Branch [main]: ' branch
    branch="${branch:-main}"
    read -r -p 'Push to remote after commit? [Y/n]: ' answer
    push='1'
    [[ "$answer" =~ ^[Nn]$ ]] && push='0'
    exec "$ID_ROOT/scripts/idtool.sh" sync "$name" "$remote" "$branch" "$push"
    ;;
  init-only|init)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 init-only <name>"
    path="$(profile_snapshots_dir "$name")/git"
    mkdir -p "$path"
    if [[ ! -d "$path/.git" ]]; then git -C "$path" init; fi
    info "Snapshot repo ready: $path"
    ;;
  status)
    name="${2:-}"
    [[ -n "$name" ]] || die "Usage: $0 status <name>"
    path="$(profile_snapshots_dir "$name")/git"
    [[ -d "$path/.git" ]] || die "No snapshot repo for $name"
    git -C "$path" status
    ;;
  help|-h|--help|'')
    cat <<'EOH'
Compatibility wrapper for the old dev-sync.sh name.

Commands:
  snapshot <name> [remote] [branch] [push]
  snapshot-interactive
  init-only <name>
  status <name>
EOH
    ;;
  *)
    die "Unknown command: $cmd"
    ;;
esac
