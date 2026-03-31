#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
for manifest in "$REPO_ROOT"/manifests/*.json; do
  python3 -m json.tool "$manifest" >/dev/null
done
