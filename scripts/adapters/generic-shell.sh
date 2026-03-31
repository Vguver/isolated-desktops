#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/adapters/common.sh"

adapter_plan() {
  local name="$1"
  local mode="$2"
  cat <<EOF2
Adapter detail: generic-shell
- mode: $mode
- looks for install.sh, setup.sh, installer.sh, or install-arch.sh in the repo root
- runs the discovered script from the repo root
- use only as a temporary adapter until a project-specific adapter exists
EOF2
}

adapter_install() {
  local name="$1"
  local mode="$2"
  local repo candidate=''
  [[ "$mode" == 'full' ]] || die 'generic-shell supports only full mode'
  repo="$(profile_repo_dir "$name")"
  for candidate in install.sh setup.sh installer.sh install-arch.sh; do
    if [[ -f "$repo/$candidate" ]]; then
      adapter_default_run_script "$name" "$candidate"
      return 0
    fi
  done
  die "No supported installer script found in repo root for generic-shell adapter"
}
