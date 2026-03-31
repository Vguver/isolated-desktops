#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"

left="${1:-}"
right="${2:-}"
[[ -n "$left" && -n "$right" ]] || die "Usage: idtool compare <profile-a> <profile-b>"
left_dir="$(profile_home_dir "$left")/.config"
right_dir="$(profile_home_dir "$right")/.config"
[[ -d "$left_dir" && -d "$right_dir" ]] || die 'Both profiles must exist and have a .config directory'
report="$(profile_reports_dir "$left")/compare-${left}-vs-${right}.txt"
mkdir -p "$(dirname "$report")"
diff -ru "$left_dir" "$right_dir" > "$report" || true
info "Compare report: $report"
