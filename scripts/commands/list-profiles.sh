#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
if [[ "${1:-}" == '--names-only' ]]; then manifest_list_names; exit 0; fi
printf '%-18s %-9s %-8s %-12s %s\n' 'NAME' 'RISK' 'SESSION' 'INSTALLED' 'PROFILE_HOME'
printf '%-18s %-9s %-8s %-12s %s\n' '----' '----' '-------' '---------' '------------'
while IFS= read -r name; do installed='no'; [[ -f "$(profile_meta_file "$name")" ]] && installed='yes'; printf '%-18s %-9s %-8s %-12s %s\n' "$name" "$(manifest_get "$name" risk)" "$(manifest_get "$name" session_type)" "$installed" "$(profile_home_dir "$name")"; done < <(manifest_list_names)
