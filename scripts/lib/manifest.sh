#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/common.sh"
manifest_builtin_path() { printf '%s/manifests/%s.json\n' "$ID_ROOT" "$1"; }
manifest_override_path() { printf '%s/profiles.d/%s.json\n' "$ID_CONFIG_ROOT" "$1"; }
manifest_cache_dir() { printf '%s/.cache/manifests\n' "$ID_STATE_ROOT"; }
manifest_cache_file() { printf '%s/%s.tsv\n' "$(manifest_cache_dir)" "$1"; }
manifest_path() {
  local name="$1" override builtin
  safe_name "$name"
  override="$(manifest_override_path "$name")"
  builtin="$(manifest_builtin_path "$name")"
  if [[ -f "$override" ]]; then printf '%s\n' "$override"; return 0; fi
  [[ -f "$builtin" ]] || die_with_code "$EX_NOINPUT" "Manifest not found for profile: $name"
  printf '%s\n' "$builtin"
}
manifest_exists() { local name="$1"; safe_name "$name"; [[ -f "$(manifest_override_path "$name")" || -f "$(manifest_builtin_path "$name")" ]]; }
manifest_list_names() {
  { local path; for path in "$ID_ROOT"/manifests/*.json; do [[ -e "$path" ]] || continue; basename "$path" .json; done; for path in "$ID_CONFIG_ROOT"/profiles.d/*.json; do [[ -e "$path" ]] || continue; basename "$path" .json; done; } | sort -u
}
ensure_manifest_cache() {
  local name="$1" src cache
  need_cmd python3
  src="$(manifest_path "$name")"
  cache="$(manifest_cache_file "$name")"
  mkdir -p -- "$(manifest_cache_dir)"
  if [[ -f "$cache" && "$cache" -nt "$src" ]]; then return 0; fi
  python3 - "$src" "$cache" <<'PY'
import json, sys
from pathlib import Path
src = Path(sys.argv[1]); out = Path(sys.argv[2])
data = json.loads(src.read_text(encoding='utf-8'))
lines=[]
def emit(prefix, value):
    if isinstance(value, dict):
        lines.append((prefix, json.dumps(value, ensure_ascii=False)))
        for k, v in value.items():
            emit(prefix + '.' + k if prefix else k, v)
    elif isinstance(value, list):
        lines.append((prefix, json.dumps(value, ensure_ascii=False)))
    elif isinstance(value, bool):
        lines.append((prefix, 'true' if value else 'false'))
    elif value is None:
        lines.append((prefix, ''))
    else:
        lines.append((prefix, str(value)))
for k, v in data.items():
    emit(k, v)
out.write_text(''.join(f"{k}\t{v}\n" for k, v in lines), encoding='utf-8')
PY
}
manifest_get() {
  local name="$1" key="$2" cache value
  ensure_manifest_cache "$name"
  cache="$(manifest_cache_file "$name")"
  value="$(awk -F $'\t' -v k="$key" '$1 == k {sub(/^[^\t]*\t/, ""); print; exit}' "$cache")"
  printf '%s\n' "$value"
}
manifest_array_lines() {
  local name="$1" key="$2" payload
  need_cmd python3
  payload="$(manifest_get "$name" "$key")"
  [[ -n "$payload" ]] || return 0
  python3 - "$payload" <<'PY'
import json, sys
payload=sys.argv[1]
try:
    value=json.loads(payload)
except Exception:
    raise SystemExit(0)
if isinstance(value, list):
    for item in value:
        print(item)
PY
}
manifest_supports_mode() { local name="$1" mode="$2"; manifest_array_lines "$name" supported_modes | grep -Fxq "$mode"; }
manifest_validate() {
  local name="$1" path repo_url adapter display_name session_type default_mode start_command risk
  path="$(manifest_path "$name")"
  display_name="$(manifest_get "$name" display_name)"
  repo_url="$(manifest_get "$name" repo_url)"
  adapter="$(manifest_get "$name" adapter)"
  session_type="$(manifest_get "$name" session_type)"
  default_mode="$(manifest_get "$name" default_mode)"
  start_command="$(manifest_get "$name" start_command)"
  risk="$(manifest_get "$name" risk)"
  [[ -n "$display_name" ]] || die_config "Manifest missing display_name: $path"
  [[ ${#display_name} -le 80 ]] || die_config "Manifest display_name too long: $path"
  validate_git_url "$repo_url"
  safe_name "$adapter"
  [[ -f "$ID_ROOT/scripts/adapters/$adapter.sh" ]] || die_config "Manifest references missing adapter '$adapter': $path"
  [[ "$session_type" == 'wayland' || "$session_type" == 'x11' ]] || die_config "Manifest has invalid session_type '$session_type': $path"
  [[ -n "$start_command" ]] || die_config "Manifest missing start_command: $path"
  manifest_supports_mode "$name" "$default_mode" || die_config "Manifest default_mode '$default_mode' not listed in supported_modes: $path"
  [[ -n "$risk" ]] || die_config "Manifest missing risk field: $path"
}
