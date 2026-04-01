#!/usr/bin/env bash
set -euo pipefail
GITHUB_USER="${GITHUB_USER:-Vguver}"
GITHUB_REPO="${GITHUB_REPO:-isolated-desktops}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
PROJECT_NAME='Isolated Desktops'
PROJECT_VERSION='1.6.1'
DEFAULT_INSTALL_DIR="${INSTALL_DIR:-$HOME/isolated-desktops}"
BOOTSTRAP_MODE=0
INTERACTIVE_MODE=0
DRY_RUN=0
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
(( BASH_VERSINFO[0] >= 4 )) || { printf '[ERROR] Bash 4.0 or newer is required. Current: %s\n' "$BASH_VERSION" >&2; exit 69; }
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"; SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" 2>/dev/null && pwd || pwd)"; SCRIPTS_DIR="$SCRIPT_DIR/scripts"
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then COLOR_RESET="\033[0m"; COLOR_BOLD="\033[1m"; COLOR_RED="\033[31m"; COLOR_GREEN="\033[32m"; COLOR_YELLOW="\033[33m"; COLOR_BLUE="\033[34m"; COLOR_CYAN="\033[36m"; else COLOR_RESET=''; COLOR_BOLD=''; COLOR_RED=''; COLOR_GREEN=''; COLOR_YELLOW=''; COLOR_BLUE=''; COLOR_CYAN=''; fi
print_color() { printf '%b%s%b\n' "$1" "$2" "$COLOR_RESET"; }
info() { print_color "$COLOR_BLUE" "[INFO] $*"; }
warn() { print_color "$COLOR_YELLOW" "[WARN] $*" >&2; }
error() { print_color "$COLOR_RED" "[ERROR] $*" >&2; }
success() { print_color "$COLOR_GREEN" "[OK] $*"; }
print_header() { echo; print_color "$COLOR_BOLD$COLOR_CYAN" '============================================'; print_color "$COLOR_BOLD$COLOR_CYAN" "  $*"; print_color "$COLOR_BOLD$COLOR_CYAN" '============================================'; echo; }
can_prompt() { [[ -t 0 || -r /dev/tty ]]; }
read_input() { local prompt="$1" __var="$2" input=''; if [[ -t 0 ]]; then read -r -p "$prompt" input || return 1; elif [[ -r /dev/tty ]]; then read -r -p "$prompt" input < /dev/tty || return 1; else return 1; fi; printf -v "$__var" '%s' "$input"; }
validate_path() { local path="$1" description="${2:-path}"; [[ -n "$path" ]] || { error "$description cannot be empty"; return 1; }; case "$path" in *$'\n'*|*$'\r'*) error "Invalid $description: contains line breaks"; return 1;; -* ) error "Invalid $description: cannot start with '-'"; return 1;; esac; }
in_local_repo_layout() { [[ -d "$SCRIPTS_DIR" && -x "$SCRIPTS_DIR/idtool.sh" && -f "$SCRIPT_DIR/VERSION" ]]; }
remote_points_to_expected_repo() { local remote_url="$1"; [[ "$remote_url" == *"github.com/${GITHUB_USER}/${GITHUB_REPO}"* ]] || [[ "$remote_url" == *"github.com:${GITHUB_USER}/${GITHUB_REPO}"* ]]; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { error "Required command not found: $1"; return 1; }; }
show_usage() { cat <<EOF2
Usage: $0 [OPTIONS]
  --bootstrap         Force bootstrap mode
  --interactive       Force local interactive mode
  --dry-run           Show bootstrap actions without making changes
  --install-dir PATH  Override bootstrap install directory
  --verbose, -v       Enable verbose shell tracing
  --help, -h          Show this help message
EOF2
}
parse_args() { while [[ $# -gt 0 ]]; do case "$1" in --bootstrap) BOOTSTRAP_MODE=1; INTERACTIVE_MODE=0; shift ;; --interactive) INTERACTIVE_MODE=1; BOOTSTRAP_MODE=0; shift ;; --dry-run) DRY_RUN=1; shift ;; --install-dir) [[ -n "${2:-}" ]] || { error 'Missing value for --install-dir'; exit 64; }; INSTALL_DIR="$2"; shift 2 ;; --verbose|-v) export ID_VERBOSE=1; shift ;; --help|-h) show_usage; exit 0 ;; *) error "Unknown option: $1"; show_usage >&2; exit 64 ;; esac; done; }
detect_mode() { if (( BOOTSTRAP_MODE == 1 || INTERACTIVE_MODE == 1 )); then return 0; fi; if [[ ! -t 0 ]]; then BOOTSTRAP_MODE=1; return 0; fi; if in_local_repo_layout; then INTERACTIVE_MODE=1; INSTALL_DIR="$SCRIPT_DIR"; return 0; fi; BOOTSTRAP_MODE=1; }
ensure_install_parent_dir() { local parent_dir; parent_dir="$(dirname "$INSTALL_DIR")"; validate_path "$parent_dir" 'install directory parent' || return 1; (( DRY_RUN == 1 )) && { info "(dry-run) Would create parent directory: $parent_dir"; return 0; }; mkdir -p -- "$parent_dir"; }
clone_or_update_repo() {
  local current_origin=''
  validate_path "$INSTALL_DIR" 'install directory' || return 1
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Repository found at: $INSTALL_DIR"
    current_origin="$(cd "$INSTALL_DIR" && git remote get-url origin 2>/dev/null || true)"
    [[ -n "$current_origin" ]] || { error "Existing repository has no origin remote: $INSTALL_DIR"; return 1; }
    remote_points_to_expected_repo "$current_origin" || { error 'Existing repository points to a different remote'; printf '  %s\n' "$current_origin" >&2; printf 'Expected: %s\n' "$REPO_URL" >&2; return 1; }
    (( DRY_RUN == 1 )) && { info '(dry-run) Would run: git fetch / git checkout / git pull'; return 0; }
    ( cd "$INSTALL_DIR"; git fetch origin "$GITHUB_BRANCH"; git checkout "$GITHUB_BRANCH"; git pull --ff-only origin "$GITHUB_BRANCH" ) || { error 'Failed to update local repository'; return 1; }
    success 'Repository updated successfully'; return 0
  fi
  [[ ! -e "$INSTALL_DIR" ]] || { error "Install path exists but is not a Git repository: $INSTALL_DIR"; return 1; }
  info "Cloning repository to: $INSTALL_DIR"
  (( DRY_RUN == 1 )) && { info "(dry-run) Would run: git clone --branch $GITHUB_BRANCH $REPO_URL $INSTALL_DIR"; return 0; }
  ensure_install_parent_dir || return 1
  git clone --branch "$GITHUB_BRANCH" -- "$REPO_URL" "$INSTALL_DIR" || { error 'Failed to clone repository'; return 1; }
  success 'Repository cloned successfully'
}
ensure_repo_scripts_executable() { (( DRY_RUN == 1 )) && return 0; chmod +x "$INSTALL_DIR/install.sh" 2>/dev/null || true; find "$INSTALL_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true; }
install_idtool_wrapper() { local wrapper_dir="$HOME/.local/bin" wrapper_path="$wrapper_dir/idtool" ans=''; mkdir -p -- "$wrapper_dir"; if [[ -f "$wrapper_path" ]]; then read_input 'Overwrite existing idtool wrapper? [y/N]: ' ans || return 0; [[ "$ans" =~ ^[Yy]$ ]] || return 0; fi; cat > "$wrapper_path" <<EOF2
#!/usr/bin/env bash
exec "$INSTALL_DIR/scripts/idtool.sh" "\$@"
EOF2
chmod +x "$wrapper_path"; success "Wrapper installed: $wrapper_path"; if [[ ":$PATH:" != *":$wrapper_dir:"* ]]; then warn "$wrapper_dir is not in PATH"; printf 'Add this line to your shell rc:\n  export PATH="%s:$PATH"\n' "$wrapper_dir"; fi; }
show_quick_start_guide() { print_header 'Quick Start Guide'; cat <<EOF2
1. Open the project
   cd $INSTALL_DIR
2. Bootstrap user tools
   ./install.sh --bootstrap
3. Start the tool
   idtool
4. Recommended first commands
   idtool status
   idtool analyze omarchy
   idtool install omarchy
   idtool verify omarchy
   idtool completion install
EOF2
}
run_bootstrap_mode() {
  print_header "$PROJECT_NAME Bootstrap v$PROJECT_VERSION"
  need_cmd bash || exit 69; need_cmd git || exit 69
  clone_or_update_repo || exit 1
  ensure_repo_scripts_executable
  (( DRY_RUN == 1 )) && { info 'Dry-run complete'; exit 0; }
  if ! can_prompt; then show_quick_start_guide; exit 0; fi
  while true; do printf '1) Launch idtool now\n2) Install idtool wrapper\n3) Show quick start guide\n0) Exit\n'; read_input 'Choice: ' choice || choice='0'; case "$choice" in 1) exec "$INSTALL_DIR/scripts/idtool.sh" ;; 2) install_idtool_wrapper ;; 3) show_quick_start_guide ;; 0|'') exit 0 ;; *) warn 'Invalid choice' ;; esac; done
}
run_interactive_mode() { in_local_repo_layout || { error 'Interactive mode must be run from a local project checkout'; exit 66; }; exec "$SCRIPT_DIR/scripts/idtool.sh" "$@"; }
main() { parse_args "$@"; detect_mode; if (( BOOTSTRAP_MODE == 1 )); then run_bootstrap_mode; else run_interactive_mode; fi; }
main "$@"
