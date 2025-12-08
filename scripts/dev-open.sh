#!/usr/bin/env bash
# dev-open.sh
#
# Developer helper to open real HOME or isolated desktop configs
# in VS Code or VSCodium.
#
# This script does NOT modify anything, it only launches editors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"
DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"

detect_editor() {
  # Prefer explicit argument, then code, then codium
  local editor="${1:-}"
  if [[ -n "$editor" ]]; then
    echo "$editor"
    return 0
  fi

  if command -v code >/dev/null 2>&1; then
    echo "code"
    return 0
  fi

  if command -v codium >/dev/null 2>&1; then
    echo "codium"
    return 0
  fi

  echo "Error: no VS Code or VSCodium found in PATH." >&2
  return 1
}

env_home_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

dotfiles_path_for() {
  local name="$1"
  printf '%s/%s\n' "$DOTFILES_ROOT" "$name"
}

open_real_home() {
  local editor="$1"
  echo "Opening real HOME in $editor: $HOME"
  "$editor" "$HOME"
}

open_fake_home() {
  local editor="$1"
  local name="$2"
  local env_home
  env_home="$(env_home_for "$name")"

  if [[ ! -d "$env_home" ]]; then
    echo "Error: fake HOME for '$name' does not exist at $env_home" >&2
    echo "Install it first using setup_desktops.sh." >&2
    return 1
  fi

  echo "Opening fake HOME for '$name' in $editor: $env_home"
  "$editor" "$env_home"
}

open_dotfiles() {
  local editor="$1"
  local name="$2"
  local df_home
  df_home="$(dotfiles_path_for "$name")"

  if [[ ! -d "$df_home" ]]; then
    echo "Warning: dotfiles path for '$name' does not exist at $df_home" >&2
    echo "You may want to create it using dotfiles-link.sh prepare $name" >&2
    return 1
  fi

  echo "Opening dotfiles for '$name' in $editor: $df_home"
  "$editor" "$df_home"
}

list_known_desktops() {
  echo "Known desktops from REPOS:"
  repos_list_names
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    real-home)
      # dev-open.sh real-home [code|codium]
      local editor
      editor="$(detect_editor "${1:-}")" || exit 1
      open_real_home "$editor"
      ;;
    fake-home)
      # dev-open.sh fake-home <name> [code|codium]
      local name="${1:-}"
      local editor
      if [[ -z "$name" ]]; then
        echo "Usage: $0 fake-home <name> [code|codium]" >&2
        exit 1
      fi
      editor="$(detect_editor "${2:-}")" || exit 1
      open_fake_home "$editor" "$name"
      ;;
    dotfiles)
      # dev-open.sh dotfiles <name> [code|codium]
      local name="${1:-}"
      local editor
      if [[ -z "$name" ]]; then
        echo "Usage: $0 dotfiles <name> [code|codium]" >&2
        exit 1
      fi
      editor="$(detect_editor "${2:-}")" || exit 1
      open_dotfiles "$editor" "$name"
      ;;
    list)
      list_known_desktops
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command> [args]

Commands:
  real-home [editor]              Open your real HOME in VS Code/VSCodium
  fake-home <name> [editor]       Open fake HOME (~/.<name>) for a desktop
  dotfiles <name> [editor]        Open dotfiles tree for a desktop
  list                            List desktops known in REPOS

Examples:
  $0 real-home
  $0 fake-home omarchy
  $0 dotfiles jakoolit codium

Environment:
  CONFIG_BASE_PREFIX   Fake HOME prefix (default: "$HOME/.")
  DOTFILES_ROOT        Base dotfiles directory (default: "$HOME/isolated-desktops/desktops")
EOF
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
