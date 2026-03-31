#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/adapters/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"

adapter_plan() {
  local name="$1"
  local mode="$2"
  local preset
  preset="$(profile_dir "$name")/preset.env"
  cat <<EOF
Adapter detail: jakoolit
- mode: $mode
- installer is run from the repo root
- installer is interactive and may use whiptail and sudo
- optional preset file: $preset
EOF
}

adapter_install() {
  local name="$1"
  local mode="$2"
  local repo preset cmd
  [[ "$mode" == "full" ]] || die "jakoolit adapter currently supports only full mode"
  repo="$(profile_repo_dir "$name")"
  preset="$(profile_dir "$name")/preset.env"
  if [[ -f "$preset" ]]; then
    cmd="cd '$repo' && chmod +x install.sh && exec bash -x ./install.sh --preset '$preset'"
  else
    cmd="cd '$repo' && chmod +x install.sh && exec bash -x ./install.sh"
  fi
  run_shell_in_profile "$name" "$cmd"
}
