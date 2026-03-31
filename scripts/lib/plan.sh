#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/manifest.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"

print_plan() {
  local name="$1"
  local mode="$2"
  local adapter risk summary repo_url ref session_type start_command

  adapter="$(manifest_get "$name" adapter)"
  risk="$(manifest_get "$name" risk)"
  summary="$(manifest_get "$name" summary)"
  repo_url="$(manifest_get "$name" repo_url)"
  ref="$(manifest_get "$name" ref)"
  session_type="$(manifest_get "$name" session_type)"
  start_command="$(manifest_get "$name" start_command)"

  printf 'Profile: %s
' "$name"
  printf 'Display: %s
' "$(manifest_get "$name" display_name)"
  printf 'Mode: %s
' "$mode"
  printf 'Adapter: %s
' "$adapter"
  printf 'Risk: %s
' "$risk"
  printf 'Repo: %s
' "$repo_url"
  printf 'Ref: %s
' "$ref"
  printf 'Session type: %s
' "$session_type"
  printf 'Start command: %s
' "$start_command"
  printf 'Profile home: %s
' "$(profile_home_dir "$name")"
  printf 'Repo dir: %s
' "$(profile_repo_dir "$name")"
  printf 'Summary: %s
' "$summary"
  echo
  echo 'Likely host changes:'
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  - %s
' "$line"
  done < <(manifest_array_lines "$name" host_changes)
  echo
  echo 'Likely profile changes:'
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  - %s
' "$line"
  done < <(manifest_array_lines "$name" profile_changes)
  echo
  echo 'Notes:'
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  - %s
' "$line"
  done < <(manifest_array_lines "$name" notes)
}
