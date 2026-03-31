#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
usage() { cat <<'EOU'
Usage:
  idtool trash list
  idtool trash restore <trash-entry> [new-name]
  idtool trash purge [trash-entry]
EOU
}
restore_external_dotfiles_from_trash() {
  local entry_dir="$1" target_name="$2" extra_src extra_dst
  extra_src="$entry_dir/__external-dotfiles/profile"
  [[ -d "$extra_src" ]] || return 0
  [[ -n "$ID_DOTFILES_ROOT" ]] || return 0
  extra_dst="$(profile_external_dotfiles_profile_dir "$target_name")"
  mkdir -p -- "$(dirname "$extra_dst")"
  mv -- "$extra_src" "$extra_dst"
  rmdir "$entry_dir/__external-dotfiles" 2>/dev/null || true
}
sub="${1:-}"
case "$sub" in
  list) mkdir -p -- "$ID_TRASH_ROOT"; find "$ID_TRASH_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort ;;
  restore)
    entry="${2:-}"; new_name="${3:-}"; [[ -n "$entry" ]] || die_usage 'Usage: idtool trash restore <trash-entry> [new-name]'; src="$ID_TRASH_ROOT/$entry"; [[ -d "$src" ]] || die_with_code "$EX_NOINPUT" "Trash entry not found: $entry"; original="${entry#*-}"; target_name="${new_name:-$original}"; safe_name "$target_name"; acquire_profile_lock "$target_name"; append_trap 'release_profile_lock' EXIT; [[ ! -d "$(profile_dir "$target_name")" ]] || die_with_code "$EX_TEMPFAIL" "Profile already exists: $target_name"; mv -- "$src" "$(profile_dir "$target_name")"; restore_external_dotfiles_from_trash "$(profile_dir "$target_name")" "$target_name"; success "Restored trash entry to profile: $target_name" ;;
  purge)
    entry="${2:-}"; if [[ -n "$entry" ]]; then [[ -d "$ID_TRASH_ROOT/$entry" ]] || die_with_code "$EX_NOINPUT" "Trash entry not found: $entry"; rm -rf -- "$ID_TRASH_ROOT/$entry"; success "Purged trash entry: $entry"; else purge_old_trash; success "Purged trash entries older than $ID_TRASH_RETENTION_DAYS days"; fi ;;
  help|-h|--help|'') usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
