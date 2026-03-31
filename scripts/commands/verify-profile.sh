#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/session.sh"
source "$ID_ROOT/scripts/lib/dotfiles.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage 'Usage: idtool verify <profile>'
safe_name "$name"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
manifest_validate "$name"
need_cmd python3
issues=0
warnings=0
report_path="$(profile_health_file "$name")"
mkdir -p -- "$(dirname "$report_path")"
ok() { printf '[OK] %s\n' "$*"; }
issue() { printf '[WARN] %s\n' "$*"; issues=$((issues + 1)); }
note() { printf '[INFO] %s\n' "$*"; warnings=$((warnings + 1)); }
check_exists() { local label="$1" path="$2"; if [[ -e "$path" || -L "$path" ]]; then ok "$label: $path"; else issue "$label missing: $path"; fi; }
check_dir_permissions() { local label="$1" path="$2" perms; [[ -d "$path" ]] || { issue "$label missing: $path"; return 0; }; perms="$(stat -c '%a' "$path" 2>/dev/null || echo '')"; if [[ -z "$perms" ]]; then note "$label permissions unavailable: $path"; elif [[ "$perms" =~ ^[0-9]{3,4}$ ]]; then ok "$label permissions: $perms"; else issue "$label permissions invalid: $path ($perms)"; fi; }
check_shell_syntax() { local label="$1" path="$2"; [[ -f "$path" ]] || { issue "$label missing: $path"; return 0; }; if bash -n "$path" >/dev/null 2>&1; then ok "$label syntax: $path"; else issue "$label syntax failed: $path"; fi; }
check_session_file_format() { local scope="$1" path="$2"; [[ -f "$path" ]] || return 0; if grep -Eq '^\[Desktop Entry\]$' "$path" && grep -Eq '^Exec=' "$path" && grep -Eq '^Name=' "$path"; then ok "$scope session format: $path"; else issue "$scope session format invalid: $path"; fi; }
check_start_command() { local command_line="$1" first; first="$(first_command_word "$command_line")"; [[ -n "$first" ]] || { issue "Could not parse start command: $command_line"; return 0; }; if [[ "$first" == /* ]]; then [[ -x "$first" ]] && ok "start command available: $first" || issue "start command missing or not executable: $first"; else command -v "$first" >/dev/null 2>&1 && ok "start command available in PATH: $first" || issue "start command missing from PATH: $first"; fi; }
check_repo_health() { local repo="$1"; [[ -d "$repo" ]] || { issue "repository checkout missing: $repo"; return 0; }; if [[ ! -d "$repo/.git" ]]; then note "repository checkout is present but not a git repository: $repo"; return 0; fi; if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then ok 'repository git metadata: healthy'; else issue "repository git metadata is broken: $repo"; fi; }
check_broken_links_under() { local label="$1" root="$2"; local broken=(); [[ -d "$root" ]] || return 0; mapfile -t broken < <(find "$root" -xtype l 2>/dev/null | sort); if [[ ${#broken[@]} -eq 0 ]]; then ok "$label symlinks: no broken links"; else issue "$label has broken symlinks (${#broken[@]})"; printf '       %s\n' "${broken[@]}"; fi; }
printf 'Verifying profile: %s\n' "$name"
check_exists 'profile root' "$(profile_dir "$name")"
check_exists 'profile home' "$(profile_home_dir "$name")"
check_exists 'profile repo' "$(profile_repo_dir "$name")"
check_exists 'profile logs' "$(profile_logs_dir "$name")"
check_exists 'profile reports' "$(profile_reports_dir "$name")"
check_exists 'profile meta' "$(profile_meta_file "$name")"
check_dir_permissions 'profile root' "$(profile_dir "$name")"
check_dir_permissions 'profile home' "$(profile_home_dir "$name")"
check_dir_permissions 'profile runtime' "$(profile_runtime_dir "$name")"
check_exists 'home config dir' "$(profile_home_dir "$name")/.config"
check_exists 'home data dir' "$(profile_home_dir "$name")/.local/share"
check_exists 'home state dir' "$(profile_home_dir "$name")/.local/state"
check_exists 'home cache dir' "$(profile_home_dir "$name")/.cache"
launcher="$(launcher_path "$name")"
if [[ -x "$launcher" ]]; then ok "launcher present: $launcher"; check_shell_syntax 'launcher' "$launcher"; else issue "launcher missing or not executable: $launcher"; fi
stype="$(manifest_get "$name" session_type)"
user_session="$(session_target_dir "$name" user "$stype")/$(session_filename "$name")"
system_session="$(session_target_dir "$name" system "$stype")/$(session_filename "$name")"
if [[ -f "$user_session" || -f "$system_session" ]]; then ok 'session file present'; check_session_file_format 'user' "$user_session"; check_session_file_format 'system' "$system_session"; else note 'session file missing in both user and system scope'; fi
if [[ -f "$(profile_links_file "$name")" ]]; then if audit_recorded_links "$name"; then ok 'managed links are healthy'; else issue 'managed links have drift or broken targets'; fi; fi
check_broken_links_under 'profile home' "$(profile_home_dir "$name")"
check_broken_links_under 'managed dotfiles' "$(profile_dotfiles_root "$name")"
check_start_command "$(manifest_get "$name" start_command)"
check_repo_health "$(profile_repo_dir "$name")"
adapter="$(manifest_get "$name" adapter)"
if [[ -f "$ID_ROOT/scripts/adapters/$adapter.sh" ]]; then source "$ID_ROOT/scripts/adapters/$adapter.sh"; if declare -F adapter_verify >/dev/null; then if adapter_verify "$name"; then ok 'adapter verification passed'; else issue 'adapter verification failed'; fi; fi; fi
python3 - "$report_path" "$name" "$issues" "$warnings" "$launcher" "$user_session" "$system_session" <<'PY'
import json, sys
from datetime import datetime, timezone
path, name, issues, warnings, launcher, user_session, system_session = sys.argv[1:]
payload = {
    'profile': name,
    'generated_utc': datetime.now(timezone.utc).isoformat(),
    'issues': int(issues),
    'warnings': int(warnings),
    'launcher': launcher,
    'user_session': user_session,
    'system_session': system_session,
}
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY
if (( issues == 0 )); then success "Verification passed for: $name"; else warn "Verification found issues for: $name"; exit "$EX_TEMPFAIL"; fi
