#!/usr/bin/env bash
# desktop-launch.sh
#
# Generate /usr/local/bin/start-<name>.sh launch scripts for isolated desktops.
# Each script sets HOME and XDG_* to the fake environment and then execs the
# desktop/WM command.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"
START_SCRIPTS_DIR="${START_SCRIPTS_DIR:-"/usr/local/bin"}"

env_path_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

start_script_path_for() {
  local name="$1"
  printf '%s/start-%s.sh\n' "$START_SCRIPTS_DIR" "$name"
}

desktop_default_command() {
  local name="$1"
  case "$name" in
    omarchy)       echo "Hyprland" ;;
    jakoolit)      echo "Hyprland" ;;
    dwm-titus)     echo "startx" ;;
    ml4w-starter)  echo "Hyprland" ;;
    *)
      return 1
      ;;
  esac
}

generate_start_script_content() {
  local name="$1"; local exec_cmd="$2"
  cat <<EOF
#!/usr/bin/env bash
# Auto-generated start script for isolated desktop: $name
set -euo pipefail

DESKTOP_NAME="$name"
CONFIG_BASE_PREFIX="\${CONFIG_BASE_PREFIX:-\$HOME/.}"
ENV_HOME="\${CONFIG_BASE_PREFIX}\${DESKTOP_NAME}"
ENV_CONFIG="\$ENV_HOME/.config"
ENV_DATA="\$ENV_HOME/.local/share"
ENV_CACHE="\$ENV_HOME/.cache"
ENV_STATE="\$ENV_HOME/.local/state"

if [[ ! -d "\$ENV_HOME" ]]; then
  echo "Error: environment for '\$DESKTOP_NAME' not found at: \$ENV_HOME" >&2
  echo "Install it first using setup_desktops.sh" >&2
  exit 1
fi

mkdir -p "\$ENV_CONFIG" "\$ENV_DATA" "\$ENV_CACHE" "\$ENV_STATE"

export HOME="\$ENV_HOME"
export XDG_CONFIG_HOME="\$ENV_CONFIG"
export XDG_DATA_HOME="\$ENV_DATA"
export XDG_CACHE_HOME="\$ENV_CACHE"
export XDG_STATE_HOME="\$ENV_STATE"

exec $exec_cmd
EOF
}

create_start_script() {
  local name="$1" exec_cmd="${2:-}"

  if [[ -z "$name" ]]; then
    echo "Usage: $0 create <name> [exec_cmd]" >&2
    return 1
  fi

  if ! repos_has "$name"; then
    echo "Error: no repo named '$name' in REPOS." >&2
    return 1
  fi

  if [[ -z "$exec_cmd" ]]; then
    if ! exec_cmd="$(desktop_default_command "$name")"; then
      echo "No default command for '$name'. Please specify exec_cmd explicitly." >&2
      return 1
    fi
  fi

  local env_home
  env_home="$(env_path_for "$name")"
  if [[ ! -d "$env_home" ]]; then
    echo "Warning: fake HOME $env_home does not exist yet." >&2
    echo "You should run setup_desktops.sh create $name first." >&2
  fi

  local script_path tmpfile
  script_path="$(start_script_path_for "$name")"
  tmpfile="$(mktemp)"

  generate_start_script_content "$name" "$exec_cmd" > "$tmpfile"
  chmod +x "$tmpfile"

  if mv "$tmpfile" "$script_path" 2>/dev/null; then
    echo "Created launch script: $script_path"
  else
    echo "[INFO] Need sudo to place script at $script_path"
    read -r -p "Proceed with sudo to write launch script? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      sudo mv "$tmpfile" "$script_path"
      sudo chmod +x "$script_path"
      echo "Created launch script (sudo): $script_path"
    else
      echo "Aborted. Temporary file at: $tmpfile"
      return 1
    fi
  fi

  echo "You can test it from a TTY with:"
  echo "  start-$name.sh"
}

list_launch_scripts() {
  local n p
  echo "Known desktops and launch scripts:"
  for n in $(repos_list_names); do
    p="$(start_script_path_for "$n")"
    if [[ -x "$p" ]]; then
      printf "  %-20s -> %s (exists)\n" "$n" "$p"
    else
      printf "  %-20s -> %s (missing)\n" "$n" "$p"
    fi
  done
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    create)
      create_start_script "${2:-}" "${3:-}"
      ;;
    create-interactive)
      echo "Available desktops:"
      repos_list_names
      read -r -p "Desktop name: " name
      if [[ -z "$name" ]]; then
        echo "Empty name, aborting." >&2
        exit 1
      fi
      local default_cmd
      if default_cmd="$(desktop_default_command "$name" 2>/dev/null)"; then
        echo "Default command for '$name' is: $default_cmd"
        read -r -p "Use this command? [Y/n]: " ans
        if [[ "$ans" =~ ^[Nn]$ ]]; then
          read -r -p "Enter custom start command: " cmd
          default_cmd="$cmd"
        fi
      else
        read -r -p "Start command (e.g. 'Hyprland' or 'dbus-run-session Hyprland'): " default_cmd
      fi
      create_start_script "$name" "$default_cmd"
      ;;
    list)
      list_launch_scripts
      ;;
    show-path)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 show-path <name>" >&2
        exit 1
      fi
      start_script_path_for "$2"
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command>

Commands:
  create <name> [exec_cmd]   Create/overwrite /usr/local/bin/start-<name>.sh
  create-interactive         Ask for desktop name and start command
  list                       List desktops and state of launch scripts
  show-path <name>           Show path of start-<name>.sh

Environment:
  START_SCRIPTS_DIR          Where to install start-<name>.sh (default: /usr/local/bin)
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
