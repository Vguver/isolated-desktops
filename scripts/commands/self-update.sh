#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
force='0'
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force='1'; shift ;;
    help|-h|--help) cat <<'EOU'
Usage:
  idtool self-update [--force]
EOU
      exit 0 ;;
    *) die_usage "Unknown option: $1" ;;
  esac
done
require_project_version
need_cmd git
[[ -d "$ID_ROOT/.git" ]] || die_with_code "$EX_CONFIG" 'self-update requires a git checkout of isolated-desktops'
if [[ "$force" != '1' ]]; then
  if ! git -C "$ID_ROOT" diff --quiet --ignore-submodules -- || ! git -C "$ID_ROOT" diff --cached --quiet --ignore-submodules --; then
    die_with_code "$EX_TEMPFAIL" 'Working tree has uncommitted changes. Commit or stash them first, or rerun with --force.'
  fi
fi
current_branch="$(git -C "$ID_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
[[ -n "$current_branch" && "$current_branch" != 'HEAD' ]] || current_branch='main'
progress_step 1 4 "Fetching project updates"
git -C "$ID_ROOT" fetch --all --tags --prune
progress_step 2 4 "Checking out branch: $current_branch"
git -C "$ID_ROOT" checkout "$current_branch"
progress_step 3 4 "Pulling latest changes"
git -C "$ID_ROOT" pull --ff-only origin "$current_branch"
progress_step 4 4 "Refreshing wrapper and executable bits"
find "$ID_ROOT/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
chmod +x "$ID_ROOT/install.sh" 2>/dev/null || true
"$ID_ROOT/scripts/commands/bootstrap.sh" >/dev/null
progress_done "Project updated successfully on branch: $current_branch"
