#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
create_custom_manifest() {
  local name="$1" url="$2" path
  safe_name "$name"
  validate_git_url "$url"
  mkdir -p -- "$ID_CONFIG_ROOT/profiles.d"
  path="$(manifest_override_path "$name")"
  cat > "$path" <<EOF2
{
  "name": "$name",
  "display_name": "$name",
  "repo_url": "$url",
  "ref": "main",
  "adapter": "generic-shell",
  "session_type": "wayland",
  "default_mode": "full",
  "supported_modes": ["full"],
  "start_command": "dbus-run-session Hyprland",
  "risk": "unknown",
  "summary": "Custom manifest generated from compatibility add command.",
  "host_changes": ["unknown until adapter is reviewed"],
  "profile_changes": [".config", ".local/share", ".cache", ".local/state"],
  "notes": ["Edit this file and assign a real adapter before trusting it on your host system."]
}
EOF2
  info "Custom manifest created: $path"
}
cmd="${1:-help}"
case "$cmd" in
  list) printf '%-18s %s\n' 'NAME' 'REPO'; printf '%-18s %s\n' '----' '----'; while IFS= read -r name; do printf '%-18s %s\n' "$name" "$(manifest_get "$name" repo_url)"; done < <(manifest_list_names) ;;
  names) manifest_list_names ;;
  count) manifest_list_names | wc -l ;;
  get-url) name="${2:-}"; [[ -n "$name" ]] || die_usage "Usage: $0 get-url <name>"; manifest_get "$name" repo_url ;;
  add) name="${2:-}"; url="${3:-}"; [[ -n "$name" && -n "$url" ]] || die_usage "Usage: $0 add <name> <url>"; create_custom_manifest "$name" "$url" ;;
  add-interactive) prompt_read 'Repository name: ' name || die 'Name required'; prompt_read 'Git repository URL: ' url || die 'URL required'; create_custom_manifest "$name" "$url" ;;
  remove) name="${2:-}"; [[ -n "$name" ]] || die_usage "Usage: $0 remove <name>"; path="$(manifest_override_path "$name")"; [[ -f "$path" ]] || die_with_code "$EX_NOINPUT" "Only custom override manifests can be removed with this command: $path"; rm -f -- "$path"; info "Removed custom manifest: $path" ;;
  config-path) printf '%s\n' "$ID_CONFIG_ROOT/profiles.d" ;;
  help|-h|--help|'') cat <<'EOH'
Compatibility wrapper for the old repos-desktops.sh name.
Commands:
  list
  names
  count
  get-url <name>
  add <name> <url>
  add-interactive
  remove <name>
  config-path
EOH
    ;;
  *) die "Unknown command: $cmd" ;;
esac
