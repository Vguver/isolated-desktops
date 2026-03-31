#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/profile.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/dotfiles.sh"
create_workspace_file() {
  local name="$1" workspace
  ensure_profile_layout "$name"; prepare_links "$name"; workspace="$(profile_workspace_file "$name")"; mkdir -p -- "$(dirname "$workspace")"
  python3 - "$workspace" "$name" "$(profile_home_dir "$name")" "$(profile_repo_dir "$name")" "$(profile_dotfiles_root "$name")" "$(profile_logs_dir "$name")" "$(profile_reports_dir "$name")" "$(profile_snapshots_dir "$name")" <<'PY'
import json, sys
workspace, name, home, repo, dotfiles, logs, reports, snapshots = sys.argv[1:]
payload = {
  'folders': [
    {'name': f'{name}: home', 'path': home},
    {'name': f'{name}: repo', 'path': repo},
    {'name': f'{name}: dotfiles', 'path': dotfiles},
    {'name': f'{name}: logs', 'path': logs},
    {'name': f'{name}: reports', 'path': reports},
    {'name': f'{name}: snapshots', 'path': snapshots},
  ],
  'settings': {
    'files.exclude': {'**/.cache': True, '**/node_modules': True, '**/__pycache__': True},
    'search.exclude': {'**/.git': True, '**/.cache': True},
    'files.watcherExclude': {'**/.git/objects/**': True, '**/.cache/**': True},
    'terminal.integrated.env.linux': {'ID_PROFILE_NAME': name},
  },
}
from pathlib import Path
Path(workspace).write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
PY
  success "Workspace file ready: $workspace"
}
status_workspace() { local name="$1" workspace; workspace="$(profile_workspace_file "$name")"; printf 'Workspace: %s\n' "$workspace"; [[ -f "$workspace" ]] && printf 'Status: present\n' || printf 'Status: missing\n'; }
usage() { cat <<'EOU'
Usage:
  idtool workspace create <profile>
  idtool workspace open <profile>
  idtool workspace status <profile>
EOU
}
sub="${1:-}"
case "$sub" in
  create) name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool workspace create <profile>'; require_project_version; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"; create_workspace_file "$name" ;;
  open) name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool workspace open <profile>'; require_project_version; manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"; [[ -f "$(profile_workspace_file "$name")" ]] || create_workspace_file "$name"; open_in_editor "$(profile_workspace_file "$name")" ;;
  status) name="${2:-}"; [[ -n "$name" ]] || die_usage 'Usage: idtool workspace status <profile>'; status_workspace "$name" ;;
  help|-h|--help|'') usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
