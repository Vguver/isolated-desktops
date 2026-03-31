#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/dotfiles.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
usage() {
  cat <<'EOU'
Usage:
  idtool links prepare <profile> [relative-home-path...]
  idtool links link <profile> [relative-home-path...]
  idtool links adopt <profile> [relative-home-path...]
  idtool links repair <profile>
  idtool links status [profile]
EOU
}
ID_LINKS_ROLLBACK_NAME=''
ID_LINKS_ROLLBACK_SNAPSHOT=''
ID_LINKS_FAILED=1
cleanup_links_action() {
  local status=$?
  if [[ -n "$ID_LINKS_ROLLBACK_NAME" && -n "$ID_LINKS_ROLLBACK_SNAPSHOT" ]] && (( status != 0 || ID_LINKS_FAILED != 0 )); then rollback_profile_from_snapshot "$ID_LINKS_ROLLBACK_NAME" "$ID_LINKS_ROLLBACK_SNAPSHOT" || true; fi
}
apply_with_rollback() {
  local name="$1" action="$2"; shift 2 || true; local rel
  ID_LINKS_ROLLBACK_NAME="$name"; ID_LINKS_ROLLBACK_SNAPSHOT="$(snapshot_profile_for_rollback "$name")"; ID_LINKS_FAILED=1; append_trap 'cleanup_links_action' EXIT
  case "$action" in
    link) for rel in "$@"; do create_link_for_rel "$name" "$rel"; success "Linked $name:$rel"; done ;;
    adopt) for rel in "$@"; do adopt_rel "$name" "$rel"; success "Adopted $name:$rel"; done ;;
    repair) repair_recorded_links "$name" ;;
    *) die_usage "Unknown links action: $action" ;;
  esac
  ID_LINKS_FAILED=0
}
sub="${1:-}"
case "$sub" in
  prepare)
    name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool links prepare <profile> [relative-home-path...]'; safe_name "$name"; require_project_version; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"; acquire_profile_lock "$name"; append_trap 'release_profile_lock' EXIT; ensure_profile_layout "$name"; shift 2 || true; prepare_links "$name" "$@"; success "Managed dotfiles targets ready for: $name"; info "Dotfiles root: $(profile_dotfiles_root "$name")" ;;
  link)
    name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool links link <profile> [relative-home-path...]'; safe_name "$name"; require_project_version; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"; acquire_profile_lock "$name"; append_trap 'release_profile_lock' EXIT; ensure_profile_layout "$name"; shift 2 || true; if [[ $# -eq 0 ]]; then mapfile -t rels < <(links_default_paths); else rels=("$@"); fi; apply_with_rollback "$name" link "${rels[@]}" ;;
  adopt)
    name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool links adopt <profile> [relative-home-path...]'; safe_name "$name"; require_project_version; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"; acquire_profile_lock "$name"; append_trap 'release_profile_lock' EXIT; ensure_profile_layout "$name"; shift 2 || true; if [[ $# -eq 0 ]]; then mapfile -t rels < <(collect_default_existing_paths "$name"); if [[ ${#rels[@]} -eq 0 ]]; then mapfile -t rels < <(links_default_paths); fi; else rels=("$@"); fi; apply_with_rollback "$name" adopt "${rels[@]}" ;;
  repair)
    name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool links repair <profile>'; safe_name "$name"; acquire_profile_lock "$name"; append_trap 'release_profile_lock' EXIT; ensure_profile_layout "$name"; apply_with_rollback "$name" repair ;;
  status) show_links_status "${2:-}" ;;
  help|-h|--help|'') usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
