#!/usr/bin/env bash
# install.sh
#
# Hybrid entrypoint for isolated-desktops.
#
# This script supports two execution modes:
#   1. Bootstrap mode   - clone/update the repository and optionally install idtool
#   2. Interactive mode - launch the full local menu from the project root
#
# Typical usage:
#   curl -fsSL https://raw.githubusercontent.com/Vguver/isolated-desktops/main/install.sh | bash
#   ./install.sh
#
# Version: 1.0
# Author: Vguver
# License: MIT

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

GITHUB_USER="${GITHUB_USER:-"Vguver"}"
GITHUB_REPO="${GITHUB_REPO:-"isolated-desktops"}"
GITHUB_BRANCH="${GITHUB_BRANCH:-"main"}"
REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
DEFAULT_INSTALL_DIR="${INSTALL_DIR:-"$HOME/isolated-desktops"}"

PROJECT_NAME="Isolated Desktops"
PROJECT_VERSION="2.4"
PROJECT_URL="https://github.com/Vguver/isolated-desktops"

BOOTSTRAP_MODE=0
INTERACTIVE_MODE=0
DRY_RUN=0
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

# -------------------------------------------------------------------
# RUNTIME PATHS
# -------------------------------------------------------------------

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" 2>/dev/null && pwd || pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Paths shown in system information during interactive mode
CONFIG_BASE_PREFIX="${CONFIG_BASE_PREFIX:-"$HOME/."}"
DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"
START_SCRIPTS_DIR="${START_SCRIPTS_DIR:-"/usr/local/bin"}"
XSESSIONS_DIR="${XSESSIONS_DIR:-"/usr/share/xsessions"}"
WAYLAND_SESSIONS_DIR="${WAYLAND_SESSIONS_DIR:-"/usr/share/wayland-sessions"}"

# -------------------------------------------------------------------
# COLORS AND FORMATTING
# -------------------------------------------------------------------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
  COLOR_RESET="\033[0m"
  COLOR_BOLD="\033[1m"
  COLOR_RED="\033[31m"
  COLOR_GREEN="\033[32m"
  COLOR_YELLOW="\033[33m"
  COLOR_BLUE="\033[34m"
  COLOR_CYAN="\033[36m"
else
  COLOR_RESET=""
  COLOR_BOLD=""
  COLOR_RED=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_CYAN=""
fi

# -------------------------------------------------------------------
# OUTPUT HELPERS
# -------------------------------------------------------------------

clear_screen() {
  if [[ -t 1 ]] && command -v clear >/dev/null 2>&1; then
    clear
  fi
}

print_color() {
  local color="$1"
  shift
  printf "%b%s%b\n" "$color" "$*" "$COLOR_RESET"
}

print_header() {
  echo ""
  print_color "$COLOR_BOLD$COLOR_CYAN" "============================================"
  print_color "$COLOR_BOLD$COLOR_CYAN" "  $*"
  print_color "$COLOR_BOLD$COLOR_CYAN" "============================================"
  echo ""
}

log() {
  print_color "$COLOR_BLUE" "[INFO] $*"
}

warn() {
  print_color "$COLOR_YELLOW" "[WARN] $*" >&2
}

error() {
  print_color "$COLOR_RED" "[ERROR] $*" >&2
}

success() {
  print_color "$COLOR_GREEN" "[SUCCESS] $*"
}

# -------------------------------------------------------------------
# INPUT HELPERS
# -------------------------------------------------------------------

can_prompt() {
  [[ -t 0 ]] || [[ -r /dev/tty ]]
}

read_input() {
  local prompt="$1"
  local __resultvar="$2"
  local input=""

  if ! can_prompt; then
    printf -v "$__resultvar" ""
    return 1
  fi

  if [[ -t 0 ]]; then
    read -r -p "$prompt" input
  else
    read -r -p "$prompt" input < /dev/tty
  fi

  printf -v "$__resultvar" '%s' "$input"
  return 0
}

press_enter() {
  local _unused=""
  if can_prompt; then
    echo ""
    read_input "Press Enter to continue..." _unused || true
  fi
}

# -------------------------------------------------------------------
# VALIDATION HELPERS
# -------------------------------------------------------------------

validate_name() {
  local name="$1"

  if [[ -z "$name" ]]; then
    error "Name cannot be empty"
    return 1
  fi

  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Invalid name: $name"
    log "Allowed characters: letters, numbers, dash (-), underscore (_)"
    return 1
  fi

  if [[ ${#name} -gt 50 ]]; then
    error "Name too long (max 50 characters): $name"
    return 1
  fi

  return 0
}

validate_path() {
  local path="$1"
  local description="${2:-path}"

  if [[ -z "$path" ]]; then
    error "$description cannot be empty"
    return 1
  fi

  if [[ "$path" == *$'\n'* || "$path" == *$'\r'* ]]; then
    error "Invalid $description: contains line breaks"
    return 1
  fi

  return 0
}

prompt_desktop_name() {
  local prompt="${1:-Desktop name: }"
  local name=""

  if ! read_input "$prompt" name; then
    return 1
  fi

  if ! validate_name "$name"; then
    return 1
  fi

  printf '%s\n' "$name"
  return 0
}

# -------------------------------------------------------------------
# SYSTEM HELPERS
# -------------------------------------------------------------------

in_local_repo_layout() {
  [[ -d "$SCRIPTS_DIR" && -f "$SCRIPTS_DIR/setup_desktops.sh" && -f "$SCRIPT_DIR/install.sh" ]]
}

remote_points_to_expected_repo() {
  local remote_url="$1"

  [[ "$remote_url" == *"github.com/${GITHUB_USER}/${GITHUB_REPO}"* ]] || \
  [[ "$remote_url" == *"github.com:${GITHUB_USER}/${GITHUB_REPO}"* ]]
}

check_bootstrap_requirements() {
  local missing=()
  local cmd

  log "Checking bootstrap requirements..."

  for cmd in bash git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required commands: ${missing[*]}"
    error "Please install them and try again"
    return 1
  fi

  success "Bootstrap requirements satisfied"
  return 0
}

# -------------------------------------------------------------------
# BOOTSTRAP MODE FUNCTIONS
# -------------------------------------------------------------------

ensure_install_parent_dir() {
  local parent_dir
  parent_dir="$(dirname "$INSTALL_DIR")"

  if ! validate_path "$parent_dir" "install directory parent"; then
    return 1
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log "(dry-run) Would create parent directory: $parent_dir"
    return 0
  fi

  if ! mkdir -p "$parent_dir"; then
    error "Failed to create parent directory: $parent_dir"
    return 1
  fi

  return 0
}

clone_or_update_repo() {
  local current_origin=""

  if ! validate_path "$INSTALL_DIR" "install directory"; then
    return 1
  fi

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "Repository found at: $INSTALL_DIR"
    log "Updating repository..."

    current_origin="$(cd "$INSTALL_DIR" && git remote get-url origin 2>/dev/null || true)"

    if [[ -z "$current_origin" ]]; then
      error "Existing repository has no 'origin' remote: $INSTALL_DIR"
      return 1
    fi

    if ! remote_points_to_expected_repo "$current_origin"; then
      error "Existing repository points to a different remote:"
      echo "  $current_origin" >&2
      echo "Expected repository: $REPO_URL" >&2
      return 1
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
      log "(dry-run) Would run: git fetch / git checkout / git pull"
      return 0
    fi

    if ! (
      cd "$INSTALL_DIR" || exit 1
      git fetch origin "$GITHUB_BRANCH"
      git checkout "$GITHUB_BRANCH"
      git pull --ff-only origin "$GITHUB_BRANCH"
    ); then
      error "Failed to update repository at: $INSTALL_DIR"
      return 1
    fi

    success "Repository updated successfully"
    return 0
  fi

  if [[ -e "$INSTALL_DIR" ]]; then
    error "Install path exists but is not a Git repository: $INSTALL_DIR"
    error "Choose a different INSTALL_DIR or remove the existing path"
    return 1
  fi

  log "Cloning repository..."
  log "URL: $REPO_URL"
  log "Destination: $INSTALL_DIR"

  if [[ $DRY_RUN -eq 1 ]]; then
    log "(dry-run) Would run: git clone --branch $GITHUB_BRANCH $REPO_URL $INSTALL_DIR"
    return 0
  fi

  if ! ensure_install_parent_dir; then
    return 1
  fi

  if ! git clone --branch "$GITHUB_BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
    error "Failed to clone repository"
    return 1
  fi

  success "Repository cloned successfully"
  return 0
}

ensure_repo_scripts_executable() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "(dry-run) Would make project scripts executable"
    return 0
  fi

  if [[ ! -d "$INSTALL_DIR" ]]; then
    warn "Install directory not found: $INSTALL_DIR"
    return 1
  fi

  chmod +x "$INSTALL_DIR/install.sh" 2>/dev/null || true

  if [[ -d "$INSTALL_DIR/scripts" ]]; then
    chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true
  fi

  return 0
}

install_idtool_wrapper() {
  local wrapper_dir wrapper_path ans

  wrapper_dir="$HOME/.local/bin"
  wrapper_path="$wrapper_dir/idtool"

  echo ""
  log "Installing idtool wrapper..."

  if [[ -f "$wrapper_path" ]]; then
    log "Wrapper already exists: $wrapper_path"

    if ! read_input "Overwrite existing wrapper? [y/N]: " ans; then
      log "Skipping wrapper installation"
      return 0
    fi

    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
      log "Skipping wrapper installation"
      return 0
    fi
  fi

  if ! mkdir -p "$wrapper_dir"; then
    error "Failed to create directory: $wrapper_dir"
    return 1
  fi

  cat > "$wrapper_path" <<EOF
#!/usr/bin/env bash
"$INSTALL_DIR/install.sh" "\$@"
EOF

  if ! chmod +x "$wrapper_path"; then
    error "Failed to make wrapper executable"
    return 1
  fi

  success "Wrapper installed: $wrapper_path"

  if [[ ":$PATH:" != *":$wrapper_dir:"* ]]; then
    echo ""
    warn "$wrapper_dir is not in your PATH"
    echo "Add this line to your shell config (~/.bashrc or ~/.zshrc):"
    echo ""
    echo "  export PATH=\"$HOME/.local/bin:\$PATH\""
    echo ""
  else
    success "You can now launch the tool with: idtool"
  fi

  return 0
}

show_quick_start_guide() {
  print_header "Quick Start Guide"

  cat <<EOF
${COLOR_BOLD}1. Open the project${COLOR_RESET}
   cd $INSTALL_DIR

${COLOR_BOLD}2. Run the main menu${COLOR_RESET}
   ./install.sh

${COLOR_BOLD}3. Recommended first workflow${COLOR_RESET}
   - Option 21: Quick setup
   - Or run the steps manually from the menu

${COLOR_BOLD}Need help?${COLOR_RESET}
   - Documentation: $PROJECT_URL
   - Issues: $PROJECT_URL/issues

EOF
}

bootstrap_main_menu() {
  local choice

  while true; do
    print_header "Bootstrap Complete"

    cat <<EOF
${COLOR_GREEN}SUCCESS${COLOR_RESET} Repository ready at: ${COLOR_CYAN}$INSTALL_DIR${COLOR_RESET}

${COLOR_BOLD}What would you like to do now?${COLOR_RESET}

  1) Launch interactive menu now
  2) Install idtool wrapper
  3) Show quick start guide
  0) Exit

EOF

    if ! read_input "Choice: " choice; then
      choice="0"
    fi

    case "$choice" in
      1)
        log "Launching interactive menu..."
        if [[ -r /dev/tty ]]; then
          exec < /dev/tty > /dev/tty 2>&1 "$INSTALL_DIR/install.sh" --interactive
        else
          exec "$INSTALL_DIR/install.sh" --interactive
        fi
        ;;
      2)
        install_idtool_wrapper
        press_enter
        ;;
      3)
        show_quick_start_guide
        press_enter
        ;;
      0|"")
        echo ""
        log "Bootstrap finished"
        log "Run '$INSTALL_DIR/install.sh' when you want to start"
        echo ""
        exit 0
        ;;
      *)
        warn "Invalid choice"
        press_enter
        ;;
    esac
  done
}

run_bootstrap_mode() {
  print_header "$PROJECT_NAME Bootstrap"

  if ! check_bootstrap_requirements; then
    exit 1
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log "Running in dry-run mode"
  fi

  if ! clone_or_update_repo; then
    exit 1
  fi

  ensure_repo_scripts_executable || true

  if [[ $DRY_RUN -eq 1 ]]; then
    log "Dry-run complete"
    exit 0
  fi

  if ! can_prompt; then
    echo ""
    log "Bootstrap completed in non-interactive mode"
    show_quick_start_guide
    exit 0
  fi

  bootstrap_main_menu
}

# -------------------------------------------------------------------
# INTERACTIVE MODE FUNCTIONS
# -------------------------------------------------------------------

check_script() {
  local script="$1"
  local path="$SCRIPTS_DIR/$script"

  if [[ ! -f "$path" ]]; then
    error "Required script not found: $path"
    return 1
  fi

  if [[ ! -x "$path" ]]; then
    warn "Script is not executable: $path"
    log "Trying to make it executable..."
    if ! chmod +x "$path"; then
      error "Failed to make script executable: $path"
      return 1
    fi
  fi

  return 0
}

run_script() {
  local script="$1"
  shift

  if ! check_script "$script"; then
    return 1
  fi

  "$SCRIPTS_DIR/$script" "$@"
}

desktop_exists_in_repos() {
  local name="$1"
  run_script "repos-desktops.sh" get-url "$name" >/dev/null 2>&1
}

show_main_menu() {
  clear_screen
  print_header "$PROJECT_NAME v$PROJECT_VERSION"

  cat <<EOF
${COLOR_BOLD}MAIN MENU${COLOR_RESET}

${COLOR_CYAN}Desktop Management:${COLOR_RESET}
  1) Install isolated desktop environment
  2) List installed desktops
  3) Remove desktop environment
  4) Open desktop shell

${COLOR_CYAN}Launch Scripts:${COLOR_RESET}
  5) Create launch script
  6) List launch scripts
  7) Remove launch script

${COLOR_CYAN}Display Manager Sessions:${COLOR_RESET}
  8) Create session file
  9) List session files
  10) Remove session file

${COLOR_CYAN}Dotfiles Management:${COLOR_RESET}
  11) Prepare dotfiles structure
  12) Link dotfiles to fake HOME
  13) Adopt existing config
  14) Show dotfiles status

${COLOR_CYAN}Development Tools:${COLOR_RESET}
  15) Open in editor (VS Code/VSCodium)
  16) Create Git snapshot
  17) Show Git status

${COLOR_CYAN}Repository Management:${COLOR_RESET}
  18) List available desktops
  19) Add new desktop repository
  20) Remove desktop repository

${COLOR_CYAN}Other:${COLOR_RESET}
  21) Quick setup (full workflow)
  22) System information
  23) Help & Documentation

  0) Exit

EOF
}

# -------------------------------------------------------------------
# MENU IMPLEMENTATIONS
# -------------------------------------------------------------------

menu_install_desktop() {
  print_header "Install Isolated Desktop"

  if ! run_script "setup_desktops.sh" create; then
    error "Desktop installation failed"
  fi

  press_enter
}

menu_list_desktops() {
  print_header "Installed Desktops"

  if ! run_script "setup_desktops.sh" list; then
    error "Failed to list installed desktops"
  fi

  press_enter
}

menu_remove_desktop() {
  local name

  print_header "Remove Desktop Environment"

  if ! run_script "setup_desktops.sh" list; then
    error "Failed to list installed desktops"
    press_enter
    return 1
  fi

  echo ""
  if ! name="$(prompt_desktop_name "Desktop name to remove: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "setup_desktops.sh" remove "$name"; then
    error "Failed to remove desktop environment: $name"
  fi

  press_enter
}

menu_open_shell() {
  local name

  print_header "Open Desktop Shell"

  if ! run_script "setup_desktops.sh" list; then
    error "Failed to list installed desktops"
    press_enter
    return 1
  fi

  echo ""
  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "setup_desktops.sh" shell "$name"; then
    error "Failed to open shell for: $name"
  fi

  press_enter
}

menu_create_launch() {
  print_header "Create Launch Script"

  if ! run_script "desktop-launch.sh" create-interactive; then
    error "Failed to create launch script"
  fi

  press_enter
}

menu_list_launch() {
  print_header "Launch Scripts"

  if ! run_script "desktop-launch.sh" list; then
    error "Failed to list launch scripts"
  fi

  press_enter
}

menu_remove_launch() {
  local name

  print_header "Remove Launch Script"

  if ! run_script "desktop-launch.sh" list; then
    error "Failed to list launch scripts"
    press_enter
    return 1
  fi

  echo ""
  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "desktop-launch.sh" remove "$name"; then
    error "Failed to remove launch script for: $name"
  fi

  press_enter
}

menu_create_session() {
  print_header "Create Display Manager Session"

  if ! run_script "desktop-sessions.sh" create-interactive; then
    error "Failed to create session file"
  fi

  press_enter
}

menu_list_sessions() {
  print_header "Display Manager Sessions"

  if ! run_script "desktop-sessions.sh" list; then
    error "Failed to list session files"
  fi

  press_enter
}

menu_remove_session() {
  local name

  print_header "Remove Session File"

  if ! run_script "desktop-sessions.sh" list; then
    error "Failed to list session files"
    press_enter
    return 1
  fi

  echo ""
  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "desktop-sessions.sh" remove "$name"; then
    error "Failed to remove session file for: $name"
  fi

  press_enter
}

menu_prepare_dotfiles() {
  local name

  print_header "Prepare Dotfiles Structure"

  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "dotfiles-link.sh" prepare "$name"; then
    error "Failed to prepare dotfiles structure for: $name"
  fi

  press_enter
}

menu_link_dotfiles() {
  local name

  print_header "Link Dotfiles"

  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "dotfiles-link.sh" link-config "$name"; then
    error "Failed to link dotfiles for: $name"
  fi

  press_enter
}

menu_adopt_config() {
  local name

  print_header "Adopt Existing Config"

  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "dotfiles-link.sh" adopt-config "$name"; then
    error "Failed to adopt config for: $name"
  fi

  press_enter
}

menu_dotfiles_status() {
  print_header "Dotfiles Status"

  if ! run_script "dotfiles-link.sh" status; then
    error "Failed to show dotfiles status"
  fi

  press_enter
}

menu_open_editor() {
  print_header "Open in Editor"

  if ! run_script "dev-open.sh" interactive; then
    error "Failed to open editor"
  fi

  press_enter
}

menu_git_snapshot() {
  print_header "Create Git Snapshot"

  if ! run_script "dev-sync.sh" snapshot-interactive; then
    error "Failed to create Git snapshot"
  fi

  press_enter
}

menu_git_status() {
  local name

  print_header "Git Status"

  if ! name="$(prompt_desktop_name "Desktop name: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "dev-sync.sh" status "$name"; then
    error "Failed to show Git status for: $name"
  fi

  press_enter
}

menu_list_repos() {
  print_header "Available Desktop Repositories"

  if ! run_script "repos-desktops.sh" list; then
    error "Failed to list repositories"
  fi

  press_enter
}

menu_add_repo() {
  print_header "Add Desktop Repository"

  if ! run_script "repos-desktops.sh" add-interactive; then
    error "Failed to add repository"
  fi

  press_enter
}

menu_remove_repo() {
  local name

  print_header "Remove Desktop Repository"

  if ! run_script "repos-desktops.sh" list; then
    error "Failed to list repositories"
    press_enter
    return 1
  fi

  echo ""
  if ! name="$(prompt_desktop_name "Repository name to remove: ")"; then
    press_enter
    return 1
  fi

  if ! run_script "repos-desktops.sh" remove "$name"; then
    error "Failed to remove repository: $name"
  fi

  press_enter
}

menu_quick_setup() {
  local name ans session_choice

  print_header "Quick Setup - Full Workflow"

  cat <<EOF
This workflow will guide you through:
  1. Installing a desktop environment
  2. Adopting existing config (optional)
  3. Creating a launch script
  4. Creating a display manager session

${COLOR_YELLOW}Note:${COLOR_RESET} Make sure the target desktop exists in the repository list
      (Repository Management -> Add new desktop repository)

EOF

  if ! name="$(prompt_desktop_name "Desktop name to install: ")"; then
    press_enter
    return 1
  fi

  if ! desktop_exists_in_repos "$name"; then
    error "Desktop '$name' is not registered in repository definitions"
    log "Add it first from: Repository Management -> Add new desktop repository"
    press_enter
    return 1
  fi

  if ! read_input "Continue? [Y/n]: " ans; then
    return 0
  fi

  if [[ "$ans" =~ ^[Nn]$ ]]; then
    return 0
  fi

  # Step 1: Install selected desktop
  echo ""
  log "Step 1/4: Installing desktop environment..."
  if ! run_script "setup_desktops.sh" create "$name"; then
    error "Installation failed for: $name"
    press_enter
    return 1
  fi

  # Step 2: Adopt config
  echo ""
  log "Step 2/4: Adopting configuration..."
  if ! read_input "Adopt existing config? [Y/n]: " ans; then
    ans="n"
  fi

  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    if ! run_script "dotfiles-link.sh" adopt-config "$name"; then
      warn "Config adoption failed or was skipped"
    fi
  else
    log "Skipping config adoption"
  fi

  # Step 3: Create launch script
  echo ""
  log "Step 3/4: Creating launch script..."
  if ! run_script "desktop-launch.sh" create "$name"; then
    warn "Launch script creation failed, continuing anyway"
  fi

  # Step 4: Create session file
  echo ""
  log "Step 4/4: Creating display manager session..."
  cat <<EOF
  1) X11
  2) Wayland
  3) Both
  0) Skip

EOF

  if ! read_input "Choice [0-3]: " session_choice; then
    session_choice="0"
  fi

  case "$session_choice" in
    1)
      if ! run_script "desktop-sessions.sh" create-x "$name" "$name"; then
        warn "Failed to create X11 session"
      fi
      ;;
    2)
      if ! run_script "desktop-sessions.sh" create-wayland "$name" "$name"; then
        warn "Failed to create Wayland session"
      fi
      ;;
    3)
      if ! run_script "desktop-sessions.sh" create-x "$name" "$name"; then
        warn "Failed to create X11 session"
      fi
      echo ""
      if ! run_script "desktop-sessions.sh" create-wayland "$name" "$name"; then
        warn "Failed to create Wayland session"
      fi
      ;;
    0|"")
      log "Skipping session file creation"
      ;;
    *)
      warn "Invalid choice. Skipping session file creation"
      ;;
  esac

  echo ""
  success "Quick setup finished for: $name"
  echo ""
  log "Next steps:"
  echo "  1. Restart your display manager (or reboot)"
  echo "  2. Select '$name (Isolated)' from the login screen"
  echo "  3. Log in and test your desktop"
  echo ""

  press_enter
}

menu_system_info() {
  local deps opt_deps dep ver

  print_header "System Information"

  echo "${COLOR_BOLD}Project:${COLOR_RESET}"
  echo "  Name:       $PROJECT_NAME"
  echo "  Version:    $PROJECT_VERSION"
  echo "  URL:        $PROJECT_URL"
  echo ""

  echo "${COLOR_BOLD}Paths:${COLOR_RESET}"
  echo "  Project:    $SCRIPT_DIR"
  echo "  Scripts:    $SCRIPTS_DIR"
  echo "  Config:     $CONFIG_BASE_PREFIX"
  echo "  Dotfiles:   $DOTFILES_ROOT"
  echo "  Launches:   $START_SCRIPTS_DIR"
  echo "  X11:        $XSESSIONS_DIR"
  echo "  Wayland:    $WAYLAND_SESSIONS_DIR"
  echo ""

  echo "${COLOR_BOLD}Dependencies:${COLOR_RESET}"
  deps=("bash" "git" "curl")
  for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
      ver="$("$dep" --version 2>/dev/null | head -n1 || echo "unknown")"
      printf "  %-10s %b %s\n" "$dep" "${COLOR_GREEN}OK${COLOR_RESET}" "$ver"
    else
      printf "  %-10s %b\n" "$dep" "${COLOR_RED}MISSING${COLOR_RESET}"
    fi
  done
  echo ""

  echo "${COLOR_BOLD}Optional:${COLOR_RESET}"
  opt_deps=("code" "codium" "vscodium" "fzf" "pacman")
  for dep in "${opt_deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
      printf "  %-10s %b\n" "$dep" "${COLOR_GREEN}OK${COLOR_RESET}"
    else
      printf "  %-10s %b\n" "$dep" "${COLOR_YELLOW}NOT INSTALLED${COLOR_RESET}"
    fi
  done

  echo ""
  press_enter
}

menu_help() {
  print_header "Help & Documentation"

  cat <<EOF
${COLOR_BOLD}DOCUMENTATION${COLOR_RESET}

For detailed documentation, visit:
  $PROJECT_URL

${COLOR_BOLD}QUICK START${COLOR_RESET}

1. Add a desktop repository (if needed):
   ${COLOR_CYAN}Repository Management -> Add new desktop repository${COLOR_RESET}

2. Install a desktop:
   ${COLOR_CYAN}Desktop Management -> Install isolated desktop environment${COLOR_RESET}

3. Create launch script:
   ${COLOR_CYAN}Launch Scripts -> Create launch script${COLOR_RESET}

4. Create session file:
   ${COLOR_CYAN}Display Manager Sessions -> Create session file${COLOR_RESET}

5. Restart display manager and log in

${COLOR_BOLD}OR USE QUICK SETUP${COLOR_RESET}

The Quick Setup option (21) guides you through the main workflow.

${COLOR_BOLD}COMMON WORKFLOWS${COLOR_RESET}

${COLOR_CYAN}Test a new desktop:${COLOR_RESET}
  Install -> Create launch script -> Test from TTY

${COLOR_CYAN}Production setup:${COLOR_RESET}
  Install -> Adopt config -> Create launch script -> Create session -> Login

${COLOR_CYAN}Development:${COLOR_RESET}
  Install -> Adopt config -> Open in editor -> Make changes -> Git snapshot

${COLOR_BOLD}SUPPORT${COLOR_RESET}

For issues, suggestions, or contributions:
  $PROJECT_URL/issues

EOF

  press_enter
}

run_interactive_mode() {
  local choice

  if [[ ! -d "$SCRIPTS_DIR" ]]; then
    error "Scripts directory not found: $SCRIPTS_DIR"
    error "Make sure you are running this from the project root"
    exit 1
  fi

  while true; do
    show_main_menu

    if ! read_input "Choose an option [0-23]: " choice; then
      choice="0"
    fi

    case "$choice" in
      1) menu_install_desktop ;;
      2) menu_list_desktops ;;
      3) menu_remove_desktop ;;
      4) menu_open_shell ;;
      5) menu_create_launch ;;
      6) menu_list_launch ;;
      7) menu_remove_launch ;;
      8) menu_create_session ;;
      9) menu_list_sessions ;;
      10) menu_remove_session ;;
      11) menu_prepare_dotfiles ;;
      12) menu_link_dotfiles ;;
      13) menu_adopt_config ;;
      14) menu_dotfiles_status ;;
      15) menu_open_editor ;;
      16) menu_git_snapshot ;;
      17) menu_git_status ;;
      18) menu_list_repos ;;
      19) menu_add_repo ;;
      20) menu_remove_repo ;;
      21) menu_quick_setup ;;
      22) menu_system_info ;;
      23) menu_help ;;
      0)
        echo ""
        log "Thank you for using $PROJECT_NAME!"
        echo ""
        exit 0
        ;;
      *)
        error "Invalid option: $choice"
        press_enter
        ;;
    esac
  done
}

# -------------------------------------------------------------------
# ARGUMENT PARSING AND MODE DETECTION
# -------------------------------------------------------------------

show_usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  --bootstrap         Force bootstrap mode
  --interactive       Force interactive mode
  --dry-run           Show bootstrap actions without making changes
  --install-dir PATH  Override bootstrap install directory
  --help, -h          Show this help message

MODE SELECTION:
  - If --bootstrap is passed, bootstrap mode is used
  - If --interactive is passed, interactive mode is used
  - If the script is piped to bash, bootstrap mode is used
  - If the script is in the project root, interactive mode is used

EXAMPLES:
  curl -fsSL https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/install.sh | bash
  ./install.sh
  ./install.sh --bootstrap --install-dir "$HOME/my-desktops"
  ./install.sh --bootstrap --dry-run

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bootstrap)
        BOOTSTRAP_MODE=1
        INTERACTIVE_MODE=0
        shift
        ;;
      --interactive)
        INTERACTIVE_MODE=1
        BOOTSTRAP_MODE=0
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --install-dir)
        if [[ -z "${2:-}" ]]; then
          error "Missing value for --install-dir"
          exit 1
        fi
        INSTALL_DIR="$2"
        shift 2
        ;;
      --help|-h)
        show_usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        show_usage >&2
        exit 1
        ;;
    esac
  done
}

detect_mode() {
  if [[ $BOOTSTRAP_MODE -eq 1 || $INTERACTIVE_MODE -eq 1 ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    BOOTSTRAP_MODE=1
    return 0
  fi

  if in_local_repo_layout; then
    INTERACTIVE_MODE=1
    INSTALL_DIR="$SCRIPT_DIR"
    return 0
  fi

  BOOTSTRAP_MODE=1
}

# -------------------------------------------------------------------
# MAIN ENTRY POINT
# -------------------------------------------------------------------

main() {
  parse_args "$@"
  detect_mode

  if [[ $BOOTSTRAP_MODE -eq 1 ]]; then
    run_bootstrap_mode
  else
    run_interactive_mode
  fi
}

main "$@"
