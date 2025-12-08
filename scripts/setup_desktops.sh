#!/usr/bin/env bash
# setup_desktops.sh
#
# Create isolated home environments and run repo installer scripts inside them.
# Uses fake HOME dirs like ~/.omarchy so each WM/DE keeps its own .config/.
# Also generates detailed logs per desktop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/repos-desktops.sh"

# Prefix for fake home directories: ~/.<name>
CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"

# Base folder for general logs (optional, for quick overview)
GLOBAL_LOG_ROOT="${GLOBAL_LOG_ROOT:-"$HOME/.logs-desktops"}"
mkdir -p "$GLOBAL_LOG_ROOT"

# Track system-level file changes (/etc, /usr/share) if set to "1"
TRACK_SYSTEM_FILES="${TRACK_SYSTEM_FILES:-0}"

# -------------------------------------------------------------------
# FUNCTIONS
# -------------------------------------------------------------------

env_path_for() {
  local name="$1"
  printf '%s%s\n' "$CONFIG_BASE_PREFIX" "$name"
}

env_log_dir_for() {
  local name="$1"
  printf '%s/logs\n' "$(env_path_for "$name")"
}

list_envs_pretty() {
  local name env_home url
  echo "Known desktops (REPOS -> fake HOME):"
  for name in $(repos_list_names); do
    env_home="$(env_path_for "$name")"
    url="$(repos_get_url "$name" || true)"
    printf "  %-20s -> %-60s  [home: %s]\n" "$name" "$url" "$env_home"
  done
}

select_env_name() {
  local names choice
  names="$(repos_list_names)"
  if [[ -z "$names" ]]; then
    echo "No desktops defined in REPOS." >&2
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    choice=$(printf "%s\n" "$names" | fzf --prompt="Select desktop to install: ")
  else
    echo "Select desktop to install:"
    select choice in $names; do
      [[ -n "$choice" ]] && break
    done
  fi

  printf '%s\n' "$choice"
}

detect_installer_script() {
  local repo_dir="$1"
  local installer=""
  shopt -s nullglob
  for candidate in install.sh setup.sh install-arch.sh install*.sh; do
    if [[ -f "$repo_dir/$candidate" ]]; then
      installer="$repo_dir/$candidate"
      break
    fi
  done
  if [[ -z "$installer" ]]; then
    for candidate in "$repo_dir"/*.sh; do
      [[ -f "$candidate" ]] && { installer="$candidate"; break; }
    done
  fi
  shopt -u nullglob
  [[ -n "$installer" ]] && printf '%s\n' "$installer" || return 1
}

run_in_env() {
  local name="$1"; shift
  local env_home env_config env_data env_cache env_state
  env_home="$(env_path_for "$name")"
  env_config="$env_home/.config"
  env_data="$env_home/.local/share"
  env_cache="$env_home/.cache"
  env_state="$env_home/.local/state"

  HOME="$env_home" \
  XDG_CONFIG_HOME="$env_config" \
  XDG_DATA_HOME="$env_data" \
  XDG_CACHE_HOME="$env_cache" \
  XDG_STATE_HOME="$env_state" \
    "$@"
}

create_env() {
  local name="$1" url="$2"
  if [[ -z "$name" || -z "$url" ]]; then
    echo "create_env: requires <name> <url>" >&2
    return 1
  fi

  local env_home repo_dir log_dir ts log_file global_log
  env_home="$(env_path_for "$name")"
  repo_dir="$env_home/.repo"
  log_dir="$(env_log_dir_for "$name")"
  mkdir -p "$env_home" "$env_home/.config" "$env_home/.local/share" "$env_home/.cache" "$env_home/.local/state" "$log_dir"
  mkdir -p "$GLOBAL_LOG_ROOT/$name"

  ts="$(date '+%Y%m%d-%H%M%S')"
  log_file="$log_dir/installer-$ts.log"
  global_log="$GLOBAL_LOG_ROOT/$name/installer-$ts.log"

  echo ">>> Creating isolated environment for: $name"
  echo "    Fake HOME : $env_home"
  echo "    Repo      : $url"
  echo "    Log file  : $log_file"

  # Optional system tracking timestamp
  local system_timestamp="/var/tmp/isolated-desktops-${name}-before"
  if [[ "$TRACK_SYSTEM_FILES" == "1" ]]; then
    echo "[INFO] TRACK_SYSTEM_FILES=1, creating timestamp at $system_timestamp (requires sudo)."
    if ! sudo touch "$system_timestamp"; then
      echo "[WARN] Could not create system timestamp. Skipping system file tracking." >&2
      TRACK_SYSTEM_FILES=0
    fi
  fi

  # Pacman snapshot BEFORE
  local pac_before="$log_dir/pacman-before.txt"
  local pac_after="$log_dir/pacman-after.txt"
  local pac_installed="$log_dir/pacman-installed.txt"
  if command -v pacman >/dev/null 2>&1; then
    pacman -Qq > "$pac_before" || true
  fi

  # Timestamp for file changes in fake HOME
  local ts_before_home="$log_dir/.timestamp-before-home"
  touch "$ts_before_home"

  # Clone or update repo
  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "--- Cloning repository into $repo_dir ..." | tee -a "$log_file" | tee -a "$global_log" >/dev/null
    run_in_env "$name" git clone "$url" "$repo_dir" 2>&1 | tee -a "$log_file" | tee -a "$global_log"
  else
    echo "--- Repository exists, pulling..." | tee -a "$log_file" | tee -a "$global_log" >/dev/null
    (
      cd "$repo_dir" || exit 1
      git pull --ff-only
    ) 2>&1 | tee -a "$log_file" | tee -a "$global_log"
  fi

  # Detect installer
  local installer=""
  if ! installer="$(detect_installer_script "$repo_dir")"; then
    echo ">>> No installer script found in $repo_dir" | tee -a "$log_file" | tee -a "$global_log"
    echo "Inspect repo manually." | tee -a "$log_file" | tee -a "$global_log"
    return 0
  fi

  echo "--- Found installer: $installer" | tee -a "$log_file" | tee -a "$global_log"
  echo "--- Running installer inside the isolated environment (with bash -x)..." | tee -a "$log_file" | tee -a "$global_log"

  # Run installer with bash -x and capture all output
  run_in_env "$name" bash -x "$installer" \
    2>&1 | tee -a "$log_file" | tee -a "$global_log"

  # Pacman snapshot AFTER + diff
  if command -v pacman >/dev/null 2>&1; then
    pacman -Qq > "$pac_after" || true
    if [[ -s "$pac_before" && -s "$pac_after" ]]; then
      comm -13 <(sort "$pac_before") <(sort "$pac_after") > "$pac_installed" || true
    fi
  fi

  # Files changed in fake HOME
  local changed_home="$log_dir/changed-files-home.txt"
  find "$env_home" -type f -newer "$ts_before_home" > "$changed_home" || true

  # Files changed in /etc and /usr/share (optional)
  if [[ "$TRACK_SYSTEM_FILES" == "1" ]]; then
    local changed_system="$log_dir/changed-files-system.txt"
    echo "[INFO] Scanning for system file changes in /etc and /usr/share (requires sudo)." | tee -a "$log_file" | tee -a "$global_log"
    sudo find /etc /usr/share -type f -newer "$system_timestamp" > "$changed_system" 2>/dev/null || true
  fi

  echo ">>> Installation of '$name' completed. Fake HOME: $env_home"
  echo "    Logs stored in: $log_dir"
  echo "    Global logs in: $GLOBAL_LOG_ROOT/$name"
}

# -------------------------------------------------------------------
# CLI
# -------------------------------------------------------------------

main() {
  local cmd="${1:-}"
  case "$cmd" in
    create)
      local name="${2:-}"
      if [[ -z "$name" ]]; then
        name="$(select_env_name)" || exit 1
      fi
      if ! repos_has "$name"; then
        echo "No repo named '$name'. Add with repos-desktops.sh add <name> <url>" >&2
        exit 1
      fi
      create_env "$name" "$(repos_get_url "$name")"
      ;;
    list)
      list_envs_pretty
      ;;
    show-path)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 show-path <name>" >&2
        exit 1
      fi
      echo "$(env_path_for "$2")"
      ;;
    shell)
      local name="${2:-}"
      if [[ -z "$name" ]]; then
        echo "Usage: $0 shell <name>" >&2
        exit 1
      fi
      local env_home
      env_home="$(env_path_for "$name")"
      if [[ ! -d "$env_home" ]]; then
        echo "Environment missing at $env_home" >&2
        exit 1
      fi
      echo "Opening shell with HOME=$env_home"
      HOME="$env_home" \
      XDG_CONFIG_HOME="$env_home/.config" \
      XDG_DATA_HOME="$env_home/.local/share" \
      XDG_CACHE_HOME="$env_home/.cache" \
      XDG_STATE_HOME="$env_home/.local/state" \
        "${SHELL:-/bin/bash}" --login
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command>
Commands:
  create [name]   Create isolated home and run installer
  list            List known desktops and fake homes
  show-path <name>
  shell <name>    Open an interactive shell with fake HOME
Environment variables:
  CONFIG_BASE_PREFIX     Prefix for fake homes (default: "$HOME/.")
  GLOBAL_LOG_ROOT        Global logs base (default: "$HOME/.logs-desktops")
  TRACK_SYSTEM_FILES     If "1", also log changes under /etc and /usr/share
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
