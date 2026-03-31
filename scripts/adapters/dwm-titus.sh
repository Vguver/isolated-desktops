#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/adapters/common.sh"

adapter_plan() {
  local name="$1"
  local mode="$2"
  cat <<EOF
Adapter detail: dwm-titus
- mode: $mode
- installer is run from the repo root
- upstream may build and install dwm and may enable a display manager
EOF
}

adapter_install() {
  local name="$1"
  local mode="$2"
  [[ "$mode" == "full" ]] || die "dwm-titus adapter currently supports only full mode"
  adapter_default_run_script "$name" install.sh
}
