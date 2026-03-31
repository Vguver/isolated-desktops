#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
export_profile_env() {
  local name="$1" home profile_runtime
  home="$(profile_home_dir "$name")"; profile_runtime="$(profile_runtime_dir "$name")"
  mkdir -p -- "$profile_runtime" "$home/.config" "$home/.local/share" "$home/.cache" "$home/.local/state"
  export ID_PROFILE_NAME="$name"
  export ID_PROFILE_ROOT="$(profile_dir "$name")"
  export ID_PROFILE_RUNTIME_DIR="$profile_runtime"
  export HOME="$home"
  export XDG_CONFIG_HOME="$home/.config"
  export XDG_DATA_HOME="$home/.local/share"
  export XDG_CACHE_HOME="$home/.cache"
  export XDG_STATE_HOME="$home/.local/state"
  export PATH="$HOME/.local/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"
}
run_in_profile_env() { local name="$1"; shift; export_profile_env "$name"; "$@"; }
run_shell_in_profile() { local name="$1" command_string="$2"; export_profile_env "$name"; bash -c "$command_string"; }
run_profile_command_managed() {
  local name="$1" command_string="$2" log_file child_pid=''
  export_profile_env "$name"
  mkdir -p -- "$(profile_logs_dir "$name")"
  log_file="$(profile_logs_dir "$name")/session-$(date +%Y%m%d-%H%M%S).log"
  rotate_logs_dir "$(profile_logs_dir "$name")" 'session-*.log' "$ID_LOG_KEEP_COUNT"
  cleanup_profile_child() {
    local signal="${1:-TERM}"
    if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
      kill -s "$signal" -- "-$child_pid" 2>/dev/null || kill -s "$signal" "$child_pid" 2>/dev/null || true
      wait "$child_pid" 2>/dev/null || true
    fi
  }
  trap 'cleanup_profile_child TERM' TERM
  trap 'cleanup_profile_child INT' INT
  trap 'cleanup_profile_child HUP' HUP
  if have_cmd setsid; then setsid bash -c "$command_string" >>"$log_file" 2>&1 & else bash -c "$command_string" >>"$log_file" 2>&1 & fi
  child_pid="$!"
  info "Session log: $log_file"
  wait "$child_pid"
}
