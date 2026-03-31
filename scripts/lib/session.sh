#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/manifest.sh"
session_target_dir() {
  local name="$1" scope="$2" session_type="${3:-}"
  if [[ -z "$session_type" ]]; then session_type="$(manifest_get "$name" session_type)"; fi
  if [[ "$scope" == 'user' ]]; then if [[ "$session_type" == 'wayland' ]]; then printf '%s\n' "$ID_USER_WSESSIONS"; else printf '%s\n' "$ID_USER_XSESSIONS"; fi; else if [[ "$session_type" == 'wayland' ]]; then printf '/usr/share/wayland-sessions\n'; else printf '/usr/share/xsessions\n'; fi; fi
}
session_filename() { printf 'isolated-%s.desktop\n' "$1"; }
session_path_for() { local name="$1" scope="$2" session_type="${3:-}"; printf '%s/%s\n' "$(session_target_dir "$name" "$scope" "$session_type")" "$(session_filename "$name")"; }
