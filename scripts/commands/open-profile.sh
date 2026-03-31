#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
kind="${1:-}"; name="${2:-}"
[[ -n "$kind" && -n "$name" ]] || die_usage "Usage: idtool open <home|repo|logs|reports|dotfiles|workspace> <profile>"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
case "$kind" in home) path="$(profile_home_dir "$name")" ;; repo) path="$(profile_repo_dir "$name")" ;; logs) path="$(profile_logs_dir "$name")" ;; reports) path="$(profile_reports_dir "$name")" ;; dotfiles) path="$(profile_dotfiles_root "$name")" ;; workspace) [[ -f "$(profile_workspace_file "$name")" ]] || "$ID_ROOT/scripts/commands/workspace-profile.sh" create "$name"; path="$(profile_workspace_file "$name")" ;; *) die_usage 'Kind must be home, repo, logs, reports, dotfiles or workspace' ;; esac
[[ -e "$path" ]] || die_with_code "$EX_NOINPUT" "Requested path does not exist yet: $path"
open_in_editor "$path"
