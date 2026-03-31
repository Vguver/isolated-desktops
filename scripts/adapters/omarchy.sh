#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/adapters/common.sh"

adapter_plan() {
  local name="$1"
  local mode="$2"
  cat <<EOF
Adapter detail: omarchy
- mode: $mode
- repo is exposed at \$HOME/.local/share/omarchy via symlink
- upstream install.sh is executed from the repo root
EOF
}

adapter_prepare_layout() {
  local name="$1"
  local target repo
  repo="$(profile_repo_dir "$name")"
  target="$(profile_home_dir "$name")/.local/share/omarchy"
  mkdir -p "$(dirname "$target")"
  rm -rf "$target"
  ln -s "$repo" "$target"
}

adapter_install() {
  local name="$1"
  local mode="$2"
  [[ "$mode" == "full" ]] || die "omarchy adapter currently supports only full mode"
  adapter_default_run_script "$name" install.sh
}
