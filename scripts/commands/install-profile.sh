#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/repo.sh"
source "$ID_ROOT/scripts/lib/report.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool install <profile> [mode]"
safe_name "$name"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
manifest_validate "$name"
mode="${2:-$(manifest_get "$name" default_mode)}"
manifest_supports_mode "$name" "$mode" || die_usage "Mode not supported for $name: $mode"
adapter="$(manifest_get "$name" adapter)"
[[ -f "$ID_ROOT/scripts/adapters/$adapter.sh" ]] || die_config "Missing adapter script: $adapter"
source "$ID_ROOT/scripts/adapters/$adapter.sh"
enable_temp_cleanup_trap
require_free_space_mb "$HOME" "$ID_MIN_INSTALL_FREE_MB"
acquire_profile_lock "$name"
backup_root="$(snapshot_profile_for_rollback "$name")"
install_failed=1
report_started=0
cleanup_install() {
  local status=$?
  if (( report_started == 1 )); then report_finish "$name" || true; fi
  release_profile_lock || true
  if (( status != 0 || install_failed != 0 )); then rollback_profile_from_snapshot "$name" "$backup_root" || true; fi
}
append_trap 'cleanup_install' EXIT
progress_step 1 5 "Preparing profile layout for $name"
ensure_profile_layout "$name"
progress_step 2 5 "Preparing repository checkout for $name"
repo_clone_or_update "$name"
progress_step 3 5 "Opening install report"
report_start "$name"
report_started=1
report_log "Installing profile: $name"
report_log "Mode: $mode"
report_log "Adapter: $adapter"
report_log "Project version: $ID_PROJECT_VERSION"
if [[ "${ID_TRACK_SYSTEM:-0}" == '1' ]]; then report_log 'System change tracking is enabled. Host-level changes may be reported but not automatically rolled back.'; fi
progress_step 4 5 "Running adapter install flow"
if declare -F adapter_prepare_layout >/dev/null; then adapter_prepare_layout "$name" "$mode"; fi
adapter_install "$name" "$mode"
if declare -F adapter_post_install >/dev/null; then adapter_post_install "$name" "$mode"; fi
progress_step 5 5 "Writing profile metadata"
write_profile_meta "$name" "$mode"
install_failed=0
metrics_log_local "install\t$name\t$mode\tsuccess"
progress_done "Profile installed: $name"
info "Verify with: idtool verify $name"
info "Create launcher with: idtool launcher create $name"
info "Create session with: idtool session create $name --scope system"
