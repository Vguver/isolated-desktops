#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
need_cmd tar
archive="${1:-}"; name_override="${2:-}"
[[ -n "$archive" ]] || die_usage 'Usage: idtool import <archive.tar.gz> [profile-name]'
[[ -f "$archive" ]] || die_with_code "$EX_NOINPUT" "Archive not found: $archive"
enable_temp_cleanup_trap
require_free_space_mb "$ID_STATE_ROOT" "$ID_MIN_INSTALL_FREE_MB"
progress_step 1 4 "Extracting import archive"
tmpdir="$(create_temp_dir)"
tar -xzf "$archive" -C "$tmpdir"
mapfile -t imported_profiles < <(find "$tmpdir/profile" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
[[ ${#imported_profiles[@]} -ge 1 ]] || die_with_code "$EX_DATAERR" 'Archive does not contain any exported profiles'
source_name="${imported_profiles[0]}"; target_name="${name_override:-$source_name}"
safe_name "$target_name"
acquire_profile_lock "$target_name"
append_trap 'release_profile_lock' EXIT
[[ ! -d "$(profile_dir "$target_name")" ]] || die_with_code "$EX_TEMPFAIL" "Profile already exists: $target_name"
progress_step 2 4 "Importing profile files"
mkdir -p -- "$ID_PROFILES_ROOT" "$ID_CONFIG_ROOT/profiles.d"
cp -a -- "$tmpdir/profile/$source_name" "$(profile_dir "$target_name")"
if [[ -f "$tmpdir/meta/$source_name.json" ]]; then cp -a -- "$tmpdir/meta/$source_name.json" "$(profile_override_manifest "$target_name")"; fi
if [[ "$target_name" != "$source_name" && -f "$(profile_meta_file "$target_name")" ]]; then need_cmd python3; python3 - "$(profile_meta_file "$target_name")" "$target_name" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]); name = sys.argv[2]
data = json.loads(path.read_text(encoding='utf-8'))
data['name'] = name
path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
PY
fi
progress_step 3 4 "Verifying imported profile layout"
[[ -d "$(profile_home_dir "$target_name")" ]] || die_with_code "$EX_DATAERR" 'Imported archive is missing profile home'
[[ -d "$(profile_repo_dir "$target_name")" ]] || warn 'Imported archive does not include a repository checkout'
progress_step 4 4 "Import complete"
success "Imported profile: $target_name"
