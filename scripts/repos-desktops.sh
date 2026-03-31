#!/usr/bin/env bash
# repos-desktops.sh
#
# Module to manage desktop/WM repositories used by the isolated desktops system.
# Provides functions to list, add, and query repos.
#
# Version: 1.0
# Author: Vguver
# License: MIT

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

# User configuration file. Each line must be valid Bash, for example:
#   REPOS["name"]="https://url.git"
REPOS_CONFIG_FILE="${REPOS_CONFIG_FILE:-"$HOME/.config/desktops-repos.conf"}"

# -------------------------------------------------------------------
# INITIALIZATION
# -------------------------------------------------------------------

# Ensure config directory exists
init_config_dir() {
  local config_dir
  config_dir="$(dirname "$REPOS_CONFIG_FILE")"
  
  if [[ ! -d "$config_dir" ]]; then
    if ! mkdir -p "$config_dir" 2>/dev/null; then
      echo "Error: Cannot create config directory: $config_dir" >&2
      return 1
    fi
  fi
}

# Create config file if it doesn't exist
init_config_file() {
  if [[ ! -f "$REPOS_CONFIG_FILE" ]]; then
    cat > "$REPOS_CONFIG_FILE" <<'EOF'
# Desktop repositories configuration for repos-desktops.sh
# Format: REPOS["name"]="https://url.git"
#
# Example:
# REPOS["my-desktop"]="https://github.com/user/my-desktop.git"

EOF
    chmod 644 "$REPOS_CONFIG_FILE"
  fi
}

# Initialize configuration
init_config_dir || exit 1
init_config_file

# -------------------------------------------------------------------
# DEFAULT REPOSITORIES
# -------------------------------------------------------------------

# Initialize REPOS array if not already declared
if ! declare -p REPOS &>/dev/null; then
  declare -gA REPOS
fi

# Default repositories
REPOS["dwm-titus"]="https://github.com/ChrisTitusTech/dwm-titus.git"
REPOS["omarchy"]="https://github.com/basecamp/omarchy.git"
REPOS["jakoolit"]="https://github.com/JaKooLit/Arch-Hyprland.git"
REPOS["ml4w-starter"]="https://github.com/mylinuxforwork/hyprland-starter.git"
REPOS["ml4w-dotfiles"]="https://github.com/mylinuxforwork/dotfiles.git"

# -------------------------------------------------------------------
# VALIDATION FUNCTIONS
# -------------------------------------------------------------------

# Validate repository name (alphanumeric, dash, underscore only)
validate_repo_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Repository name cannot be empty" >&2
    return 1
  fi
  
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid repository name '$name'" >&2
    echo "       Only alphanumeric characters, dash (-) and underscore (_) allowed" >&2
    return 1
  fi
  
  if [[ ${#name} -gt 50 ]]; then
    echo "Error: Repository name too long (max 50 characters)" >&2
    return 1
  fi
  
  return 0
}

# Validate Git URL
validate_git_url() {
  local url="$1"
  
  if [[ -z "$url" ]]; then
    echo "Error: Git URL cannot be empty" >&2
    return 1
  fi
  
  # Check for common Git URL patterns
  if [[ ! "$url" =~ ^(https?://|git@|ssh://|git://) ]]; then
    echo "Error: Invalid Git URL format: $url" >&2
    echo "       Expected format: https://, git@, ssh://, or git://" >&2
    return 1
  fi
  
  return 0
}

# -------------------------------------------------------------------
# LOAD EXTRA REPOSITORIES
# -------------------------------------------------------------------

# Load repositories from config file
repos_load_extra() {
  if [[ ! -f "$REPOS_CONFIG_FILE" ]]; then
    return 0
  fi
  
  # Validate config file is readable
  if [[ ! -r "$REPOS_CONFIG_FILE" ]]; then
    echo "Warning: Cannot read config file: $REPOS_CONFIG_FILE" >&2
    return 1
  fi
  
  # Source config file in a safe way
  # shellcheck source=/dev/null
  if ! source "$REPOS_CONFIG_FILE" 2>/dev/null; then
    echo "Warning: Failed to load config file: $REPOS_CONFIG_FILE" >&2
    echo "         Please check for syntax errors" >&2
    return 1
  fi
  
  return 0
}

# Load extra repositories
repos_load_extra

# -------------------------------------------------------------------
# PUBLIC FUNCTIONS
# -------------------------------------------------------------------

# Check if repository exists
repos_has() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Repository name required" >&2
    return 1
  fi
  
  [[ -n "${REPOS[$name]+x}" ]]
}

# Get repository URL
repos_get_url() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Repository name required" >&2
    return 1
  fi
  
  if repos_has "$name"; then
    printf '%s\n' "${REPOS[$name]}"
    return 0
  else
    echo "Error: No repository named '$name'" >&2
    return 1
  fi
}

# List all repository names (sorted)
repos_list_names() {
  if [[ ${#REPOS[@]} -eq 0 ]]; then
    return 0
  fi
  
  local name
  for name in "${!REPOS[@]}"; do
    echo "$name"
  done | sort
}

# List repositories with URLs in pretty format
repos_list_pretty() {
  if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "No repositories configured."
    return 0
  fi
  
  local name
  for name in $(repos_list_names); do
    printf '%-20s -> %s\n' "$name" "${REPOS[$name]}"
  done
}

# Add a new repository
repos_add() {
  local name="$1"
  local url="$2"
  
  # Validate inputs
  if ! validate_repo_name "$name"; then
    return 1
  fi
  
  if ! validate_git_url "$url"; then
    return 1
  fi
  
  # Check if repo already exists
  if repos_has "$name"; then
    echo "Warning: Repository '$name' already exists" >&2
    echo "         Current URL: ${REPOS[$name]}" >&2
    echo "         New URL: $url" >&2
    read -r -p "Update URL? [y/N]: " ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
      echo "Aborted by user."
      return 1
    fi
  fi
  
  # Add to in-memory array
  REPOS["$name"]="$url"
  
  # Append to config file
  {
    echo ""
    echo "# Added on $(date '+%Y-%m-%d %H:%M:%S')"
    printf 'REPOS["%s"]="%s"\n' "$name" "$url"
  } >> "$REPOS_CONFIG_FILE"
  
  echo "✓ Added repository: $name"
  echo "  URL: $url"
  echo "  Config: $REPOS_CONFIG_FILE"
  
  return 0
}

# Interactive repository addition
repos_add_interactive() {
  local name url
  
  echo "=== Add New Desktop Repository ==="
  echo ""
  
  # Get repository name
  while true; do
    read -r -p "Repository name (e.g., omarchy): " name
    if [[ -z "$name" ]]; then
      echo "Error: Name cannot be empty" >&2
      continue
    fi
    if validate_repo_name "$name"; then
      break
    fi
  done
  
  # Get repository URL
  while true; do
    read -r -p "Git repository URL: " url
    if [[ -z "$url" ]]; then
      echo "Error: URL cannot be empty" >&2
      continue
    fi
    if validate_git_url "$url"; then
      break
    fi
  done
  
  # Confirm and add
  echo ""
  echo "Repository to add:"
  echo "  Name: $name"
  echo "  URL:  $url"
  echo ""
  read -r -p "Continue? [Y/n]: " confirm
  
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Aborted by user."
    return 1
  fi
  
  repos_add "$name" "$url"
}

# Remove a repository from config file
repos_remove() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Repository name required" >&2
    return 1
  fi
  
  if ! repos_has "$name"; then
    echo "Error: Repository '$name' not found" >&2
    return 1
  fi
  
  echo "Warning: This will remove '$name' from the config file"
  echo "         URL: ${REPOS[$name]}"
  read -r -p "Continue? [y/N]: " ans
  
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    return 1
  fi
  
  # Remove from in-memory array
  unset "REPOS[$name]"
  
  # Remove from config file (create backup first)
  local backup="${REPOS_CONFIG_FILE}.backup.$(date +%s)"
  cp "$REPOS_CONFIG_FILE" "$backup"
  
  # Filter out the repository entry
  grep -v "^REPOS\\[\"$name\"\\]=" "$REPOS_CONFIG_FILE" > "${REPOS_CONFIG_FILE}.tmp" || true
  mv "${REPOS_CONFIG_FILE}.tmp" "$REPOS_CONFIG_FILE"
  
  echo "✓ Removed repository: $name"
  echo "  Backup saved: $backup"
  
  return 0
}

# Show config file path
repos_config_path() {
  printf '%s\n' "$REPOS_CONFIG_FILE"
}

# Show repository count
repos_count() {
  echo "${#REPOS[@]}"
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

# Show help message
show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  list                    List all repositories (name -> URL)
  names                   List only repository names
  count                   Show number of repositories
  get-url <name>          Show URL for a repository
  add <name> <url>        Add a new repository
  add-interactive         Add repository interactively
  remove <name>           Remove a repository
  config-path             Show config file path
  help                    Show this help message

EXAMPLES:
  $0 list
  $0 add my-desktop https://github.com/user/desktop.git
  $0 get-url omarchy
  $0 remove my-desktop

ENVIRONMENT:
  REPOS_CONFIG_FILE       Path to config file
                          (default: ~/.config/desktops-repos.conf)

EOF
}

# Main CLI handler
main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    list)
      echo "Known repositories:"
      repos_list_pretty
      ;;
    names)
      repos_list_names
      ;;
    count)
      echo "Total repositories: $(repos_count)"
      ;;
    get-url)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Repository name required" >&2
        echo "Usage: $0 get-url <name>" >&2
        exit 1
      fi
      repos_get_url "$2"
      ;;
    add)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        echo "Error: Name and URL required" >&2
        echo "Usage: $0 add <name> <url>" >&2
        exit 1
      fi
      repos_add "$2" "$3"
      ;;
    add-interactive)
      repos_add_interactive
      ;;
    remove)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Repository name required" >&2
        echo "Usage: $0 remove <name>" >&2
        exit 1
      fi
      repos_remove "$2"
      ;;
    config-path)
      repos_config_path
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

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
