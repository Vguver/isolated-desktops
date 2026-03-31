#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
name="${1:-}"
[[ -n "$name" ]] || die_usage "Usage: idtool launcher create <profile>"
safe_name "$name"
require_project_version
manifest_exists "$name" || die_with_code "$EX_NOINPUT" "Unknown profile: $name"
[[ -f "$(profile_meta_file "$name")" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
mkdir -p -- "$ID_USER_BIN"
launcher="$(launcher_path "$name")"
cat > "$launcher" <<EOF2
#!/usr/bin/env bash
exec "$ID_ROOT/scripts/idtool.sh" start "$name" "\$@"
EOF2
chmod +x "$launcher"
info "Launcher created: $launcher"
