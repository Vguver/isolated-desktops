#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/testlib.sh"
run_case() { local name="$1"; echo "[resilience] $name"; "$name"; }
test_install_clone_failure() {
  setup_test_env
  trap teardown_test_env RETURN
  write_manifest broken-repo 'file:///definitely/missing/repo' 'main'
  assert_failure bash "$REPO_ROOT/scripts/commands/install-profile.sh" broken-repo >/dev/null 2>&1
  [[ ! -f "$ID_STATE_ROOT/profiles/broken-repo/meta.json" ]]
}
test_install_disk_guard() {
  setup_test_env
  trap teardown_test_env RETURN
  LOCAL_REPO="$TEST_ROOT/disk-repo"
  mkdir -p "$LOCAL_REPO"
  cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/demo"
printf 'x\n' > "$HOME/.config/demo/app.conf"
EOS
  create_local_git_repo "$LOCAL_REPO"
  write_manifest disk-test "file://$LOCAL_REPO" "$(current_branch "$LOCAL_REPO")"
  cat > "$TEST_BIN/df" <<'EOS'
#!/usr/bin/env bash
printf 'Filesystem 1048576-blocks Used Available Capacity Mounted on\n'
printf '/dev/mock 100 99 1 99%% /\n'
EOS
  chmod +x "$TEST_BIN/df"
  assert_failure bash "$REPO_ROOT/scripts/commands/install-profile.sh" disk-test >/dev/null 2>&1
  [[ ! -d "$ID_STATE_ROOT/profiles/disk-test/repo/.git" ]]
}
test_install_interrupted_rolls_back() {
  setup_test_env
  trap teardown_test_env RETURN
  LOCAL_REPO="$TEST_ROOT/interrupted-repo"
  mkdir -p "$LOCAL_REPO"
  cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
trap 'exit 130' INT TERM
mkdir -p "$HOME/.config/demo"
printf 'begin\n' > "$HOME/.config/demo/app.conf"
sleep 10
printf 'end\n' > "$HOME/.config/demo/app.conf"
EOS
  create_local_git_repo "$LOCAL_REPO"
  write_manifest interrupted-test "file://$LOCAL_REPO" "$(current_branch "$LOCAL_REPO")"
  bash "$REPO_ROOT/scripts/commands/install-profile.sh" interrupted-test >/dev/null 2>&1 &
  pid=$!
  sleep 1
  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  [[ ! -d "$ID_STATE_ROOT/profiles/interrupted-test" ]]
}
test_concurrent_install_locking() {
  setup_test_env
  trap teardown_test_env RETURN
  LOCAL_REPO="$TEST_ROOT/concurrent-repo"
  mkdir -p "$LOCAL_REPO"
  cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/demo"
sleep 4
printf 'done\n' > "$HOME/.config/demo/app.conf"
EOS
  create_local_git_repo "$LOCAL_REPO"
  write_manifest concurrent-test "file://$LOCAL_REPO" "$(current_branch "$LOCAL_REPO")"
  bash "$REPO_ROOT/scripts/commands/install-profile.sh" concurrent-test >/dev/null 2>&1 &
  pid1=$!
  wait_for_path "$ID_STATE_ROOT/locks/concurrent-test.lock" 40 0.1
  if bash "$REPO_ROOT/scripts/commands/install-profile.sh" concurrent-test >/dev/null 2>&1; then
    kill -TERM "$pid1" 2>/dev/null || true
    wait "$pid1" 2>/dev/null || true
    echo 'Expected second concurrent install to fail' >&2
    return 1
  fi
  wait "$pid1"
}
run_case test_install_clone_failure
run_case test_install_disk_guard
run_case test_install_interrupted_rolls_back
run_case test_concurrent_install_locking
