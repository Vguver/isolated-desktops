#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage 'Usage: idtool update <profile> [mode]'
safe_name "$name"
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
[[ -f "$(profile_meta_file "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
need_cmd python3
mode="${2:-$(python3 - "$(profile_meta_file "$name")" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
print(json.loads(path.read_text(encoding='utf-8')).get('last_install_mode', ''))
PY
)}"
mode="${mode:-$(manifest_get "$name" default_mode)}"
progress_step 1 2 "Updating profile: $name"
"$ID_ROOT/scripts/commands/install-profile.sh" "$name" "$mode"
progress_step 2 2 "Running post-update verification"
if "$ID_ROOT/scripts/commands/verify-profile.sh" "$name"; then progress_done "Update completed and verification passed for: $name"; else warn "Update completed, but verification found issues for: $name"; fi
