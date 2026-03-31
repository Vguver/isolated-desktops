#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/plan.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool analyze <profile> [mode]"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
manifest_validate "$name"
mode="${2:-$(manifest_get "$name" default_mode)}"
manifest_supports_mode "$name" "$mode" || die "Mode not supported for $name: $mode"
print_plan "$name" "$mode"
adapter="$(manifest_get "$name" adapter)"
source "$ID_ROOT/scripts/adapters/$adapter.sh"
if declare -F adapter_plan >/dev/null; then echo; adapter_plan "$name" "$mode"; fi
