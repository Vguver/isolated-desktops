#!/usr/bin/env bash
set -euo pipefail
: "${ID_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ID_STATE_ROOT="${ID_STATE_ROOT:-$HOME/.local/share/isolated-desktops}"
ID_PROFILES_ROOT="${ID_PROFILES_ROOT:-$ID_STATE_ROOT/profiles}"
ID_TRASH_ROOT="${ID_TRASH_ROOT:-$ID_STATE_ROOT/trash}"
ID_EXPORT_ROOT="${ID_EXPORT_ROOT:-$ID_STATE_ROOT/exports}"
ID_TMP_ROOT="${ID_TMP_ROOT:-$ID_STATE_ROOT/tmp}"
ID_CONFIG_ROOT="${ID_CONFIG_ROOT:-$HOME/.config/isolated-desktops}"
ID_USER_BIN="${ID_USER_BIN:-$HOME/.local/bin}"
ID_USER_XSESSIONS="${ID_USER_XSESSIONS:-$HOME/.local/share/xsessions}"
ID_USER_WSESSIONS="${ID_USER_WSESSIONS:-$HOME/.local/share/wayland-sessions}"
ID_DOTFILES_ROOT="${ID_DOTFILES_ROOT:-}"
profile_dir() { printf '%s/%s\n' "$ID_PROFILES_ROOT" "$1"; }
profile_home_dir() { printf '%s/home\n' "$(profile_dir "$1")"; }
profile_repo_dir() { printf '%s/repo\n' "$(profile_dir "$1")"; }
profile_logs_dir() { printf '%s/logs\n' "$(profile_dir "$1")"; }
profile_reports_dir() { printf '%s/reports\n' "$(profile_dir "$1")"; }
profile_snapshots_dir() { printf '%s/snapshots\n' "$(profile_dir "$1")"; }
profile_runtime_dir() { printf '%s/runtime\n' "$(profile_dir "$1")"; }
profile_meta_file() { printf '%s/meta.json\n' "$(profile_dir "$1")"; }
profile_override_manifest() { printf '%s/profiles.d/%s.json\n' "$ID_CONFIG_ROOT" "$1"; }
launcher_path() { printf '%s/id-start-%s\n' "$ID_USER_BIN" "$1"; }
profile_link_state_dir() { printf '%s/dotfiles\n' "$(profile_dir "$1")"; }
profile_links_file() { printf '%s/links.json\n' "$(profile_link_state_dir "$1")"; }
profile_backups_dir() { printf '%s/backups\n' "$(profile_dir "$1")"; }
profile_workspace_dir() { printf '%s/workspace\n' "$(profile_dir "$1")"; }
profile_workspace_file() { printf '%s/%s.code-workspace\n' "$(profile_workspace_dir "$1")" "$1"; }
profile_health_file() { printf '%s/verify.json\n' "$(profile_reports_dir "$1")"; }
profile_transactions_root() { printf '%s/transactions/%s\n' "$ID_TMP_ROOT" "$1"; }
profile_trash_dir() { printf '%s/%s\n' "$ID_TRASH_ROOT" "$1"; }
profile_external_dotfiles_profile_dir() {
  [[ -n "$ID_DOTFILES_ROOT" ]] || return 1
  printf '%s/%s\n' "$ID_DOTFILES_ROOT" "$1"
}
profile_dotfiles_root() {
  if [[ -n "$ID_DOTFILES_ROOT" ]]; then
    printf '%s/home\n' "$(profile_external_dotfiles_profile_dir "$1")"
  else
    printf '%s/home\n' "$(profile_link_state_dir "$1")"
  fi
}
profile_dotfiles_path() { local name="$1" rel="$2"; printf '%s/%s\n' "$(profile_dotfiles_root "$name")" "$rel"; }
