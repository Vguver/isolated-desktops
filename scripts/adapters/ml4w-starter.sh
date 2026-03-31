#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/adapters/common.sh"

adapter_plan() {
  local name="$1"
  local mode="$2"
  cat <<EOF
Adapter detail: ml4w-starter
- mode: $mode
- config-only copies repo/dotfiles into the profile home
- full runs setup/setup.sh from the repo root
EOF
}

adapter_install() {
  local name="$1"
  local mode="$2"
  local repo home
  repo="$(profile_repo_dir "$name")"
  home="$(profile_home_dir "$name")"
  case "$mode" in
    config-only)
      [[ -d "$repo/dotfiles" ]] || die "Expected dotfiles folder not found in $repo"
      copy_tree "$repo/dotfiles" "$home"
      ;;
    full)
      [[ -f "$repo/setup/setup.sh" ]] || die "Expected setup/setup.sh not found in $repo"
      run_shell_in_profile "$name" "cd '$repo' && chmod +x setup/setup.sh && exec bash -x ./setup/setup.sh"
      ;;
    *)
      die "Unsupported mode for ml4w-starter: $mode"
      ;;
  esac
}
