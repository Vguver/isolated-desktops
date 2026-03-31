#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/version.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
usage() {
  cat <<'EOU'
Usage:
  idtool completion show
  idtool completion install [destination-file]
EOU
}
completion_source_file="$ID_ROOT/scripts/completions/idtool.bash"
[[ -f "$completion_source_file" ]] || die_with_code "$EX_NOINPUT" "Completion source not found: $completion_source_file"
sub="${1:-}"
case "$sub" in
  show) cat "$completion_source_file" ;;
  install)
    require_project_version
    dest="${2:-$HOME/.local/share/bash-completion/completions/idtool}"
    validate_plain_path "$dest" 'completion destination'
    mkdir -p -- "$(dirname "$dest")"
    install -m 0644 -- "$completion_source_file" "$dest"
    success "Installed bash completion: $dest"
    info "Load it with: source $dest"
    ;;
  help|-h|--help|'') usage ;;
  *) usage; exit "$EX_USAGE" ;;
esac
