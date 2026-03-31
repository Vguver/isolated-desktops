#!/usr/bin/env bash
set -euo pipefail
TEST_ROOT=''
TEST_BIN=''
setup_test_env() {
  TEST_ROOT="$(mktemp -d)"
  export TEST_ROOT
  export HOME="$TEST_ROOT/home"
  export ID_STATE_ROOT="$TEST_ROOT/state"
  export ID_CONFIG_ROOT="$TEST_ROOT/config"
  export ID_USER_BIN="$TEST_ROOT/bin"
  export ID_USER_XSESSIONS="$TEST_ROOT/xsessions"
  export ID_USER_WSESSIONS="$TEST_ROOT/wayland-sessions"
  export ID_TMP_ROOT="$TEST_ROOT/tmp"
  TEST_BIN="$TEST_ROOT/test-bin"
  export TEST_BIN
  mkdir -p "$HOME" "$ID_CONFIG_ROOT/profiles.d" "$ID_USER_BIN" "$ID_USER_XSESSIONS" "$ID_USER_WSESSIONS" "$ID_TMP_ROOT" "$TEST_BIN"
  export PATH="$TEST_BIN:/usr/local/bin:/usr/bin:/bin"
}
teardown_test_env() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
  TEST_ROOT=''
  TEST_BIN=''
  return 0
}
create_local_git_repo() {
  local repo_path="$1"
  mkdir -p "$repo_path"
  git -C "$TEST_ROOT" init -b main "$repo_path" >/dev/null 2>&1 || git -C "$TEST_ROOT" init "$repo_path" >/dev/null 2>&1
  chmod +x "$repo_path/install.sh"
  git -C "$repo_path" add install.sh >/dev/null
  git -C "$repo_path" -c user.name='test' -c user.email='test@example.com' commit -m 'init' >/dev/null
}
current_branch() { git -C "$1" branch --show-current; }
write_manifest() {
  local name="$1" repo_url="$2" ref="$3" start_command="${4:-/bin/true}"
  cat > "$ID_CONFIG_ROOT/profiles.d/$name.json" <<EOF2
{
  "name": "$name",
  "display_name": "$name",
  "repo_url": "$repo_url",
  "ref": "$ref",
  "adapter": "generic-shell",
  "session_type": "wayland",
  "default_mode": "full",
  "supported_modes": ["full"],
  "start_command": "$start_command",
  "risk": "low",
  "summary": "Local test manifest",
  "host_changes": [],
  "profile_changes": [".config", ".local/share"],
  "notes": []
}
EOF2
}
assert_success() { "$@"; }
assert_failure() { if "$@"; then echo "Expected failure but command succeeded: $*" >&2; return 1; fi; }
wait_for_path() { local path="$1" retries="${2:-40}" delay="${3:-0.1}" i; for ((i=0; i<retries; i++)); do [[ -e "$path" || -L "$path" ]] && return 0; sleep "$delay"; done; return 1; }
