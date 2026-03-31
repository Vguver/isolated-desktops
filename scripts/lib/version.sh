#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
require_project_version() {
  local expected
  expected="$(tr -d '[:space:]' < "$ID_ROOT/VERSION" 2>/dev/null || printf 'unknown')"
  if [[ "$expected" == 'unknown' ]]; then
    die_config 'VERSION file missing or unreadable'
  fi
  if [[ "$ID_PROJECT_VERSION" != 'unknown' && "$ID_PROJECT_VERSION" != "$expected" ]]; then
    warn "Loaded project version '$ID_PROJECT_VERSION' but VERSION file says '$expected'"
  fi
}
