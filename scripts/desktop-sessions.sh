#!/usr/bin/env bash
# desktop-sessions.sh
#
# Generate .desktop session entries for display managers that call
# /usr/local/bin/start-<name>.sh.
# Writes to /usr/share/xsessions and /usr/share/wayland-sessions (requires sudo).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

XSESSIONS_DIR="${XSESSIONS_DIR:-"/usr/share/xsessions"}"
WAYLAND_SESSIONS_DIR="${WAYLAND_SESSIONS_DIR:-"/usr/share/wayland-sessions"}"
START_SCRIPTS_DIR="${START_SCRIPTS_DIR:-"/usr/local/bin"}"

start_script_path_for() {
  local name="$1"
  printf '%s/start-%s.sh\n' "$START_SCRIPTS_DIR" "$name"
}

xsession_file_for() {
  local name="$1"
  printf '%s/%s-isolated.desktop\n' "$XSESSIONS_DIR" "$name"
}

wayland_session_file_for() {
  local name="$1"
  printf '%s/%s-isolated.desktop\n' "$WAYLAND_SESSIONS_DIR" "$name"
}

generate_xsession_file_content() {
  local display_name="$1"
  local script_path="$2"
  cat <<EOF
[Desktop Entry]
Name=$display_name (Isolated)
Comment=Isolated desktop environment
Exec=$script_path
Type=Application
EOF
}

generate_wayland_session_file_content() {
  local display_name="$1"
  local script_path="$2"
  cat <<EOF
[Desktop Entry]
Name=$display_name (Isolated Wayland)
Comment=Isolated Wayland desktop environment
Exec=$script_path
Type=Application
EOF
}

create_session_file() {
  local name="$1" display_name="$2" script_path="$3" target_file="$4" kind="$5"

  if [[ -z "$name" || -z "$display_name" || -z "$script_path" || -z "$target_file" || -z "$kind" ]]; then
    echo "create_session_file: invalid arguments" >&2
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    echo "Error: launch script not found/executable: $script_path" >&2
    echo "Create it first with desktop-launch.sh." >&2
    return 1
  fi

  local tmp
  tmp="$(mktemp)"

  case "$kind" in
    x)
      generate_xsession_file_content "$display_name" "$script_path" > "$tmp"
      ;;
    w)
      generate_wayland_session_file_content "$display_name" "$script_path" > "$tmp"
      ;;
    *)
      echo "Unknown session kind: $kind" >&2
      rm -f "$tmp"
      return 1
      ;;
  esac

  if mv "$tmp" "$target_file" 2>/dev/null; then
    echo "Created session file: $target_file"
  else
    echo "[INFO] Creating $target_file requires sudo." >&2
    read -r -p "Proceed with sudo to write session file? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      sudo mv "$tmp" "$target_file"
      echo "Created session file (sudo): $target_file"
    else
      echo "Aborted. Temp file: $tmp"
      return 1
    fi
  fi
}

list_sessions() {
  local n xs wl
  echo "Known desktops and session files:"
  for n in $(repos_list_names); do
    xs="$(xsession_file_for "$n")"
    wl="$(wayland_session_file_for "$n")"
    printf "  %-20s -> X: %s | W: %s\n" "$n" "$xs" "$wl"
  done
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    create-x)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 create-x <name> [Display Name]" >&2
        exit 1
      fi
      local name="$2"
      local display_name="${3:-$name}"
      create_session_file "$name" "$display_name" \
        "$(start_script_path_for "$name")" \
        "$(xsession_file_for "$name")" x
      ;;
    create-wayland)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 create-wayland <name> [Display Name]" >&2
        exit 1
      fi
      local name="$2"
      local display_name="${3:-$name}"
      create_session_file "$name" "$display_name" \
        "$(start_script_path_for "$name")" \
        "$(wayland_session_file_for "$name")" w
      ;;
    create-interactive)
      echo "Available desktops:"
      repos_list_names
      read -r -p "Desktop name: " name
      if [[ -z "$name" ]]; then
        echo "Empty name, aborting." >&2
        exit 1
      fi
      read -r -p "Display name [default: $name]: " display
      display="${display:-$name}"
      echo "Type: 1) Xorg  2) Wayland  3) Both"
      read -r -p "Choice: " choice
      case "$choice" in
        1)
          create_session_file "$name" "$display" "$(start_script_path_for "$name")" "$(xsession_file_for "$name")" x
          ;;
        2)
          create_session_file "$name" "$display" "$(start_script_path_for "$name")" "$(wayland_session_file_for "$name")" w
          ;;
        3)
          create_session_file "$name" "$display" "$(start_script_path_for "$name")" "$(xsession_file_for "$name")" x
          create_session_file "$name" "$display" "$(start_script_path_for "$name")" "$(wayland_session_file_for "$name")" w
          ;;
        *)
          echo "Invalid choice, aborting." >&2
          exit 1
          ;;
      esac
      ;;
    list)
      list_sessions
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command>

Commands:
  create-x <name> [Display Name]        Create Xorg session in $XSESSIONS_DIR
  create-wayland <name> [Display Name]  Create Wayland session in $WAYLAND_SESSIONS_DIR
  create-interactive                    Interactive mode
  list                                  List desktops and paths of session files

Environment:
  XSESSIONS_DIR         Xorg session directory (default: /usr/share/xsessions)
  WAYLAND_SESSIONS_DIR  Wayland session directory (default: /usr/share/wayland-sessions)
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
