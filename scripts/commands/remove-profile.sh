#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/session.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool remove <profile> [--purge] [--yes]"
safe_name "$name"
purge='0'
assume_yes='0'
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) purge='1'; shift ;;
    --yes|-y) assume_yes='1'; shift ;;
    *) die_usage "Unknown option: $1" ;;
  esac
done
[[ -d "$(profile_dir "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
acquire_profile_lock "$name"
append_trap 'release_profile_lock' EXIT
if [[ "$assume_yes" != '1' ]]; then confirm "Remove profile '$name'?" || die 'Cancelled'; fi
remove_system_sessions() {
  local path
  for path in "/usr/share/xsessions/$(session_filename "$name")" "/usr/share/wayland-sessions/$(session_filename "$name")"; do
    if [[ -f "$path" ]]; then
      sudo_remove_path "$path"
      info "Removed system session file: $path"
    fi
  done
}
if [[ "$purge" == '1' ]]; then
  progress_step 1 3 "Deleting profile directory"
  rm -rf -- "$(profile_dir "$name")"
  progress_step 2 3 "Removing launchers, sessions, and overrides"
  remove_profile_supporting_files "$name"
  progress_step 3 3 "Removing system session files if present"
  remove_system_sessions
  success "Deleted profile permanently: $name"
else
  progress_step 1 2 "Moving profile to trash"
  trash_path="$(move_profile_to_trash "$name")"
  progress_step 2 2 "Removing launchers, sessions, and overrides"
  remove_profile_supporting_files "$name"
  remove_system_sessions
  success "Moved profile to trash: $trash_path"
fi
purge_old_trash
info "Removed profile hooks for: $name"
