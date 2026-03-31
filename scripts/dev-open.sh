#!/usr/bin/env bash
# dev-open.sh
#
# Developer helper to open real HOME or isolated desktop configs
# in VS Code or VSCodium.
#
# This script does NOT modify anything, it only launches editors.
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
env_home_for() {
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

# Detect available editor
detect_editor() {
  local requested="${1:-}"
  
  # If editor explicitly requested, validate it
  if [[ -n "$requested" ]]; then
    if command -v "$requested" >/dev/null 2>&1; then
      echo "$requested"
      return 0
    else
      echo "Error: Requested editor not found: $requested" >&2
      return 1
    fi
  fi
  
  # Try to auto-detect
  local editors=("code" "codium" "vscodium")
  
  for editor in "${editors[@]}"; do
    if command -v "$editor" >/dev/null 2>&1; then
      echo "$editor"
      return 0
    fi
  done
  
  echo "Error: No supported editor found in PATH" >&2
  echo "       Searched for: ${editors[*]}" >&2
  echo "       Please install VS Code or VSCodium" >&2
  return 1
}

# Validate path exists
validate_path_exists() {
  local path="$1"
  local description="$2"
  
  if [[ ! -e "$path" ]]; then
    echo "Error: $description does not exist" >&2
    echo "       Path: $path" >&2
    return 1
  fi
  
  return 0
}

# -------------------------------------------------------------------
# OPEN FUNCTIONS
# -------------------------------------------------------------------

# Open real HOME directory
open_real_home() {
  local editor="$1"
  
  echo ">>> Opening real HOME in $editor"
  echo "    Path: $HOME"
  echo ""
  
  if ! "$editor" "$HOME"; then
    echo "Error: Failed to launch editor" >&2
    return 1
  fi
  
  return 0
}

# Open fake HOME directory
open_fake_home() {
  local editor="$1"
  local name="$2"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local env_home
  env_home="$(env_home_for "$name")"
  
  if ! validate_path_exists "$env_home" "Fake HOME for '$name'"; then
    echo "       Install it first: setup_desktops.sh create $name" >&2
    return 1
  fi
  
  echo ">>> Opening fake HOME for '$name' in $editor"
  echo "    Path: $env_home"
  echo ""
  
  if ! "$editor" "$env_home"; then
    echo "Error: Failed to launch editor" >&2
    return 1
  fi
  
  return 0
}

# Open dotfiles directory
open_dotfiles() {
  local editor="$1"
  local name="$2"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local df_home
  df_home="$(dotfiles_path_for "$name")"
  
  if ! validate_path_exists "$df_home" "Dotfiles for '$name'"; then
    echo "       Create it first: dotfiles-link.sh prepare $name" >&2
    return 1
  fi
  
  echo ">>> Opening dotfiles for '$name' in $editor"
  echo "    Path: $df_home"
  echo ""
  
  if ! "$editor" "$df_home"; then
    echo "Error: Failed to launch editor" >&2
    return 1
  fi
  
  return 0
}

# Open project root
open_project_root() {
  local editor="$1"
  local project_root
  
  # Try to find project root
  if [[ -n "${ISOLATED_DESKTOPS_ROOT:-}" ]]; then
    project_root="$ISOLATED_DESKTOPS_ROOT"
  elif [[ -d "$HOME/isolated-desktops" ]]; then
    project_root="$HOME/isolated-desktops"
  elif [[ -d "$SCRIPT_DIR/.." ]]; then
    project_root="$(cd "$SCRIPT_DIR/.." && pwd)"
  else
    echo "Error: Cannot find project root" >&2
    return 1
  fi
  
  if ! validate_path_exists "$project_root" "Project root"; then
    return 1
  fi
  
  echo ">>> Opening project root in $editor"
  echo "    Path: $project_root"
  echo ""
  
  if ! "$editor" "$project_root"; then
    echo "Error: Failed to launch editor" >&2
    return 1
  fi
  
  return 0
}

# -------------------------------------------------------------------
# LIST FUNCTIONS
# -------------------------------------------------------------------

# List known desktops
list_known_desktops() {
  echo "Known desktops from repositories:"
  echo ""
  
  if [[ $(repos_count) -eq 0 ]]; then
    echo "  (none)"
    echo ""
    echo "Add desktops with: repos-desktops.sh add-interactive"
    return 0
  fi
  
  printf "  %-20s %-12s %-12s\n" "DESKTOP" "FAKE HOME" "DOTFILES"
  printf "  %-20s %-12s %-12s\n" "-------" "---------" "--------"
  
  for name in $(repos_list_names); do
    local env_home df_home env_status df_status
    env_home="$(env_home_for "$name")"
    df_home="$(dotfiles_path_for "$name")"
    
    if [[ -d "$env_home" ]]; then
      env_status="✓ Exists"
    else
      env_status="- Missing"
    fi
    
    if [[ -d "$df_home" ]]; then
      df_status="✓ Exists"
    else
      df_status="- Missing"
    fi
    
    printf "  %-20s %-12s %-12s\n" "$name" "$env_status" "$df_status"
  done
  
  echo ""
}

# -------------------------------------------------------------------
# INTERACTIVE MODE
# -------------------------------------------------------------------

open_interactive() {
  echo "=== Open in Editor ==="
  echo ""
  
  # Detect editor
  local editor
  if ! editor="$(detect_editor)"; then
    return 1
  fi
  echo "Using editor: $editor"
  echo ""
  
  # Choose what to open
  echo "What would you like to open?"
  echo "  1) Real HOME ($HOME)"
  echo "  2) Fake HOME for a desktop"
  echo "  3) Dotfiles for a desktop"
  echo "  4) Project root"
  echo ""
  
  local choice
  read -r -p "Choice [1-4]: " choice
  
  case "$choice" in
    1)
      open_real_home "$editor"
      ;;
    2)
      echo ""
      list_known_desktops
      read -r -p "Desktop name: " name
      if [[ -z "$name" ]]; then
        echo "Error: Empty name" >&2
        return 1
      fi
      open_fake_home "$editor" "$name"
      ;;
    3)
      echo ""
      list_known_desktops
      read -r -p "Desktop name: " name
      if [[ -z "$name" ]]; then
        echo "Error: Empty name" >&2
        return 1
      fi
      open_dotfiles "$editor" "$name"
      ;;
    4)
      open_project_root "$editor"
      ;;
    *)
      echo "Error: Invalid choice" >&2
      return 1
      ;;
  esac
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  real-home [editor]          Open real HOME directory
  fake-home <n> [editor]   Open fake HOME for a desktop
  dotfiles <n> [editor]    Open dotfiles for a desktop
  project [editor]            Open project root directory
  interactive                 Interactive mode
  list                        List desktops and their status
  help                        Show this help message

EXAMPLES:
  $0 real-home
  $0 fake-home omarchy
  $0 dotfiles jakoolit
  $0 project
  $0 interactive

EDITORS:
  code                        VS Code
  codium, vscodium            VSCodium
  
  If no editor specified, auto-detects available editor.
  
ENVIRONMENT:
  CONFIG_BASE_PREFIX          Fake HOME prefix
                              (default: \$HOME/.)
  DOTFILES_ROOT               Dotfiles base directory
                              (default: \$HOME/isolated-desktops/desktops)
  ISOLATED_DESKTOPS_ROOT      Project root override

NOTES:
  - This script only opens directories in an editor
  - It does not modify any files or configurations
  - Useful for development and inspection

EOF
}

main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    real-home)
      local editor
      if ! editor="$(detect_editor "${2:-}")"; then
        exit 1
      fi
      open_real_home "$editor"
      ;;
      
    fake-home)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 fake-home <n> [editor]" >&2
        exit 1
      fi
      local editor
      if ! editor="$(detect_editor "${3:-}")"; then
        exit 1
      fi
      open_fake_home "$editor" "$2"
      ;;
      
    dotfiles)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 dotfiles <n> [editor]" >&2
        exit 1
      fi
      local editor
      if ! editor="$(detect_editor "${3:-}")"; then
        exit 1
      fi
      open_dotfiles "$editor" "$2"
      ;;
      
    project|root)
      local editor
      if ! editor="$(detect_editor "${2:-}")"; then
        exit 1
      fi
      open_project_root "$editor"
      ;;
      
    interactive)
      open_interactive
      ;;
      
    list)
      list_known_desktops
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
