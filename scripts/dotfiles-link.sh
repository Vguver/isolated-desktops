#!/usr/bin/env bash
# dotfiles-link.sh
#
# Basic helper to prepare a dotfiles directory per desktop and optionally
# link it into the fake HOME. This is intentionally minimal for v1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"
DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"

env_path_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

dotfiles_path_for() {
  local name="$1"
  printf '%s/%s\n' "$DOTFILES_ROOT" "$name"
}

prepare_dotfiles_structure() {
  local name="$1"
  local env_home dot_home
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"

  mkdir -p "$dot_home"
  mkdir -p "$dot_home/.config" "$dot_home/.local/share"

  echo "Dotfiles root for '$name': $dot_home"
  echo "Fake HOME for '$name'   : $env_home"
}

link_config_dir() {
  local name="$1"
  local env_home dot_home
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"

  mkdir -p "$dot_home/.config"
  mkdir -p "$env_home"

  local target="$dot_home/.config"
  local link="$env_home/.config"

  if [[ -L "$link" || -d "$link" || -f "$link" ]]; then
    echo "Warning: $link already exists. Not overwriting automatically." >&2
    return 1
  fi

  ln -s "$target" "$link"
  echo "Linked: $link -> $target"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    prepare)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 prepare <name>" >&2
        exit 1
      fi
      prepare_dotfiles_structure "$2"
      ;;
    link-config)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 link-config <name>" >&2
        exit 1
      fi
      link_config_dir "$2"
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command>
Commands:
  prepare <name>       Create dotfiles tree for a desktop under $DOTFILES_ROOT
  link-config <name>   Symlink fake HOME .config to dotfiles .config

Environment:
  DOTFILES_ROOT        Base dir for per-desktop dotfiles (default: $HOME/isolated-desktops/desktops)
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
