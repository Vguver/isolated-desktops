#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
preset_dir="$ID_ROOT/presets"
preset_path() { printf '%s/%s.txt\n' "$preset_dir" "$1"; }
usage() { cat <<'EOU'
Usage:
  idtool preset list
  idtool preset show <preset>
  idtool preset install <preset> [mode]
EOU
}
sub="${1:-}"
case "$sub" in
  list) find "$preset_dir" -maxdepth 1 -type f -name '*.txt' -printf '%f\n' 2>/dev/null | sed 's/\.txt$//' | sort ;;
  show) preset="${2:-}"; [[ -n "$preset" ]] || die_usage 'Usage: idtool preset show <preset>'; [[ -f "$(preset_path "$preset")" ]] || die_with_code "$EX_NOINPUT" "Preset not found: $preset"; cat "$(preset_path "$preset")" ;;
  install) preset="${2:-}"; mode="${3:-}"; [[ -n "$preset" ]] || die_usage 'Usage: idtool preset install <preset> [mode]'; path="$(preset_path "$preset")"; [[ -f "$path" ]] || die_with_code "$EX_NOINPUT" "Preset not found: $preset"; while IFS= read -r name; do name="${name%%#*}"; name="$(printf '%s' "$name" | xargs)"; [[ -n "$name" ]] || continue; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Preset references unknown profile: $name"; info "Installing preset item: $name"; if [[ -n "$mode" ]]; then "$ID_ROOT/scripts/commands/install-profile.sh" "$name" "$mode"; else "$ID_ROOT/scripts/commands/install-profile.sh" "$name"; fi; done < "$path" ;;
  help|-h|--help|'') usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
