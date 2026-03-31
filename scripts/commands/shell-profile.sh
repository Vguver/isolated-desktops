#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/runtime.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool shell <profile>"
safe_name "$name"
require_project_version
[[ -d "$(profile_dir "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
export_profile_env "$name"
info "Profile shell: $name"
info "HOME=$HOME"
metrics_log_local "shell\t$name"
exec "${SHELL:-/bin/bash}"
