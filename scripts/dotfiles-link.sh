#!/usr/bin/env bash
# dotfiles-link.sh
#
# Helper to manage per-desktop dotfiles and link them into the fake HOME.
#
# Goals:
#   - Keep each desktop's dotfiles under:
#       $HOME/isolated-desktops/desktops/NAME/.config/...
#   - Make the fake HOME (~/.NAME) use that tree via symlinks.
#
# Version: 1.0
# Author: Vguver
# License: MIT

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source repos module
if [[ ! -f "$SCRIPT_DIR/repos-desktops.sh" ]]; then
  echo "Error: Required file not found: $SCRIPT_DIR/repos-desktops.sh" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"
DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"

# -------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------

# Get fake HOME path
env_path_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

# Get dotfiles path
dotfiles_path_for() {
  local name="$1"
  printf '%s/%s\n' "$DOTFILES_ROOT" "$name"
}

# Validate desktop name
validate_desktop_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Desktop name cannot be empty" >&2
    return 1
  fi
  
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid desktop name: $name" >&2
    return 1
  fi
  
  return 0
}

# Check if directory is empty
is_directory_empty() {
  local dir="$1"
  
  if [[ ! -d "$dir" ]]; then
    return 0  # Consider non-existent as empty
  fi
  
  # Check if directory has any files (including hidden)
  shopt -s nullglob dotglob
  local files=("$dir"/*)
  shopt -u nullglob dotglob
  
  [[ ${#files[@]} -eq 0 ]]
}

# Safe directory move with error handling
safe_move_contents() {
  local src="$1"
  local dst="$2"
  
  if [[ ! -d "$src" ]]; then
    echo "Error: Source directory does not exist: $src" >&2
    return 1
  fi
  
  if [[ ! -d "$dst" ]]; then
    if ! mkdir -p "$dst"; then
      echo "Error: Failed to create destination: $dst" >&2
      return 1
    fi
  fi
  
  # Move all contents (including hidden files)
  shopt -s dotglob nullglob
  local files=("$src"/*)
  shopt -u dotglob nullglob
  
  if [[ ${#files[@]} -eq 0 ]]; then
    return 0  # Nothing to move
  fi
  
  for item in "${files[@]}"; do
    if ! mv "$item" "$dst/" 2>/dev/null; then
      echo "Error: Failed to move: $item" >&2
      return 1
    fi
  done
  
  return 0
}

# -------------------------------------------------------------------
# PREPARE: Create dotfiles directory structure
# -------------------------------------------------------------------

prepare_dotfiles_structure() {
  local name="$1"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local env_home dot_home
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"
  
  echo ">>> Preparing dotfiles structure for: $name"
  echo ""
  
  # Create dotfiles directories
  if ! mkdir -p "$dot_home/.config" "$dot_home/.local/share" "$dot_home/.local/bin" 2>/dev/null; then
    echo "Error: Failed to create dotfiles directories" >&2
    return 1
  fi
  
  cat <<EOF
Created dotfiles structure:
  Root      : $dot_home
  Config    : $dot_home/.config
  Data      : $dot_home/.local/share
  Binaries  : $dot_home/.local/bin

Fake HOME:
  Path      : $env_home

Next steps:
  1. Place your dotfiles in: $dot_home/.config/
  2. Link to fake HOME: $0 link-config $name
  3. Or adopt existing: $0 adopt-config $name

EOF
  
  return 0
}

# -------------------------------------------------------------------
# LINK-CONFIG: Link fake HOME .config -> dotfiles .config
# -------------------------------------------------------------------

link_config_dir() {
  local name="$1"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local env_home dot_home target link
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"
  target="$dot_home/.config"
  link="$env_home/.config"
  
  echo ">>> Linking config directory for: $name"
  echo ""
  
  # Ensure fake HOME exists
  if [[ ! -d "$env_home" ]]; then
    echo "Error: Fake HOME does not exist: $env_home" >&2
    echo "       Create it first: setup_desktops.sh create $name" >&2
    return 1
  fi
  
  # Ensure dotfiles structure exists
  if ! mkdir -p "$dot_home" "$target" 2>/dev/null; then
    echo "Error: Failed to create dotfiles directory: $dot_home" >&2
    return 1
  fi
  
  # Check if link already exists
  if [[ -L "$link" ]]; then
    local current_target
    current_target="$(readlink "$link")"
    
    if [[ "$current_target" == "$target" ]]; then
      echo "✓ Link already exists and points to correct target"
      echo "  Link:   $link"
      echo "  Target: $target"
      return 0
    else
      echo "Warning: Link exists but points to different target" >&2
      echo "         Current: $current_target" >&2
      echo "         Expected: $target" >&2
      read -r -p "Update link? [y/N]: " ans
      if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        return 1
      fi
      rm -f "$link"
    fi
  fi
  
  # Check if regular directory/file exists
  if [[ -e "$link" ]]; then
    echo "Error: Path exists as regular directory/file: $link" >&2
    echo "       Use 'adopt-config' to move existing configs to dotfiles" >&2
    echo "       Or remove manually before linking" >&2
    return 1
  fi
  
  # Create symlink
  if ! ln -s "$target" "$link" 2>/dev/null; then
    echo "Error: Failed to create symlink" >&2
    return 1
  fi
  
  echo "✓ Successfully linked config directory"
  echo "  Link:   $link"
  echo "  Target: $target"
  echo ""
  
  return 0
}

# -------------------------------------------------------------------
# ADOPT-CONFIG: Move existing ~/.NAME/.config into dotfiles tree
# -------------------------------------------------------------------

adopt_config_dir() {
  local name="$1"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local env_home dot_home env_config dot_config
  env_home="$(env_path_for "$name")"
  dot_home="$(dotfiles_path_for "$name")"
  env_config="$env_home/.config"
  dot_config="$dot_home/.config"
  
  echo ">>> Adopting existing config for: $name"
  echo ""
  
  # Validate fake HOME exists
  if [[ ! -d "$env_home" ]]; then
    echo "Error: Fake HOME does not exist: $env_home" >&2
    echo "       Install the desktop first: setup_desktops.sh create $name" >&2
    return 1
  fi
  
  # Check if config exists and is a directory
  if [[ ! -d "$env_config" ]]; then
    if [[ -L "$env_config" ]]; then
      echo "Error: $env_config is already a symlink" >&2
      local target
      target="$(readlink "$env_config")"
      echo "       Points to: $target" >&2
      echo "       Nothing to adopt" >&2
    else
      echo "Error: $env_config does not exist or is not a directory" >&2
      echo "       Nothing to adopt" >&2
    fi
    return 1
  fi
  
  # Check if env_config is empty
  if is_directory_empty "$env_config"; then
    echo "Warning: $env_config is empty" >&2
    echo "         Nothing to adopt" >&2
    return 1
  fi
  
  # Create dotfiles directory
  if ! mkdir -p "$dot_config" 2>/dev/null; then
    echo "Error: Failed to create dotfiles directory: $dot_config" >&2
    return 1
  fi
  
  # Check if dot_config already has content
  if ! is_directory_empty "$dot_config"; then
    echo "Error: Dotfiles directory is not empty: $dot_config" >&2
    echo "       This could cause conflicts" >&2
    echo "       Please clean it manually first" >&2
    return 1
  fi
  
  # Show plan
  cat <<EOF
Adoption plan:
  1. Move contents from: $env_config
     to:                 $dot_config
  2. Remove original:    $env_config
  3. Create symlink:     $env_config -> $dot_config

EOF
  
  # Count files to be moved
  shopt -s dotglob nullglob
  local files=("$env_config"/*)
  shopt -u dotglob nullglob
  echo "Files/directories to move: ${#files[@]}"
  echo ""
  
  # Confirm
  read -r -p "Continue with adoption? [y/N]: " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "Aborted by user"
    return 1
  fi
  
  echo ""
  echo "Processing..."
  
  # Move contents
  if ! safe_move_contents "$env_config" "$dot_config"; then
    echo "" >&2
    echo "Error: Failed to move config contents" >&2
    echo "       Partial move may have occurred" >&2
    echo "       Check directories manually:" >&2
    echo "         Source: $env_config" >&2
    echo "         Dest:   $dot_config" >&2
    return 1
  fi
  
  # Try to remove original directory
  if ! rmdir "$env_config" 2>/dev/null; then
    echo "Warning: Could not remove original directory (not empty?)" >&2
    echo "         Path: $env_config" >&2
    echo "         Check manually and remove if safe" >&2
  fi
  
  # Verify original is gone or is symlink
  if [[ -d "$env_config" && ! -L "$env_config" ]]; then
    echo "Error: Original directory still exists after move" >&2
    echo "       Cannot create symlink" >&2
    echo "       Check manually: $env_config" >&2
    return 1
  fi
  
  # Remove if it's already a symlink (shouldn't happen but be safe)
  if [[ -L "$env_config" ]]; then
    rm -f "$env_config"
  fi
  
  # Create symlink
  if ! ln -s "$dot_config" "$env_config" 2>/dev/null; then
    echo "Error: Failed to create symlink" >&2
    echo "       Your configs are safe at: $dot_config" >&2
    echo "       You can create symlink manually:" >&2
    echo "         ln -s $dot_config $env_config" >&2
    return 1
  fi
  
  echo ""
  echo "✓ Successfully adopted config for: $name"
  echo "  Original:  (moved)"
  echo "  Dotfiles:  $dot_config"
  echo "  Symlink:   $env_config -> $dot_config"
  echo ""
  echo "Your configs are now managed in the dotfiles tree"
  echo "You can version them with Git using dev-sync.sh"
  echo ""
  
  return 0
}

# -------------------------------------------------------------------
# STATUS: Show linking status
# -------------------------------------------------------------------

show_status() {
  local name="${1:-}"
  
  if [[ -z "$name" ]]; then
    # Show all desktops
    echo "Dotfiles status for all desktops:"
    echo ""
    printf "  %-20s %-15s %s\n" "DESKTOP" "CONFIG STATUS" "PATH"
    printf "  %-20s %-15s %s\n" "-------" "-------------" "----"
    
    for name in $(repos_list_names); do
      local env_config status
      env_config="$(env_path_for "$name")/.config"
      
      if [[ -L "$env_config" ]]; then
        status="✓ Linked"
      elif [[ -d "$env_config" ]]; then
        status="✗ Not linked"
      else
        status="- Missing"
      fi
      
      printf "  %-20s %-15s %s\n" "$name" "$status" "$env_config"
    done
    echo ""
  else
    # Show specific desktop
    if ! validate_desktop_name "$name"; then
      return 1
    fi
    
    local env_home dot_home env_config dot_config
    env_home="$(env_path_for "$name")"
    dot_home="$(dotfiles_path_for "$name")"
    env_config="$env_home/.config"
    dot_config="$dot_home/.config"
    
    echo "Status for: $name"
    echo ""
    echo "Fake HOME:"
    if [[ -d "$env_home" ]]; then
      echo "  ✓ Exists: $env_home"
    else
      echo "  ✗ Missing: $env_home"
    fi
    echo ""
    
    echo "Dotfiles:"
    if [[ -d "$dot_home" ]]; then
      echo "  ✓ Exists: $dot_home"
    else
      echo "  ✗ Missing: $dot_home"
    fi
    echo ""
    
    echo "Config directory:"
    if [[ -L "$env_config" ]]; then
      local target
      target="$(readlink "$env_config")"
      echo "  ✓ Linked: $env_config"
      echo "    Target: $target"
      if [[ "$target" == "$dot_config" ]]; then
        echo "    Status: Correct"
      else
        echo "    Status: Points to wrong target"
      fi
    elif [[ -d "$env_config" ]]; then
      echo "  ✗ Not linked (regular directory): $env_config"
    else
      echo "  - Missing: $env_config"
    fi
    echo ""
  fi
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  prepare <n>          Create dotfiles structure
  link-config <n>      Link fake HOME config to dotfiles
  adopt-config <n>     Move existing config to dotfiles and link
  status [name]           Show linking status
  help                    Show this help message

WORKFLOWS:

  New installation (before installing):
    1. $0 prepare omarchy
    2. setup_desktops.sh create omarchy
    3. $0 adopt-config omarchy

  Existing installation (after installing):
    1. setup_desktops.sh create omarchy
    2. $0 adopt-config omarchy

  Manual dotfiles setup:
    1. $0 prepare omarchy
    2. # Copy dotfiles to ~/isolated-desktops/desktops/omarchy/.config/
    3. $0 link-config omarchy

EXAMPLES:
  $0 prepare omarchy
  $0 link-config jakoolit
  $0 adopt-config dwm-titus
  $0 status
  $0 status omarchy

ENVIRONMENT:
  CONFIG_BASE_PREFIX      Fake HOME prefix
                          (default: \$HOME/.)
  DOTFILES_ROOT           Dotfiles base directory
                          (default: \$HOME/isolated-desktops/desktops)

STRUCTURE:
  Fake HOME:    ~/.<n>/.config/
  Dotfiles:     ~/isolated-desktops/desktops/<n>/.config/
  Symlink:      ~/.<n>/.config -> ~/isolated-desktops/desktops/<n>/.config

EOF
}

main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    prepare)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 prepare <n>" >&2
        exit 1
      fi
      prepare_dotfiles_structure "$2"
      ;;
      
    link-config)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 link-config <n>" >&2
        exit 1
      fi
      link_config_dir "$2"
      ;;
      
    adopt-config)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 adopt-config <n>" >&2
        exit 1
      fi
      adopt_config_dir "$2"
      ;;
      
    status)
      show_status "${2:-}"
      ;;
      
    ""|help|-h|--help)
      show_help
      ;;
      
    *)
      echo "Error: Unknown command: $cmd" >&2
      echo "Use '$0 help' for usage information" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
