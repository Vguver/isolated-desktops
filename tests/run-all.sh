#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/manifests.sh"
bash "$SCRIPT_DIR/shellcheck.sh"
bash "$SCRIPT_DIR/smoke.sh"
bash "$SCRIPT_DIR/install_resilience.sh"
exec bash "$SCRIPT_DIR/lifecycle.sh"
