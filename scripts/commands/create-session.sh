#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
source "$ID_ROOT/scripts/lib/session.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool session create <profile> [--scope user|system] [--type x11|wayland]"
safe_name "$name"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
shift || true
scope='system'; session_type=''
while [[ $# -gt 0 ]]; do case "$1" in --scope) scope="${2:-}"; shift 2 ;; --type) session_type="${2:-}"; shift 2 ;; *) die_usage "Unknown option: $1" ;; esac; done
[[ "$scope" == 'user' || "$scope" == 'system' ]] || die_usage 'Scope must be user or system'
[[ -n "$session_type" ]] || session_type="$(manifest_get "$name" session_type)"
[[ "$session_type" == 'wayland' || "$session_type" == 'x11' ]] || die_usage 'Type must be x11 or wayland'
launcher="$(launcher_path "$name")"; [[ -x "$launcher" ]] || "$ID_ROOT/scripts/commands/create-launcher.sh" "$name"
dir="$(session_target_dir "$name" "$scope" "$session_type")"; file="$(session_filename "$name")"; path="$dir/$file"
content=$(cat <<EOF2
[Desktop Entry]
Name=Isolated $(manifest_get "$name" display_name)
Comment=Start isolated desktop profile: $name
Exec=$launcher
TryExec=$launcher
Type=Application
DesktopNames=isolated-$name
EOF2
)
enable_temp_cleanup_trap
tmpfile="$(create_temp_file)"; printf '%s\n' "$content" > "$tmpfile"
if [[ "$scope" == 'system' ]]; then ensure_sudo_session; sudo mkdir -p -- "$dir"; sudo install -m 0644 -- "$tmpfile" "$path"; else mkdir -p -- "$dir"; install -m 0644 -- "$tmpfile" "$path"; fi
info "Session file created: $path"
[[ "$scope" == 'user' ]] && warn 'Some display managers only read system session directories.'
