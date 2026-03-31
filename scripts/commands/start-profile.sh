#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/runtime.sh"
source "$ID_ROOT/scripts/lib/dotfiles.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool start <profile>"
safe_name "$name"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
[[ -f "$(profile_meta_file "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
if [[ -f "$(profile_links_file "$name")" ]]; then if [[ "${ID_AUTO_REPAIR_LINKS:-0}" == '1' ]]; then info "Auto-repairing managed links for: $name"; repair_recorded_links "$name"; else if ! audit_recorded_links "$name"; then warn "Managed links are out of sync for: $name"; warn "Run: idtool links repair $name"; fi; fi; fi
adapter="$(manifest_get "$name" adapter)"; source "$ID_ROOT/scripts/adapters/$adapter.sh"
start_command="$(manifest_get "$name" start_command)"
if declare -F adapter_start_command >/dev/null; then candidate="$(adapter_start_command "$name" || true)"; [[ -n "$candidate" ]] && start_command="$candidate"; fi
start_bin="$(first_command_word "$start_command")"
[[ -n "$start_bin" ]] || die_with_code "$EX_CONFIG" "Could not parse start command for $name: $start_command"
if [[ "$start_bin" == /* ]]; then [[ -x "$start_bin" ]] || die_with_code "$EX_UNAVAILABLE" "Start command missing: $start_bin"; else command -v "$start_bin" >/dev/null 2>&1 || die_with_code "$EX_UNAVAILABLE" "Start command missing from PATH: $start_bin"; fi
info "Starting profile $name"
metrics_log_local "start\t$name"
run_profile_command_managed "$name" "export ID_ROOT='$ID_ROOT'; source '$ID_ROOT/scripts/lib/common.sh'; source '$ID_ROOT/scripts/lib/paths.sh'; source '$ID_ROOT/scripts/lib/runtime.sh'; export_profile_env '$name'; exec $start_command"
