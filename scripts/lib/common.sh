#!/usr/bin/env bash
set -euo pipefail

ID_PROJECT_NAME='isolated-desktops'
ID_VERSION_FILE="${ID_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/VERSION"
ID_PROJECT_VERSION='unknown'
if [[ -f "$ID_VERSION_FILE" ]]; then
  ID_PROJECT_VERSION="$(tr -d '[:space:]' < "$ID_VERSION_FILE" 2>/dev/null || printf 'unknown')"
fi

MAX_NAME_LENGTH="${MAX_NAME_LENGTH:-50}"
ID_LOG_KEEP_COUNT="${ID_LOG_KEEP_COUNT:-20}"
ID_BACKUP_KEEP_COUNT="${ID_BACKUP_KEEP_COUNT:-10}"
ID_TRASH_RETENTION_DAYS="${ID_TRASH_RETENTION_DAYS:-7}"
ID_MIN_INSTALL_FREE_MB="${ID_MIN_INSTALL_FREE_MB:-1024}"
ID_MIN_EXPORT_FREE_MB="${ID_MIN_EXPORT_FREE_MB:-256}"
ID_PROGRESS_BAR_WIDTH="${ID_PROGRESS_BAR_WIDTH:-26}"
ID_VERBOSE="${ID_VERBOSE:-0}"
ID_ENABLE_LOCAL_METRICS="${ID_ENABLE_LOCAL_METRICS:-0}"
ID_LOCK_STALE_SECONDS="${ID_LOCK_STALE_SECONDS:-21600}"
ID_AUTO_REPAIR_LINKS="${ID_AUTO_REPAIR_LINKS:-0}"
ID_TELEMETRY_ENABLED="${ID_TELEMETRY_ENABLED:-0}"
ID_TELEMETRY_URL="${ID_TELEMETRY_URL:-}"
ID_TELEMETRY_TIMEOUT_SECONDS="${ID_TELEMETRY_TIMEOUT_SECONDS:-2}"

EX_USAGE=64
EX_DATAERR=65
EX_NOINPUT=66
EX_UNAVAILABLE=69
EX_SOFTWARE=70
EX_OSERR=71
EX_CANTCREAT=73
EX_IOERR=74
EX_TEMPFAIL=75
EX_NOPERM=77
EX_CONFIG=78

if (( BASH_VERSINFO[0] < 4 )); then
  printf '[ERROR] Bash 4.0 or newer is required. Current: %s\n' "$BASH_VERSION" >&2
  exit "$EX_UNAVAILABLE"
fi

if [[ "$ID_VERBOSE" == '1' ]]; then
  export PS4='+ ${BASH_SOURCE##*/}:${LINENO}: '
  set -x
fi

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
  C_RESET='\033[0m'; C_BOLD='\033[1m'; C_RED='\033[31m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_BLUE='\033[34m'; C_CYAN='\033[36m'
else
  C_RESET=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''
fi

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log_line() { local level="$1" color="$2"; shift 2; printf '%b[%s]%b %s %s\n' "$color" "$level" "$C_RESET" "$(timestamp)" "$*"; }
bold() { printf '%b%s%b\n' "$C_BOLD" "$*" "$C_RESET"; }
info() { log_line 'INFO' "$C_BLUE" "$*"; }
success() { log_line 'OK' "$C_GREEN" "$*"; }
warn() { log_line 'WARN' "$C_YELLOW" "$*" >&2; }
err() { log_line 'ERROR' "$C_RED" "$*" >&2; }
die_with_code() { local code="$1"; shift; err "$*"; exit "$code"; }
die() { die_with_code "$EX_SOFTWARE" "$*"; }
die_usage() { die_with_code "$EX_USAGE" "$*"; }
die_perm() { die_with_code "$EX_NOPERM" "$*"; }
die_config() { die_with_code "$EX_CONFIG" "$*"; }

progress_bar_render() {
  local current="$1" total="$2" width="${3:-$ID_PROGRESS_BAR_WIDTH}" filled empty percent
  if ! [[ "$current" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || (( total <= 0 )); then
    printf ''
    return 0
  fi
  (( current > total )) && current="$total"
  filled=$(( current * width / total ))
  empty=$(( width - filled ))
  percent=$(( current * 100 / total ))
  printf '['
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%*s' "$empty" '' | tr ' ' '-'
  printf '] %3d%%' "$percent"
}
progress_step() {
  local index="$1" total="$2" message="$3"
  if [[ -n "$index" && -n "$total" ]]; then
    info "$(progress_bar_render "$index" "$total") [$index/$total] $message"
  else
    info "$message"
  fi
}
progress_done() { success "$*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }
need_cmd() { local cmd="$1"; have_cmd "$cmd" || die_with_code "$EX_UNAVAILABLE" "Required command not found: $cmd"; }
need_cmds() { local cmd; for cmd in "$@"; do need_cmd "$cmd"; done; }

safe_name() {
  local value="$1"
  [[ -n "$value" ]] || die_usage 'Name cannot be empty'
  [[ ${#value} -le $MAX_NAME_LENGTH ]] || die_usage "Name too long (max $MAX_NAME_LENGTH): $value"
  [[ "$value" =~ ^[a-zA-Z0-9._-]+$ ]] || die_usage "Invalid name: $value"
  [[ "$value" != .* ]] || die_usage "Names cannot start with '.': $value"
}

_validate_no_controls() {
  local value="$1" description="$2"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die_usage "Invalid $description: contains control characters"
}

validate_plain_path() {
  local path="$1" description="${2:-path}"
  [[ -n "$path" ]] || die_usage "$description cannot be empty"
  _validate_no_controls "$path" "$description"
  case "$path" in -* ) die_usage "Invalid $description: cannot start with '-'";; esac
}
validate_directory_path() { local path="$1" description="${2:-directory path}"; validate_plain_path "$path" "$description"; }
validate_relative_path() {
  local path="$1" description="${2:-relative path}"
  validate_plain_path "$path" "$description"
  [[ "$path" != /* ]] || die_usage "Invalid $description: must be relative"
  [[ "$path" != '.' && "$path" != '..' ]] || die_usage "Invalid $description: $path"
  case "/$path/" in *'/../'*|*'//'* ) die_usage "Invalid $description: $path";; esac
}
validate_absolute_path() { local path="$1" description="${2:-absolute path}"; validate_plain_path "$path" "$description"; [[ "$path" == /* ]] || die_usage "Invalid $description: must be absolute"; }
validate_git_url() {
  local url="$1"
  [[ -n "$url" ]] || die_usage 'Git URL cannot be empty'
  _validate_no_controls "$url" 'Git URL'
  [[ "$url" != *' '* && "$url" != *$'\t'* ]] || die_usage 'Invalid Git URL: contains whitespace'
  printf '%s\n' "$url" | grep -Eq '^(https://|http://|git@|ssh://|git://|file://)[^[:space:]]+$' || die_usage "Invalid Git URL: $url"
  [[ "$url" != *';'* && "$url" != *'&'* && "$url" != *'|'* ]] || die_usage 'Invalid Git URL: shell metacharacters are not allowed'
}
sanitize_url() {
  local url="$1"
  python3 - "$url" <<'PY'
import re, sys
url = sys.argv[1]
url = re.sub(r'(https?://[^/@:]+:)([^@/]+)@', r'\1***@', url)
url = re.sub(r'([?&](?:token|access_token|auth|password)=)[^&]+', r'\1***', url)
print(url)
PY
}
can_prompt() { [[ -t 0 || -r /dev/tty ]]; }
prompt_read() {
  local prompt="$1" __var="$2" input=''
  if [[ -t 0 ]]; then
    read -r -p "$prompt" input || return 1
  elif [[ -r /dev/tty ]]; then
    read -r -p "$prompt" input < /dev/tty || return 1
  else
    return 1
  fi
  printf -v "$__var" '%s' "$input"
}
confirm() { local prompt="$1" answer=''; prompt_read "$prompt [y/N]: " answer || return 1; [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; }
append_trap() {
  local handler="$1" signal="$2" current
  current="$(trap -p "$signal" | awk -F"'" '{print $2}')"
  if [[ -z "$current" ]]; then trap "$handler" "$signal"; elif [[ "$current" != *"$handler"* ]]; then trap "$current; $handler" "$signal"; fi
}
mkdirp() { mkdir -p -- "$@"; }
copy_tree() { local src="$1" dst="$2"; [[ -e "$src" ]] || die_with_code "$EX_NOINPUT" "Source path does not exist: $src"; mkdir -p -- "$dst"; if have_cmd rsync; then rsync -a -- "$src"/ "$dst"/; else cp -a -- "$src"/. "$dst"/; fi; }
copy_path_preserve() { local src="$1" dst="$2"; [[ -e "$src" || -L "$src" ]] || die_with_code "$EX_NOINPUT" "Source path does not exist: $src"; mkdir -p -- "$(dirname "$dst")"; rm -rf -- "$dst"; cp -a -- "$src" "$dst"; }
sync_tree() { local src="$1" dst="$2"; [[ -e "$src" ]] || die_with_code "$EX_NOINPUT" "Source path does not exist: $src"; mkdir -p -- "$dst"; if have_cmd rsync; then rsync -a --delete -- "$src"/ "$dst"/; else rm -rf -- "$dst"; mkdir -p -- "$dst"; cp -a -- "$src"/. "$dst"/; fi; }
record_note() { local file="$1"; shift; mkdir -p -- "$(dirname "$file")"; printf '%s\n' "$*" >> "$file"; }
rotate_logs_dir() { local dir="$1" pattern="${2:-*}" keep="${3:-$ID_LOG_KEEP_COUNT}"; [[ -d "$dir" ]] || return 0; mapfile -t _id_rotate_files < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR>'"$keep"' {print $2}'); if [[ ${#_id_rotate_files[@]} -gt 0 ]]; then rm -f -- "${_id_rotate_files[@]}"; fi; }
rotate_named_dirs() { local dir="$1" glob="$2" keep="${3:-$ID_BACKUP_KEEP_COUNT}"; [[ -d "$dir" ]] || return 0; mapfile -t _id_rotate_dirs < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -name "$glob" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR>'"$keep"' {print $2}'); if [[ ${#_id_rotate_dirs[@]} -gt 0 ]]; then rm -rf -- "${_id_rotate_dirs[@]}"; fi; }
remove_path_any() { local path="$1"; [[ -e "$path" || -L "$path" ]] || return 0; rm -rf -- "$path"; }
ID_TEMP_PATHS=()
register_temp_path() { ID_TEMP_PATHS+=("$1"); }
cleanup_temp_paths() { local item; for item in "${ID_TEMP_PATHS[@]:-}"; do [[ -n "$item" ]] || continue; rm -rf -- "$item" 2>/dev/null || true; done; ID_TEMP_PATHS=(); }
enable_temp_cleanup_trap() { append_trap 'cleanup_temp_paths' EXIT; append_trap 'cleanup_temp_paths' INT; append_trap 'cleanup_temp_paths' TERM; append_trap 'cleanup_temp_paths' HUP; }
create_temp_dir() { local path; path="$(mktemp -d 2>/dev/null)" || die_with_code "$EX_CANTCREAT" 'Failed to create temporary directory'; register_temp_path "$path"; printf '%s\n' "$path"; }
create_temp_file() { local path; path="$(mktemp 2>/dev/null)" || die_with_code "$EX_CANTCREAT" 'Failed to create temporary file'; register_temp_path "$path"; printf '%s\n' "$path"; }
require_free_space_mb() {
  local path="$1" required_mb="$2"
  need_cmd df
  validate_directory_path "$path" 'space-check path'
  local available_mb
  available_mb="$(df -Pm "$path" 2>/dev/null | awk 'NR==2 {print $4}')"
  [[ "$available_mb" =~ ^[0-9]+$ ]] || die_with_code "$EX_IOERR" "Could not determine free space for: $path"
  if (( available_mb < required_mb )); then die_with_code "$EX_TEMPFAIL" "Not enough free space under $path. Required: ${required_mb}MB, available: ${available_mb}MB"; fi
}
ensure_sudo_session() { need_cmd sudo; if sudo -n true 2>/dev/null; then return 0; fi; info 'Requesting sudo credentials...'; sudo -v || die_perm 'sudo authentication failed'; }
validate_sudo_session() { need_cmd sudo; sudo -n true 2>/dev/null || die_perm 'sudo credentials are no longer valid; please retry the command'; }
sudo_copy_file() { local src="$1" dst="$2"; ensure_sudo_session; validate_sudo_session; sudo install -m 0644 -- "$src" "$dst"; }
sudo_remove_path() { local path="$1"; ensure_sudo_session; validate_sudo_session; sudo rm -rf -- "$path"; }
is_shell_script_syntax_ok() { local path="$1"; bash -n "$path" >/dev/null 2>&1; }
first_command_word() {
  local command_line="$1"
  if have_cmd python3; then python3 - "$command_line" <<'PY'
import shlex, sys
try:
    argv = shlex.split(sys.argv[1], posix=True)
except Exception:
    argv = []
print(argv[0] if argv else '')
PY
  else printf '%s\n' "${command_line%% *}"; fi
}
default_editor_cmd() { local requested="${1:-}"; if [[ -n "$requested" ]]; then have_cmd "$requested" || die_with_code "$EX_UNAVAILABLE" "Requested editor not found: $requested"; printf '%s\n' "$requested"; return 0; fi; local editor; for editor in "${ID_EDITOR:-}" codium code vscodium; do [[ -n "$editor" ]] || continue; if have_cmd "$editor"; then printf '%s\n' "$editor"; return 0; fi; done; if have_cmd xdg-open; then printf '%s\n' 'xdg-open'; return 0; fi; return 1; }
open_in_editor() { local target="$1" editor="${2:-}"; [[ -e "$target" ]] || die_with_code "$EX_NOINPUT" "Path does not exist: $target"; editor="$(default_editor_cmd "$editor")" || die_with_code "$EX_UNAVAILABLE" 'No supported editor or opener found'; exec "$editor" "$target"; }
metrics_log_local() { [[ "$ID_ENABLE_LOCAL_METRICS" == '1' ]] || return 0; [[ -n "${ID_STATE_ROOT:-}" ]] || return 0; local metrics_dir="$ID_STATE_ROOT/metrics"; mkdir -p -- "$metrics_dir"; printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >> "$metrics_dir/events.log"; }
telemetry_emit() {
  [[ "$ID_TELEMETRY_ENABLED" == '1' ]] || return 0
  [[ -n "$ID_TELEMETRY_URL" ]] || return 0
  have_cmd curl || return 0
  local event="$1" status="${2:-ok}" profile="${3:-}"
  python3 - "$event" "$status" "$profile" "$ID_PROJECT_VERSION" <<'PY' | curl -fsS --max-time "$ID_TELEMETRY_TIMEOUT_SECONDS" -H 'Content-Type: application/json' -d @- "$ID_TELEMETRY_URL" >/dev/null 2>&1 || true
import json, platform, sys
payload = {'event': sys.argv[1], 'status': sys.argv[2], 'profile': sys.argv[3], 'version': sys.argv[4], 'os': platform.system()}
print(json.dumps(payload, separators=(',', ':')))
PY
}
