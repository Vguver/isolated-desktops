#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/session.sh"
single="${1:-}"
need_cmd python3
printf '%-18s %-10s %-10s %-9s %-9s %-8s %-9s %s\n' 'PROFILE' 'INSTALLED' 'LAUNCHER' 'SESSION' 'LINKS' 'HEALTH' 'RISK' 'HOME'
printf '%-18s %-10s %-10s %-9s %-9s %-8s %-9s %s\n' '-------' '---------' '--------' '-------' '-----' '------' '----' '----'
emit_row() {
  local name="$1" installed='no' launcher='no' session='no' links='-' risk home stype user_session system_session health='unknown' health_file
  risk="$(manifest_get "$name" risk)"; home="$(profile_home_dir "$name")"; [[ -f "$(profile_meta_file "$name")" ]] && installed='yes'; [[ -x "$(launcher_path "$name")" ]] && launcher='yes'; stype="$(manifest_get "$name" session_type)"; user_session="$(session_target_dir "$name" user "$stype")/$(session_filename "$name")"; system_session="$(session_target_dir "$name" system "$stype")/$(session_filename "$name")"; [[ -f "$user_session" || -f "$system_session" ]] && session='yes'; [[ -f "$(profile_links_file "$name")" ]] && links='yes'; health_file="$(profile_health_file "$name")"
  if [[ -f "$health_file" ]]; then health="$(python3 - "$health_file" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    issues = int(json.loads(path.read_text(encoding='utf-8')).get('issues', 99))
except Exception:
    print('invalid')
    raise SystemExit(0)
print('ok' if issues == 0 else 'issues')
PY
)"; fi
  printf '%-18s %-10s %-10s %-9s %-9s %-8s %-9s %s\n' "$name" "$installed" "$launcher" "$session" "$links" "$health" "$risk" "$home"
}
if [[ -n "$single" ]]; then safe_name "$single"; manifest_exists "$single" || die_with_code "$EX_NOINPUT" "Unknown profile: $single"; emit_row "$single"; else while IFS= read -r name; do emit_row "$name"; done < <(manifest_list_names); fi
