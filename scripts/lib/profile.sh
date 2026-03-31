#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
ensure_profile_layout() {
  local name="$1"
  safe_name "$name"
  mkdirp \
    "$ID_PROFILES_ROOT" \
    "$ID_TRASH_ROOT" \
    "$ID_EXPORT_ROOT" \
    "$ID_TMP_ROOT" \
    "$(profile_transactions_root "$name")" \
    "$(profile_home_dir "$name")" \
    "$(profile_repo_dir "$name")" \
    "$(profile_logs_dir "$name")" \
    "$(profile_reports_dir "$name")" \
    "$(profile_snapshots_dir "$name")" \
    "$(profile_runtime_dir "$name")" \
    "$(profile_link_state_dir "$name")" \
    "$(profile_workspace_dir "$name")" \
    "$(profile_backups_dir "$name")" \
    "$(profile_home_dir "$name")/.config" \
    "$(profile_home_dir "$name")/.cache" \
    "$(profile_home_dir "$name")/.local/share" \
    "$(profile_home_dir "$name")/.local/state"
  chmod 700 "$(profile_dir "$name")" "$(profile_home_dir "$name")" "$(profile_runtime_dir "$name")" 2>/dev/null || true
}
write_profile_meta() {
  local name="$1" mode="$2" meta
  need_cmd python3
  meta="$(profile_meta_file "$name")"
  python3 - "$meta" "$name" "$mode" "$(manifest_get "$name" display_name)" "$(manifest_get "$name" adapter)" "$(manifest_get "$name" ref)" "$(manifest_get "$name" session_type)" "$ID_PROJECT_VERSION" <<'PY'
import json, sys
from datetime import datetime, timezone
path, name, mode, display_name, adapter, ref, session_type, version = sys.argv[1:]
payload = {
    'name': name,
    'display_name': display_name,
    'adapter': adapter,
    'ref': ref,
    'session_type': session_type,
    'last_install_mode': mode,
    'project_version': version,
    'last_install_utc': datetime.now(timezone.utc).isoformat(),
}
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY
}
profile_exists() { local name="$1"; [[ -d "$(profile_dir "$name")" ]]; }
_external_dotfiles_exists() {
  local name="$1"
  [[ -n "$ID_DOTFILES_ROOT" ]] || return 1
  [[ -d "$(profile_external_dotfiles_profile_dir "$name")" ]]
}
snapshot_profile_for_rollback() {
  local name="$1" backup_root tx_root
  tx_root="$(profile_transactions_root "$name")"
  mkdir -p -- "$tx_root"
  rotate_named_dirs "$tx_root" 'install-rollback-*' "$ID_BACKUP_KEEP_COUNT"
  backup_root="$tx_root/install-rollback-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p -- "$backup_root"
  if profile_exists "$name" && [[ -f "$(profile_meta_file "$name")" ]]; then
    info "Creating rollback snapshot for existing profile: $name" >&2
    mkdir -p -- "$backup_root/profile"
    copy_tree "$(profile_dir "$name")" "$backup_root/profile"
    if _external_dotfiles_exists "$name"; then
      mkdir -p -- "$backup_root/external-dotfiles"
      copy_tree "$(profile_external_dotfiles_profile_dir "$name")" "$backup_root/external-dotfiles"
    fi
  else
    printf 'new-install\n' > "$backup_root/state"
  fi
  printf '%s\n' "$backup_root"
}
rollback_profile_from_snapshot() {
  local name="$1" backup_root="$2"
  [[ -d "$backup_root" ]] || return 0
  warn "Rolling back profile state for: $name"
  if [[ -d "$backup_root/profile" ]]; then
    rm -rf -- "$(profile_dir "$name")"
    mkdir -p -- "$(dirname "$(profile_dir "$name")")"
    cp -a -- "$backup_root/profile" "$(profile_dir "$name")"
  else
    rm -rf -- "$(profile_dir "$name")"
  fi
  if [[ -n "$ID_DOTFILES_ROOT" ]]; then
    if [[ -d "$backup_root/external-dotfiles" ]]; then
      rm -rf -- "$(profile_external_dotfiles_profile_dir "$name")"
      mkdir -p -- "$(dirname "$(profile_external_dotfiles_profile_dir "$name")")"
      cp -a -- "$backup_root/external-dotfiles" "$(profile_external_dotfiles_profile_dir "$name")"
    elif _external_dotfiles_exists "$name"; then
      rm -rf -- "$(profile_external_dotfiles_profile_dir "$name")"
    fi
  fi
}
move_profile_to_trash() {
  local name="$1" source target stamp
  source="$(profile_dir "$name")"
  [[ -d "$source" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
  mkdir -p -- "$ID_TRASH_ROOT"
  stamp="$(date +%Y%m%d-%H%M%S)"
  target="$ID_TRASH_ROOT/${stamp}-${name}"
  mv -- "$source" "$target"
  if _external_dotfiles_exists "$name"; then
    mkdir -p -- "$target/__external-dotfiles"
    mv -- "$(profile_external_dotfiles_profile_dir "$name")" "$target/__external-dotfiles/profile"
  fi
  printf '%s\n' "$target"
}
remove_profile_supporting_files() {
  local name="$1"
  rm -f -- "$(launcher_path "$name")"
  rm -f -- "$ID_USER_XSESSIONS/$(session_filename "$name")" "$ID_USER_WSESSIONS/$(session_filename "$name")"
  rm -f -- "$(profile_override_manifest "$name")"
  if _external_dotfiles_exists "$name"; then
    rm -rf -- "$(profile_external_dotfiles_profile_dir "$name")"
  fi
}
purge_old_trash() {
  [[ -d "$ID_TRASH_ROOT" ]] || return 0
  find "$ID_TRASH_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +"$ID_TRASH_RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
}
