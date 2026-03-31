#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
need_cmd tar
name="${1:-}"; out="${2:-}"
[[ -n "$name" ]] || die_usage 'Usage: idtool export <profile> [output.tar.gz]'
safe_name "$name"
[[ -d "$(profile_dir "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
enable_temp_cleanup_trap
mkdir -p -- "$ID_EXPORT_ROOT"
[[ -n "$out" ]] || out="$ID_EXPORT_ROOT/${name}-$(date +%Y%m%d-%H%M%S).tar.gz"
validate_plain_path "$out" 'export output path'
mkdir -p -- "$(dirname "$out")"
require_free_space_mb "$(dirname "$out")" "$ID_MIN_EXPORT_FREE_MB"
acquire_profile_lock "$name"
append_trap 'release_profile_lock' EXIT
progress_step 1 3 "Collecting profile export data for $name"
tmpdir="$(create_temp_dir)"
mkdir -p -- "$tmpdir/export/profile" "$tmpdir/export/meta"
cp -a -- "$(profile_dir "$name")" "$tmpdir/export/profile/$name"
override="$(profile_override_manifest "$name")"
[[ -f "$override" ]] && cp -a -- "$override" "$tmpdir/export/meta/${name}.json"
progress_step 2 3 "Creating archive $out"
( cd "$tmpdir/export" && tar -czf "$out" . )
progress_step 3 3 "Verifying archive"
tar -tzf "$out" >/dev/null || die_with_code "$EX_IOERR" "Export archive verification failed: $out"
success "Export archive created: $out"
