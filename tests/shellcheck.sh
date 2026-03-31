#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed; skipping shellcheck step."
  exit 0
fi
find "$REPO_ROOT" -type f -name '*.sh' -print0 | xargs -0 shellcheck -x
