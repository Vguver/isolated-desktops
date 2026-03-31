#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/testlib.sh"
setup_test_env
trap teardown_test_env EXIT
LOCAL_REPO="$TEST_ROOT/local-repo"
mkdir -p "$LOCAL_REPO"
cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/demo" "$HOME/.local/share/demo"
printf 'hello\n' > "$HOME/.config/demo/app.conf"
printf 'world\n' > "$HOME/.local/share/demo/data.txt"
EOS
create_local_git_repo "$LOCAL_REPO"
write_manifest test-shell "file://$LOCAL_REPO" "$(current_branch "$LOCAL_REPO")"
bash "$REPO_ROOT/scripts/commands/bootstrap.sh" >/dev/null
bash "$REPO_ROOT/scripts/commands/status-profiles.sh" >/dev/null
bash "$REPO_ROOT/scripts/commands/install-profile.sh" test-shell >/dev/null
bash "$REPO_ROOT/scripts/commands/create-launcher.sh" test-shell >/dev/null
bash "$REPO_ROOT/scripts/commands/create-session.sh" test-shell --scope user --type wayland >/dev/null
bash "$REPO_ROOT/scripts/commands/verify-profile.sh" test-shell >/dev/null
bash "$REPO_ROOT/scripts/commands/links-profile.sh" adopt test-shell .config .local/share >/dev/null
bash "$REPO_ROOT/scripts/commands/workspace-profile.sh" create test-shell >/dev/null
bash "$REPO_ROOT/scripts/commands/sync-profile.sh" test-shell >/dev/null
EXPORT_FILE="$TEST_ROOT/test-shell-export.tar.gz"
bash "$REPO_ROOT/scripts/commands/export-profile.sh" test-shell "$EXPORT_FILE" >/dev/null
bash "$REPO_ROOT/scripts/commands/remove-profile.sh" test-shell --purge --yes >/dev/null
bash "$REPO_ROOT/scripts/commands/import-profile.sh" "$EXPORT_FILE" test-shell-copy >/dev/null
bash "$REPO_ROOT/scripts/commands/status-profiles.sh" >/dev/null
bash "$REPO_ROOT/scripts/commands/trash-profile.sh" list >/dev/null
