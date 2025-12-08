#!/usr/bin/env bash
# repos-desktops.sh
#
# Module to manage desktop/WM repositories used by the isolated desktops system.
# Provides functions to list, add, and query repos.
# Comments are in English for maintainability.

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION FILE
# -------------------------------------------------------------------

# User configuration file. Each line must be valid Bash, for example:
#   REPOS["name"]="https://url.git"
REPOS_CONFIG_FILE="${REPOS_CONFIG_FILE:-"$HOME/.config/desktops-repos.conf"}"
mkdir -p "$(dirname "$REPOS_CONFIG_FILE")"

if [[ ! -f "$REPOS_CONFIG_FILE" ]]; then
  {
    echo '# Desktop repositories configuration for repos-desktops.sh'
    echo '# Format: REPOS["name"]="https://url.git"'
    echo
  } > "$REPOS_CONFIG_FILE"
fi

# -------------------------------------------------------------------
# DEFAULT REPOSITORIES
# -------------------------------------------------------------------

if ! declare -p REPOS &>/dev/null; then
  declare -A REPOS
fi

REPOS["dwm-titus"]="https://github.com/ChrisTitusTech/dwm-titus.git"
REPOS["omarchy"]="https://github.com/basecamp/omarchy.git"
REPOS["jakoolit"]="https://github.com/JaKooLit/Arch-Hyprland.git"
REPOS["ml4w-starter"]="https://github.com/mylinuxforwork/hyprland-starter.git"
REPOS["ml4w-dotfiles"]="https://github.com/mylinuxforwork/dotfiles.git"

# -------------------------------------------------------------------
# LOAD EXTRA REPOSITORIES FROM CONFIG FILE
# -------------------------------------------------------------------

repos_load_extra() {
  if [[ -f "$REPOS_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$REPOS_CONFIG_FILE"
  fi
}
repos_load_extra

# -------------------------------------------------------------------
# PUBLIC FUNCTIONS
# -------------------------------------------------------------------

repos_has() {
  local name="$1"
  [[ -n "${REPOS[$name]+x}" ]]
}

repos_get_url() {
  local name="$1"
  if repos_has "$name"; then
    printf '%s\n' "${REPOS[$name]}"
  else
    return 1
  fi
}

repos_list_names() {
  local name
  for name in "${!REPOS[@]}"; do
    echo "$name"
  done | sort
}

repos_list_pretty() {
  local name
  for name in $(repos_list_names); do
    printf '%-20s -> %s\n' "$name" "${REPOS[$name]}"
  done
}

repos_add() {
  local name="$1"
  local url="$2"

  if [[ -z "$name" || -z "$url" ]]; then
    echo "repos_add: usage: repos_add <name> <git_url>" >&2
    return 1
  fi

  if repos_has "$name"; then
    echo "Warning: repo '$name' already existed, updating URL." >&2
  fi

  REPOS["$name"]="$url"

  {
    echo ""
    echo "# added by repos_add on $(date '+%Y-%m-%d %H:%M:%S')"
    printf 'REPOS["%s"]="%s"\n' "$name" "$url"
  } >> "$REPOS_CONFIG_FILE"

  echo "Added repo '$name' -> $url (saved to $REPOS_CONFIG_FILE)"
}

repos_add_interactive() {
  local name url
  echo "=== Add new desktop repository ==="
  read -r -p "Internal name (e.g. omarchy): " name
  read -r -p "Git repo URL (https://... .git): " url
  [[ -z "$name" || -z "$url" ]] && { echo "Empty field, aborting." >&2; return 1; }
  if [[ "$url" != *"://"* ]]; then
    echo "URL does not look valid. Expect something like https://... or git+ssh://..." >&2
    return 1
  fi
  repos_add "$name" "$url"
}

repos_config_path() {
  printf '%s\n' "$REPOS_CONFIG_FILE"
}

# -------------------------------------------------------------------
# CLI WHEN EXECUTED DIRECTLY
# -------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    list)
      echo "Known repositories:"
      repos_list_pretty
      ;;
    names)
      repos_list_names
      ;;
    get-url)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 get-url <name>" >&2
        exit 1
      fi
      repos_get_url "$2" || {
        echo "No repo named $2" >&2
        exit 1
      }
      ;;
    add)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        echo "Usage: $0 add <name> <url>" >&2
        exit 1
      fi
      repos_add "$2" "$3"
      ;;
    add-interactive)
      repos_add_interactive
      ;;
    config-path)
      repos_config_path
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command>
Commands:
  list                  List all repos (name -> url)
  names                 List only repo names
  get-url <name>        Show URL for a repo
  add <name> <url>      Add a new repo and save it to config
  add-interactive       Interactively add a new repo
  config-path           Show repos config file path
EOF
      ;;
    *)
      echo "Unknown command: $1" >&2
      exit 1
      ;;
  esac
fi
EOF
