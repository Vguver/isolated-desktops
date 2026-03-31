#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
require_project_version
need_cmds bash git python3
mkdir -p -- "$ID_USER_BIN" "$ID_PROFILES_ROOT" "$ID_CONFIG_ROOT/profiles.d" "$ID_TRASH_ROOT" "$ID_EXPORT_ROOT"
find "$ID_ROOT" -type f \( -name '*.sh' -o -name 'install.sh' \) -exec chmod +x {} +
wrapper="$ID_USER_BIN/idtool"
cat > "$wrapper" <<EOF2
#!/usr/bin/env bash
exec "$ID_ROOT/scripts/idtool.sh" "\$@"
EOF2
chmod +x "$wrapper"
info "Installed wrapper: $wrapper"
info "Profiles root: $ID_PROFILES_ROOT"
info "Custom manifests: $ID_CONFIG_ROOT/profiles.d"
info "Trash root: $ID_TRASH_ROOT"
info "Export root: $ID_EXPORT_ROOT"
if [[ ":$PATH:" != *":$ID_USER_BIN:"* ]]; then warn "$ID_USER_BIN is not in PATH"; printf 'Add this line to your shell rc:\n  export PATH="%s:$PATH"\n' "$ID_USER_BIN"; fi
info 'Next step: idtool status'
