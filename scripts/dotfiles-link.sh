#!/usr/bin/env bash
# dotfiles-link.sh
#
# Helper to manage per-desktop dotfiles and link them into the fake HOME.
#
# Goals:
#   - Keep each desktop's dotfiles under:
#       $HOME/isolated-desktops/desktops/<name>/.config/...
#   - Make the fake HOME (~/.<name>) use that tree via symlinks.
#
# Subcommands:
#   prepare <name>
#       Create dotfiles directory structure for a desktop.
#
#   link-config <name>
#       Create symlink:
#         ~/.<name>/.config -> ~/isolated-desktops/desktops/<name>/.config
#       Only works if ~/.<name>/.config does not exist yet.
#
#   adopt-config <name>
#       Move existing config files from:
#         ~/.<name>/.config/*
#       into:
#         ~/isolated-desktops/desktops/<name>/.config/
#       then replace ~/.<name>/.config with a symlink pointing there.
#       This is the "I already installed and like the result, now adopt it"
#       workflow.

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

# -------------------------------------------------------------------
# PREPARE: create dotfiles directory structure
# -------------------------------------------------------------------

prepare_dotfiles_structure() {
  local name="$1"
  local env_home dot_home
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"

  mkdir -p "$dot_home"
  mkdir -p "$dot_home/.config" "$dot_home/.local/share"

  echo "Dotfiles root for '$name': $dot_home"
  echo "Fake HOME for '$name'   : $env_home"
  echo
  echo "You can now move or copy configs into:"
  echo "  $dot_home/.config/"
  echo "and later link it into the fake HOME using:"
  echo "  dotfiles-link.sh link-config $name"
}

# -------------------------------------------------------------------
# LINK-CONFIG: link fake HOME .config -> dotfiles .config
# -------------------------------------------------------------------

link_config_dir() {
  local name="$1"
  local env_home dot_home
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"

  local target="$dot_home/.config"
  local link="$env_home/.config"

  mkdir -p "$dot_home"
  mkdir -p "$target"
  mkdir -p "$env_home"

  if [[ -L "$link" ]]; then
    echo "Warning: $link is already a symlink. Not overwriting." >&2
    return 1
  fi

  if [[ -d "$link" || -f "$link" ]]; then
    echo "Error: $link already exists as a regular directory/file." >&2
    echo "Use 'adopt-config $name' if you want to move its contents into the dotfiles directory," >&2
    echo "or handle it manually before linking." >&2
    return 1
  fi

  ln -s "$target" "$link"
  echo "Linked: $link -> $target"
}

# -------------------------------------------------------------------
# ADOPT-CONFIG: move existing ~/.<name>/.config into dotfiles tree
# -------------------------------------------------------------------

adopt_config_dir() {
  local name="$1"
  local env_home dot_home env_config dot_config
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"
  env_config="$env_home/.config"
  dot_config="$dot_home/.config"

  if [[ ! -d "$env_home" ]]; then
    echo "Error: fake HOME does not exist: $env_home" >&2
    echo "Install the desktop first using setup_desktops.sh create $name." >&2
    return 1
  fi

  if [[ ! -d "$env_config" ]]; then
    echo "Error: $env_config does not exist or is not a directory." >&2
    echo "Nothing to adopt. If you want to start fresh, use 'prepare' + 'link-config' instead." >&2
    return 1
  fi

  mkdir -p "$dot_config"

  # Check if dot_config is empty to avoid merging two sets of configs silently
  if [[ -n "$(find "$dot_config" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "Warning: $dot_config is not empty." >&2
    echo "For safety, adopt-config will NOT merge configs automatically." >&2
    echo "Please move or clean its contents manually, then run adopt-config again." >&2
    echo
    echo "Dotfiles directory:" >&2
    echo "  $dot_config" >&2
    return 1
  fi

  echo "This will:"
  echo "  1) Move all files from:"
  echo "       $env_config"
  echo "     into:"
  echo "       $dot_config"
  echo "  2) Remove the original directory (if empty)"
  echo "  3) Create a symlink:"
  echo "       $env_config -> $dot_config"
  echo
  read -r -p "Continue with adopt-config for '$name'? [y/N]: " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    return 1
  fi

  # Move contents of env_config into dot_config
  shopt -s dotglob nullglob
  if mv "$env_config"/* "$dot_config"/ 2>/dev/null; then
    :
  fi
  shopt -u dotglob nullglob

  # Try to remove the original env_config directory
  if rmdir "$env_config" 2>/dev/null; then
    :
  else
    echo "Warning: could not remove $env_config (directory not empty?)." >&2
    echo "Check its contents manually if needed." >&2
  fi

  # If env_config still exists, do not overwrite it
  if [[ -e "$env_config" || -L "$env_config" ]]; then
    echo "Warning: $env_config still exists after move; not overwriting with symlink." >&2
    echo "Please verify manually that it points to $dot_config if you create it." >&2
    return 1
  fi

  ln -s "$dot_config" "$env_config"
  echo "Adopted config for '$name' and created symlink:"
  echo "  $env_config -> $dot_config"
}

# -------------------------------------------------------------------
# CLI
# -------------------------------------------------------------------

main() {
  local cmd="${1:-}"
  case "$cmd" in
    prepare)
      # dotfiles-link.sh prepare NAME
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 prepare NAME" >&2
        exit 1
      fi
      prepare_dotfiles_structure "$2"
      ;;
    link-config)
      # dotfiles-link.sh link-config NAME
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 link-config NAME" >&2
        exit 1
      fi
      link_config_dir "$2"
      ;;
    adopt-config)
      # dotfiles-link.sh adopt-config NAME
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 adopt-config NAME" >&2
        exit 1
      fi
      adopt_config_dir "$2"
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage:
  dotfiles-link.sh COMMAND [ARGS]

Commands:
  prepare NAME
      Create dotfiles tree for a desktop under:
        \$DOTFILES_ROOT/NAME/.config
      Does NOT touch the fake HOME.

  link-config NAME
      Create symlink:
        ~/.NAME/.config -> \$DOTFILES_ROOT/NAME/.config
      Fails if ~/.NAME/.config already exists as a real directory or file.

  adopt-config NAME
      Move existing configs from:
        ~/.NAME/.config/*
      into:
        \$DOTFILES_ROOT/NAME/.config/
      and then replace ~/.NAME/.config with a symlink pointing there.
      This is useful after you have installed a desktop and want to
      centralize its configs in the desktops/ tree for Git and editing.

Environment variables:
  CONFIG_BASE_PREFIX   Fake HOME prefix (default: "\$HOME/.")
  DOTFILES_ROOT        Base dir for per-desktop dotfiles
                       (default: "\$HOME/isolated-desktops/desktops")
EOF
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo "Use: $0 help" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
