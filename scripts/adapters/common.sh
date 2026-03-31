#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/profile.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/runtime.sh"

adapter_prepare_layout() { :; }
adapter_post_install() { :; }

adapter_default_run_script() {
  local name="$1"
  local rel_script="$2"
  local repo
  repo="$(profile_repo_dir "$name")"
  [[ -f "$repo/$rel_script" ]] || die "Adapter script not found: $repo/$rel_script"
  run_shell_in_profile "$name" "cd '$repo' && chmod +x '$rel_script' && exec bash -x './$rel_script'"
}
