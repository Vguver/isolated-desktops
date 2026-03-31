#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/session.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
cmd="${1:-help}"
case "$cmd" in
  create-x) name="${2:-}"; [[ -n "$name" ]] || die_usage "Usage: $0 create-x <name>"; exec "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type x11 ;;
  create-wayland) name="${2:-}"; [[ -n "$name" ]] || die_usage "Usage: $0 create-wayland <name>"; exec "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type wayland ;;
  create-interactive)
    prompt_read 'Desktop name: ' name || die 'Empty name'
    echo '1) X11'; echo '2) Wayland'; echo '3) Both'
    prompt_read 'Choice [1-3]: ' choice || die 'Invalid choice'
    case "$choice" in 1) exec "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type x11 ;; 2) exec "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type wayland ;; 3) "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type x11; exec "$ID_ROOT/scripts/idtool.sh" session create "$name" --scope system --type wayland ;; *) die 'Invalid choice' ;; esac
    ;;
  list)
    printf '%-18s %-8s %-8s %-8s %-8s\n' 'NAME' 'SYS-X' 'SYS-W' 'USR-X' 'USR-W'
    printf '%-18s %-8s %-8s %-8s %-8s\n' '----' '-----' '-----' '-----' '-----'
    while IFS= read -r name; do sx='-'; sw='-'; ux='-'; uw='-'; [[ -f "$(session_path_for "$name" system x11)" ]] && sx='yes'; [[ -f "$(session_path_for "$name" system wayland)" ]] && sw='yes'; [[ -f "$(session_path_for "$name" user x11)" ]] && ux='yes'; [[ -f "$(session_path_for "$name" user wayland)" ]] && uw='yes'; printf '%-18s %-8s %-8s %-8s %-8s\n' "$name" "$sx" "$sw" "$ux" "$uw"; done < <(manifest_list_names)
    ;;
  remove)
    name="${2:-}"; type="${3:-both}"
    [[ -n "$name" ]] || die_usage "Usage: $0 remove <name> [x|wayland|both]"
    case "$type" in x|x11|xorg) path="$(session_path_for "$name" system x11)"; [[ -f "$path" ]] && sudo_remove_path "$path" ;; w|wayland) path="$(session_path_for "$name" system wayland)"; [[ -f "$path" ]] && sudo_remove_path "$path" ;; both) for path in "$(session_path_for "$name" system x11)" "$(session_path_for "$name" system wayland)"; do [[ -f "$path" ]] && sudo_remove_path "$path"; done ;; *) die_usage 'Type must be x, wayland, or both' ;; esac
    info "Removed session files for: $name"
    ;;
  help|-h|--help|'') cat <<'EOH'
Compatibility wrapper for the old desktop-sessions.sh name.
Commands:
  create-x <name>
  create-wayland <name>
  create-interactive
  list
  remove <name> [x|wayland|both]
EOH
    ;;
  *) die "Unknown command: $cmd" ;;
esac
