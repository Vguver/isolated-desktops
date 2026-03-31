#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/testlib.sh"
setup_test_env
trap teardown_test_env EXIT
LOCAL_REPO="$TEST_ROOT/lifecycle-repo"
mkdir -p "$LOCAL_REPO"
cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/demo"
printf 'version-1\n' > "$HOME/.config/demo/app.conf"
EOS
create_local_git_repo "$LOCAL_REPO"
write_manifest lifecycle-test "file://$LOCAL_REPO" "$(current_branch "$LOCAL_REPO")"
bash "$REPO_ROOT/scripts/commands/bootstrap.sh" >/dev/null
bash "$REPO_ROOT/scripts/commands/install-profile.sh" lifecycle-test >/dev/null
bash "$REPO_ROOT/scripts/commands/create-launcher.sh" lifecycle-test >/dev/null
bash "$REPO_ROOT/scripts/commands/create-session.sh" lifecycle-test --scope user --type wayland >/dev/null
bash "$REPO_ROOT/scripts/commands/verify-profile.sh" lifecycle-test >/dev/null
bash "$REPO_ROOT/scripts/commands/workspace-profile.sh" create lifecycle-test >/dev/null
[[ "$(cat "$ID_STATE_ROOT/profiles/lifecycle-test/home/.config/demo/app.conf")" == 'version-1' ]]
cat > "$LOCAL_REPO/install.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.config/demo"
printf 'version-2\n' > "$HOME/.config/demo/app.conf"
EOS
chmod +x "$LOCAL_REPO/install.sh"
git -C "$LOCAL_REPO" add install.sh >/dev/null
git -C "$LOCAL_REPO" -c user.name='test' -c user.email='test@example.com' commit -m 'update' >/dev/null
bash "$REPO_ROOT/scripts/commands/update-profile.sh" lifecycle-test >/dev/null
[[ "$(cat "$ID_STATE_ROOT/profiles/lifecycle-test/home/.config/demo/app.conf")" == 'version-2' ]]
COMPLETION_FILE="$TEST_ROOT/idtool.bash"
bash "$REPO_ROOT/scripts/commands/completion.sh" install "$COMPLETION_FILE" >/dev/null
grep -q 'complete -F _idtool_complete idtool' "$COMPLETION_FILE"
