#!/usr/bin/env bash
# setup_desktops.sh
#
# Create isolated home environments and run repo installer scripts inside them.
# Uses fake HOME dirs like ~/.omarchy so each WM/DE keeps its own .config/.
# Also generates detailed logs per desktop.
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

# Prefix for fake home directories: ~/.<name>
CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"

# Base folder for general logs (optional, for quick overview)
GLOBAL_LOG_ROOT="${GLOBAL_LOG_ROOT:-"$HOME/.logs-desktops"}"

# Track system-level file changes (/etc, /usr/share) if set to "1"
TRACK_SYSTEM_FILES="${TRACK_SYSTEM_FILES:-0}"

# -------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------

# Get fake HOME path for a desktop
env_path_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

# Get log directory for a desktop
env_log_dir_for() {
  local name="$1"
  printf '%s/logs\n' "$(env_path_for "$name")"
}

# Validate desktop name
validate_desktop_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Desktop name cannot be empty" >&2
    return 1
  fi
  
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid desktop name '$name'" >&2
    echo "       Only alphanumeric characters, dash (-) and underscore (_) allowed" >&2
    return 1
  fi
  
  return 0
}

# Check if required commands exist
check_dependencies() {
  local deps=("git" "bash")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing required dependencies:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    return 1
  fi
  
  return 0
}

# List all environments
list_envs_pretty() {
  echo "Known desktops and their configuration:"
  echo ""
  printf "  %-20s %-10s %-60s\n" "NAME" "STATUS" "FAKE HOME"
  printf "  %-20s %-10s %-60s\n" "----" "------" "---------"
  
  local name env_home status
  for name in $(repos_list_names); do
    env_home="$(env_path_for "$name")"
    
    if [[ -d "$env_home" ]]; then
      status="✓ Exists"
    else
      status="✗ Missing"
    fi
    
    printf "  %-20s %-10s %-60s\n" "$name" "$status" "$env_home"
  done
  
  echo ""
  echo "Total desktops: $(repos_count)"
}

# Interactive desktop selection
select_env_name() {
  local names choice
  names="$(repos_list_names)"
  
  if [[ -z "$names" ]]; then
    echo "Error: No desktops defined in REPOS" >&2
    echo "       Use repos-desktops.sh to add repositories" >&2
    return 1
  fi

  # Try fzf first for better UX
  if command -v fzf >/dev/null 2>&1; then
    choice=$(printf "%s\n" "$names" | fzf --prompt="Select desktop to install: " --height=10)
  else
    echo "Select desktop to install:"
    select choice in $names; do
      if [[ -n "$choice" ]]; then
        break
      fi
    done
  fi

  if [[ -z "$choice" ]]; then
    echo "Error: No desktop selected" >&2
    return 1
  fi

  printf '%s\n' "$choice"
}

# Detect installer script in repo
detect_installer_script() {
  local repo_dir="$1"
  local installer=""
  
  if [[ ! -d "$repo_dir" ]]; then
    echo "Error: Repository directory not found: $repo_dir" >&2
    return 1
  fi
  
  # Common installer script names (in order of preference)
  local candidates=(
    "install.sh"
    "setup.sh"
    "install-arch.sh"
    "installer.sh"
  )
  
  # Check for known installer names first
  for candidate in "${candidates[@]}"; do
    if [[ -x "$repo_dir/$candidate" ]]; then
      installer="$repo_dir/$candidate"
      break
    fi
  done
  
  # If not found, look for any executable .sh file
  if [[ -z "$installer" ]]; then
    shopt -s nullglob
    for candidate in "$repo_dir"/*.sh; do
      if [[ -x "$candidate" ]]; then
        installer="$candidate"
        break
      fi
    done
    shopt -u nullglob
  fi
  
  if [[ -n "$installer" ]]; then
    printf '%s\n' "$installer"
    return 0
  else
    return 1
  fi
}

# Run command in isolated environment
run_in_env() {
  local name="$1"
  shift
  
  local env_home env_config env_data env_cache env_state
  env_home="$(env_path_for "$name")"
  env_config="$env_home/.config"
  env_data="$env_home/.local/share"
  env_cache="$env_home/.cache"
  env_state="$env_home/.local/state"

  # Export isolated environment variables
  HOME="$env_home" \
  XDG_CONFIG_HOME="$env_config" \
  XDG_DATA_HOME="$env_data" \
  XDG_CACHE_HOME="$env_cache" \
  XDG_STATE_HOME="$env_state" \
    "$@"
}

# Create pacman snapshot (if available)
create_pacman_snapshot() {
  local output_file="$1"
  
  if ! command -v pacman >/dev/null 2>&1; then
    return 0
  fi
  
  if ! pacman -Qq > "$output_file" 2>/dev/null; then
    echo "Warning: Failed to create pacman snapshot" >&2
    return 1
  fi
  
  return 0
}

# Compare pacman snapshots
compare_pacman_snapshots() {
  local before="$1"
  local after="$2"
  local output="$3"
  
  if [[ ! -f "$before" || ! -f "$after" ]]; then
    return 0
  fi
  
  if ! comm -13 <(sort "$before") <(sort "$after") > "$output" 2>/dev/null; then
    echo "Warning: Failed to compare pacman snapshots" >&2
    return 1
  fi
  
  return 0
}

# -------------------------------------------------------------------
# MAIN FUNCTION: CREATE ENVIRONMENT
# -------------------------------------------------------------------

create_env() {
  local name="$1"
  local url="$2"
  
  # Validate inputs
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if [[ -z "$url" ]]; then
    echo "Error: Repository URL is required" >&2
    return 1
  fi
  
  # Check dependencies
  if ! check_dependencies; then
    return 1
  fi
  
  # Setup paths
  local env_home repo_dir log_dir ts log_file global_log
  env_home="$(env_path_for "$name")"
  repo_dir="$env_home/.repo"
  log_dir="$(env_log_dir_for "$name")"
  ts="$(date '+%Y%m%d-%H%M%S')"
  log_file="$log_dir/installer-$ts.log"
  global_log="$GLOBAL_LOG_ROOT/$name/installer-$ts.log"
  
  # Create directories
  echo ">>> Setting up isolated environment for: $name"
  echo ""
  
  if ! mkdir -p "$env_home" "$env_home/.config" "$env_home/.local/share" \
              "$env_home/.cache" "$env_home/.local/state" "$log_dir" \
              "$GLOBAL_LOG_ROOT/$name" 2>/dev/null; then
    echo "Error: Failed to create directory structure" >&2
    return 1
  fi
  
  # Display configuration
  cat <<EOF
Configuration:
  Desktop       : $name
  Fake HOME     : $env_home
  Repository    : $url
  Log file      : $log_file
  Global log    : $global_log

EOF
  
  # Initialize log files
  {
    echo "=== Installation Log for '$name' ==="
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Repository: $url"
    echo "Fake HOME: $env_home"
    echo ""
  } | tee "$log_file" "$global_log" >/dev/null
  
  # System file tracking (optional)
  local system_timestamp="/var/tmp/isolated-desktops-${name}-before"
  if [[ "$TRACK_SYSTEM_FILES" == "1" ]]; then
    echo "[INFO] TRACK_SYSTEM_FILES=1, creating system timestamp" | tee -a "$log_file" "$global_log"
    if sudo touch "$system_timestamp" 2>/dev/null; then
      echo "       Timestamp created: $system_timestamp" | tee -a "$log_file" "$global_log"
    else
      echo "[WARN] Could not create system timestamp, skipping" | tee -a "$log_file" "$global_log" >&2
      TRACK_SYSTEM_FILES=0
    fi
  fi
  
  # Pacman snapshot BEFORE
  local pac_before="$log_dir/pacman-before.txt"
  local pac_after="$log_dir/pacman-after.txt"
  local pac_installed="$log_dir/pacman-installed.txt"
  
  echo "[INFO] Creating pacman snapshot (before)" | tee -a "$log_file" "$global_log"
  create_pacman_snapshot "$pac_before"
  
  # Timestamp for file changes in fake HOME
  local ts_before_home="$log_dir/.timestamp-before-home"
  touch "$ts_before_home"
  
  # Clone or update repository
  echo "" | tee -a "$log_file" "$global_log"
  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "[STEP] Cloning repository..." | tee -a "$log_file" "$global_log"
    if ! run_in_env "$name" git clone "$url" "$repo_dir" 2>&1 | tee -a "$log_file" "$global_log"; then
      echo "" | tee -a "$log_file" "$global_log"
      echo "Error: Failed to clone repository" | tee -a "$log_file" "$global_log" >&2
      return 1
    fi
  else
    echo "[STEP] Repository exists, updating..." | tee -a "$log_file" "$global_log"
    if ! (cd "$repo_dir" && git pull --ff-only 2>&1) | tee -a "$log_file" "$global_log"; then
      echo "" | tee -a "$log_file" "$global_log"
      echo "Warning: Failed to update repository" | tee -a "$log_file" "$global_log" >&2
    fi
  fi
  
  echo "" | tee -a "$log_file" "$global_log"
  
  # Detect installer script
  echo "[STEP] Detecting installer script..." | tee -a "$log_file" "$global_log"
  local installer=""
  if ! installer="$(detect_installer_script "$repo_dir")"; then
    echo "" | tee -a "$log_file" "$global_log"
    echo "[WARN] No executable installer script found in repository" | tee -a "$log_file" "$global_log" >&2
    echo "       Repository path: $repo_dir" | tee -a "$log_file" "$global_log" >&2
    echo "       You may need to run the installer manually" | tee -a "$log_file" "$global_log" >&2
    return 0
  fi
  
  echo "       Found: $installer" | tee -a "$log_file" "$global_log"
  echo "" | tee -a "$log_file" "$global_log"
  
  # Run installer
  echo "[STEP] Running installer (this may take a while)..." | tee -a "$log_file" "$global_log"
  echo "       Press Ctrl+C to abort" | tee -a "$log_file" "$global_log"
  echo "" | tee -a "$log_file" "$global_log"
  
  if run_in_env "$name" bash -x "$installer" 2>&1 | tee -a "$log_file" "$global_log"; then
    echo "" | tee -a "$log_file" "$global_log"
    echo "[SUCCESS] Installer completed successfully" | tee -a "$log_file" "$global_log"
  else
    local exit_code=$?
    echo "" | tee -a "$log_file" "$global_log"
    echo "[ERROR] Installer failed with exit code: $exit_code" | tee -a "$log_file" "$global_log" >&2
    echo "        Check logs for details: $log_file" | tee -a "$log_file" "$global_log" >&2
  fi
  
  echo "" | tee -a "$log_file" "$global_log"
  
  # Post-installation analysis
  echo "[STEP] Creating post-installation snapshots..." | tee -a "$log_file" "$global_log"
  
  # Pacman snapshot AFTER
  create_pacman_snapshot "$pac_after"
  compare_pacman_snapshots "$pac_before" "$pac_after" "$pac_installed"
  
  if [[ -s "$pac_installed" ]]; then
    local pkg_count
    pkg_count=$(wc -l < "$pac_installed")
    echo "       Packages installed: $pkg_count" | tee -a "$log_file" "$global_log"
    echo "       List saved to: $pac_installed" | tee -a "$log_file" "$global_log"
  fi
  
  # Files changed in fake HOME
  local changed_home="$log_dir/changed-files-home.txt"
  if find "$env_home" -type f -newer "$ts_before_home" > "$changed_home" 2>/dev/null; then
    local file_count
    file_count=$(wc -l < "$changed_home")
    echo "       Files modified in HOME: $file_count" | tee -a "$log_file" "$global_log"
    echo "       List saved to: $changed_home" | tee -a "$log_file" "$global_log"
  fi
  
  # System files changed (optional)
  if [[ "$TRACK_SYSTEM_FILES" == "1" ]]; then
    local changed_system="$log_dir/changed-files-system.txt"
    if sudo find /etc /usr/share -type f -newer "$system_timestamp" > "$changed_system" 2>/dev/null; then
      local sys_count
      sys_count=$(wc -l < "$changed_system")
      echo "       System files modified: $sys_count" | tee -a "$log_file" "$global_log"
      echo "       List saved to: $changed_system" | tee -a "$log_file" "$global_log"
    fi
    sudo rm -f "$system_timestamp" 2>/dev/null || true
  fi
  
  # Final summary
  {
    echo ""
    echo "=== Installation Summary ==="
    echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Desktop: $name"
    echo "Fake HOME: $env_home"
    echo "Logs: $log_dir"
    echo ""
  } | tee -a "$log_file" "$global_log"
  
  echo ">>> Installation of '$name' completed"
  echo ""
  echo "Next steps:"
  echo "  1. Create launch script: ./scripts/desktop-launch.sh create $name"
  echo "  2. Create session file:  ./scripts/desktop-sessions.sh create-interactive"
  echo "  3. Test from TTY:        start-$name.sh"
  echo ""
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  create [name]           Create isolated environment and run installer
  list                    List known desktops and their status
  show-path <n>        Show fake HOME path for a desktop
  shell <n>            Open interactive shell in fake HOME
  remove <n>           Remove fake HOME (asks for confirmation)
  help                    Show this help message

EXAMPLES:
  $0 create
  $0 create omarchy
  $0 list
  $0 shell omarchy
  $0 remove omarchy

ENVIRONMENT VARIABLES:
  CONFIG_BASE_PREFIX      Prefix for fake HOME directories
                          (default: \$HOME/.)
  GLOBAL_LOG_ROOT         Global logs directory
                          (default: \$HOME/.logs-desktops)
  TRACK_SYSTEM_FILES      Track /etc and /usr/share changes
                          (default: 0, set to 1 to enable)

FAKE HOME STRUCTURE:
  ~/.<n>/                Fake HOME root
  ~/.<n>/.config/          Desktop configuration
  ~/.<n>/.local/           Local data and state
  ~/.<n>/.cache/           Cache directory
  ~/.<n>/.repo/            Cloned repository
  ~/.<n>/logs/             Installation logs

EOF
}

main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    create)
      local name="${2:-}"
      
      # Interactive selection if name not provided
      if [[ -z "$name" ]]; then
        if ! name="$(select_env_name)"; then
          exit 1
        fi
      fi
      
      # Validate name exists in repos
      if ! repos_has "$name"; then
        echo "Error: No repository named '$name'" >&2
        echo "       Available: $(repos_list_names | tr '\n' ' ')" >&2
        echo "       Use repos-desktops.sh to add repositories" >&2
        exit 1
      fi
      
      # Get URL and create environment
      local url
      url="$(repos_get_url "$name")"
      create_env "$name" "$url"
      ;;
      
    list)
      list_envs_pretty
      ;;
      
    show-path)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 show-path <n>" >&2
        exit 1
      fi
      env_path_for "$2"
      ;;
      
    shell)
      local name="${2:-}"
      if [[ -z "$name" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 shell <n>" >&2
        exit 1
      fi
      
      local env_home
      env_home="$(env_path_for "$name")"
      
      if [[ ! -d "$env_home" ]]; then
        echo "Error: Fake HOME not found: $env_home" >&2
        echo "       Create it first: $0 create $name" >&2
        exit 1
      fi
      
      echo "Opening shell in fake HOME for: $name"
      echo "Path: $env_home"
      echo "Type 'exit' to return"
      echo ""
      
      HOME="$env_home" \
      XDG_CONFIG_HOME="$env_home/.config" \
      XDG_DATA_HOME="$env_home/.local/share" \
      XDG_CACHE_HOME="$env_home/.cache" \
      XDG_STATE_HOME="$env_home/.local/state" \
        "${SHELL:-/bin/bash}" --login
      ;;
      
    remove)
      local name="${2:-}"
      if [[ -z "$name" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 remove <n>" >&2
        exit 1
      fi
      
      local env_home
      env_home="$(env_path_for "$name")"
      
      if [[ ! -d "$env_home" ]]; then
        echo "Error: Fake HOME not found: $env_home" >&2
        exit 1
      fi
      
      echo "WARNING: This will permanently delete:"
      echo "  $env_home"
      echo ""
      read -r -p "Type the desktop name to confirm: " confirm
      
      if [[ "$confirm" != "$name" ]]; then
        echo "Aborted: name mismatch"
        exit 1
      fi
      
      echo "Removing $env_home..."
      if rm -rf "$env_home"; then
        echo "✓ Removed fake HOME for: $name"
      else
        echo "Error: Failed to remove $env_home" >&2
        exit 1
      fi
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
