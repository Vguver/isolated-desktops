#!/usr/bin/env bash
# desktop-sessions.sh
#
# Generate .desktop session entries for display managers that call
# /usr/local/bin/start-<n>.sh.
# Writes to /usr/share/xsessions and /usr/share/wayland-sessions (requires sudo).
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

XSESSIONS_DIR="${XSESSIONS_DIR:-"/usr/share/xsessions"}"
WAYLAND_SESSIONS_DIR="${WAYLAND_SESSIONS_DIR:-"/usr/share/wayland-sessions"}"
START_SCRIPTS_DIR="${START_SCRIPTS_DIR:-"/usr/local/bin"}"

# -------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------

# Get start script path
start_script_path_for() {
  local name="$1"
  printf '%s/start-%s.sh\n' "$START_SCRIPTS_DIR" "$name"
}

# Get xsession file path
xsession_file_for() {
  local name="$1"
  printf '%s/%s-isolated.desktop\n' "$XSESSIONS_DIR" "$name"
}

# Get wayland session file path
wayland_session_file_for() {
  local name="$1"
  printf '%s/%s-isolated.desktop\n' "$WAYLAND_SESSIONS_DIR" "$name"
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

# Validate display name
validate_display_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Display name cannot be empty" >&2
    return 1
  fi
  
  # Allow more characters for display name
  if [[ ${#name} -gt 50 ]]; then
    echo "Error: Display name too long (max 50 characters)" >&2
    return 1
  fi
  
  return 0
}

# -------------------------------------------------------------------
# GENERATE SESSION FILES
# -------------------------------------------------------------------

generate_xsession_file_content() {
  local display_name="$1"
  local script_path="$2"
  
  cat <<EOF
[Desktop Entry]
Name=$display_name (Isolated)
Comment=Isolated desktop environment for $display_name
Exec=$script_path
Type=Application
DesktopNames=$display_name
EOF
}

generate_wayland_session_file_content() {
  local display_name="$1"
  local script_path="$2"
  
  cat <<EOF
[Desktop Entry]
Name=$display_name (Isolated Wayland)
Comment=Isolated Wayland desktop environment for $display_name
Exec=$script_path
Type=Application
DesktopNames=$display_name
EOF
}

# -------------------------------------------------------------------
# CREATE SESSION FILE
# -------------------------------------------------------------------

create_session_file() {
  local name="$1"
  local display_name="$2"
  local script_path="$3"
  local target_file="$4"
  local kind="$5"
  
  # Validate inputs
  if [[ -z "$name" || -z "$display_name" || -z "$script_path" || -z "$target_file" || -z "$kind" ]]; then
    echo "Error: Missing required arguments" >&2
    return 1
  fi
  
  # Check if start script exists
  if [[ ! -x "$script_path" ]]; then
    echo "Error: Launch script not found or not executable: $script_path" >&2
    echo "       Create it first with: desktop-launch.sh create $name" >&2
    return 1
  fi
  
  # Generate session file content
  local tmp
  tmp="$(mktemp)"
  
  case "$kind" in
    x)
      if ! generate_xsession_file_content "$display_name" "$script_path" > "$tmp"; then
        echo "Error: Failed to generate X session file" >&2
        rm -f "$tmp"
        return 1
      fi
      ;;
    w)
      if ! generate_wayland_session_file_content "$display_name" "$script_path" > "$tmp"; then
        echo "Error: Failed to generate Wayland session file" >&2
        rm -f "$tmp"
        return 1
      fi
      ;;
    *)
      echo "Error: Unknown session kind: $kind" >&2
      rm -f "$tmp"
      return 1
      ;;
  esac
  
  # Check if target directory exists
  local target_dir
  target_dir="$(dirname "$target_file")"
  if [[ ! -d "$target_dir" ]]; then
    echo "Error: Target directory does not exist: $target_dir" >&2
    echo "       Your display manager may not support this session type" >&2
    rm -f "$tmp"
    return 1
  fi
  
  # Try to write without sudo first
  if mv "$tmp" "$target_file" 2>/dev/null; then
    echo "✓ Created session file: $target_file"
    return 0
  fi
  
  # Need sudo
  echo ""
  echo "The session file will be installed to: $target_file"
  echo "This location requires sudo access"
  echo ""
  read -r -p "Proceed with sudo? [Y/n]: " ans
  
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    echo "Aborted by user"
    echo "Temporary file saved at: $tmp"
    echo "You can manually install it later with:"
    echo "  sudo mv $tmp $target_file"
    return 1
  fi
  
  if ! sudo mv "$tmp" "$target_file"; then
    echo "Error: Failed to install session file with sudo" >&2
    rm -f "$tmp"
    return 1
  fi
  
  echo "✓ Created session file (with sudo): $target_file"
  return 0
}

# -------------------------------------------------------------------
# CREATE FUNCTIONS
# -------------------------------------------------------------------

create_xsession() {
  local name="$1"
  local display_name="${2:-$name}"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if ! validate_display_name "$display_name"; then
    return 1
  fi
  
  echo ">>> Creating X session for: $name"
  echo ""
  
  create_session_file \
    "$name" \
    "$display_name" \
    "$(start_script_path_for "$name")" \
    "$(xsession_file_for "$name")" \
    "x"
}

create_wayland_session() {
  local name="$1"
  local display_name="${2:-$name}"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if ! validate_display_name "$display_name"; then
    return 1
  fi
  
  echo ">>> Creating Wayland session for: $name"
  echo ""
  
  create_session_file \
    "$name" \
    "$display_name" \
    "$(start_script_path_for "$name")" \
    "$(wayland_session_file_for "$name")" \
    "w"
}

# -------------------------------------------------------------------
# INTERACTIVE MODE
# -------------------------------------------------------------------

create_interactive() {
  echo "=== Create Display Manager Session ==="
  echo ""
  
  # List available desktops
  echo "Available desktops:"
  local names
  names=$(repos_list_names)
  if [[ -z "$names" ]]; then
    echo "  (none)"
    echo ""
    echo "Add desktops with: repos-desktops.sh add-interactive"
    return 1
  fi
  
  echo "$names" | sed 's/^/  - /'
  echo ""
  
  # Get desktop name
  local name
  read -r -p "Desktop name: " name
  if [[ -z "$name" ]]; then
    echo "Error: Empty name" >&2
    return 1
  fi
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if ! repos_has "$name"; then
    echo "Error: Desktop '$name' not found in repositories" >&2
    return 1
  fi
  
  # Get display name
  local display_name
  read -r -p "Display name [default: $name]: " display_name
  display_name="${display_name:-$name}"
  
  if ! validate_display_name "$display_name"; then
    return 1
  fi
  
  # Choose session type
  echo ""
  echo "Session type:"
  echo "  1) X11 (Xorg)"
  echo "  2) Wayland"
  echo "  3) Both"
  echo ""
  
  local choice
  read -r -p "Choice [1-3]: " choice
  
  case "$choice" in
    1)
      create_xsession "$name" "$display_name"
      ;;
    2)
      create_wayland_session "$name" "$display_name"
      ;;
    3)
      create_xsession "$name" "$display_name"
      echo ""
      create_wayland_session "$name" "$display_name"
      ;;
    *)
      echo "Error: Invalid choice" >&2
      return 1
      ;;
  esac
  
  echo ""
  echo "Next steps:"
  echo "  1. Restart your display manager (or reboot)"
  echo "  2. Select '$display_name (Isolated)' from the session menu"
  echo "  3. Log in with your user credentials"
  echo ""
}

# -------------------------------------------------------------------
# LIST SESSIONS
# -------------------------------------------------------------------

list_sessions() {
  echo "Display manager sessions for isolated desktops:"
  echo ""
  printf "  %-20s %-12s %-12s\n" "DESKTOP" "X SESSION" "WAYLAND"
  printf "  %-20s %-12s %-12s\n" "-------" "---------" "-------"
  
  for name in $(repos_list_names); do
    local xs_file wl_file xs_status wl_status
    xs_file="$(xsession_file_for "$name")"
    wl_file="$(wayland_session_file_for "$name")"
    
    if [[ -f "$xs_file" ]]; then
      xs_status="✓ Exists"
    else
      xs_status="- Missing"
    fi
    
    if [[ -f "$wl_file" ]]; then
      wl_status="✓ Exists"
    else
      wl_status="- Missing"
    fi
    
    printf "  %-20s %-12s %-12s\n" "$name" "$xs_status" "$wl_status"
  done
  
  echo ""
  echo "Session directories:"
  echo "  X11:     $XSESSIONS_DIR"
  echo "  Wayland: $WAYLAND_SESSIONS_DIR"
  echo ""
}

# -------------------------------------------------------------------
# REMOVE SESSION
# -------------------------------------------------------------------

remove_session() {
  local name="$1"
  local type="${2:-both}"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local xs_file wl_file removed=0
  xs_file="$(xsession_file_for "$name")"
  wl_file="$(wayland_session_file_for "$name")"
  
  case "$type" in
    x|xorg)
      if [[ ! -f "$xs_file" ]]; then
        echo "Error: X session file does not exist: $xs_file" >&2
        return 1
      fi
      
      echo "This will remove: $xs_file"
      read -r -p "Continue? [y/N]: " ans
      if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        return 1
      fi
      
      if sudo rm "$xs_file"; then
        echo "✓ Removed X session file"
        removed=1
      fi
      ;;
      
    w|wayland)
      if [[ ! -f "$wl_file" ]]; then
        echo "Error: Wayland session file does not exist: $wl_file" >&2
        return 1
      fi
      
      echo "This will remove: $wl_file"
      read -r -p "Continue? [y/N]: " ans
      if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        return 1
      fi
      
      if sudo rm "$wl_file"; then
        echo "✓ Removed Wayland session file"
        removed=1
      fi
      ;;
      
    both)
      echo "This will remove:"
      [[ -f "$xs_file" ]] && echo "  - $xs_file"
      [[ -f "$wl_file" ]] && echo "  - $wl_file"
      
      if [[ ! -f "$xs_file" && ! -f "$wl_file" ]]; then
        echo "Error: No session files found for: $name" >&2
        return 1
      fi
      
      echo ""
      read -r -p "Continue? [y/N]: " ans
      if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Aborted by user"
        return 1
      fi
      
      if [[ -f "$xs_file" ]]; then
        if sudo rm "$xs_file"; then
          echo "✓ Removed X session file"
          removed=1
        fi
      fi
      
      if [[ -f "$wl_file" ]]; then
        if sudo rm "$wl_file"; then
          echo "✓ Removed Wayland session file"
          removed=1
        fi
      fi
      ;;
      
    *)
      echo "Error: Invalid type: $type" >&2
      return 1
      ;;
  esac
  
  if [[ $removed -eq 1 ]]; then
    echo ""
    echo "Session files removed. Restart display manager to apply changes."
    return 0
  else
    echo "Error: Failed to remove session files" >&2
    return 1
  fi
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  create-x <n> [display]        Create X11 session
  create-wayland <n> [display]  Create Wayland session
  create-interactive               Interactive creation
  list                             List all sessions
  remove <n> [type]             Remove session files
  help                             Show this help message

EXAMPLES:
  $0 create-x omarchy
  $0 create-wayland jakoolit "JaKooLit Hyprland"
  $0 create-interactive
  $0 list
  $0 remove omarchy
  $0 remove omarchy x

REMOVE TYPES:
  x, xorg    - Remove only X11 session
  w, wayland - Remove only Wayland session
  both       - Remove both (default)

ENVIRONMENT:
  XSESSIONS_DIR           X11 sessions directory
                          (default: /usr/share/xsessions)
  WAYLAND_SESSIONS_DIR    Wayland sessions directory
                          (default: /usr/share/wayland-sessions)
  START_SCRIPTS_DIR       Launch scripts directory
                          (default: /usr/local/bin)

NOTES:
  - Session files require sudo to install
  - Display manager must be restarted after changes
  - Launch script must exist before creating session

WORKFLOW:
  1. Create launch script: desktop-launch.sh create <n>
  2. Create session file:  $0 create-interactive
  3. Restart display manager
  4. Select from login screen

EOF
}

main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    create-x|create-xorg)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 create-x <n> [display]" >&2
        exit 1
      fi
      create_xsession "${2}" "${3:-${2}}"
      ;;
      
    create-wayland|create-w)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 create-wayland <n> [display]" >&2
        exit 1
      fi
      create_wayland_session "${2}" "${3:-${2}}"
      ;;
      
    create-interactive)
      create_interactive
      ;;
      
    list)
      list_sessions
      ;;
      
    remove)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 remove <n> [type]" >&2
        exit 1
      fi
      remove_session "${2}" "${3:-both}"
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
