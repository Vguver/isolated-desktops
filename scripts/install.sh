#!/usr/bin/env bash
# install.sh
#
# Main interactive menu for isolated-desktops project.
# Provides a unified interface to all functionality.
#
# Version: 2.0
# Author: Vguver
# License: MIT

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Project information
PROJECT_NAME="Isolated Desktops"
PROJECT_VERSION="2.0"
PROJECT_URL="https://github.com/Vguver/isolated-desktops"

# -------------------------------------------------------------------
# COLORS AND FORMATTING
# -------------------------------------------------------------------

# Check if terminal supports colors
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
# HELPER FUNCTIONS
# -------------------------------------------------------------------

# Print colored message
print_color() {
  local color="$1"
  shift
  printf "${color}%s${COLOR_RESET}\n" "$*"
}

# Print header
print_header() {
  echo ""
  print_color "$COLOR_BOLD$COLOR_CYAN" "============================================"
  print_color "$COLOR_BOLD$COLOR_CYAN" "  $*"
  print_color "$COLOR_BOLD$COLOR_CYAN" "============================================"
  echo ""
}

# Print success message
print_success() {
  print_color "$COLOR_GREEN" "✓ $*"
}

# Print error message
print_error() {
  print_color "$COLOR_RED" "✗ $*" >&2
}

# Print warning message
print_warning() {
  print_color "$COLOR_YELLOW" "⚠ $*"
}

# Print info message
print_info() {
  print_color "$COLOR_BLUE" "ℹ $*"
}

# Check if script exists
check_script() {
  local script="$1"
  local path="$SCRIPTS_DIR/$script"
  
  if [[ ! -f "$path" ]]; then
    print_error "Required script not found: $path"
    return 1
  fi
  
  if [[ ! -x "$path" ]]; then
    print_warning "Script not executable: $path"
    print_info "Making it executable..."
    chmod +x "$path" || {
      print_error "Failed to make script executable"
      return 1
    }
  fi
  
  return 0
}

# Run script
run_script() {
  local script="$1"
  shift
  
  if ! check_script "$script"; then
    return 1
  fi
  
  "$SCRIPTS_DIR/$script" "$@"
}

# Wait for user
press_enter() {
  echo ""
  read -r -p "Press Enter to continue..."
}

# -------------------------------------------------------------------
# MENU FUNCTIONS
# -------------------------------------------------------------------

# Show main menu
show_main_menu() {
  clear
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

# Install desktop
menu_install_desktop() {
  print_header "Install Isolated Desktop"
  run_script "setup_desktops.sh" create
  press_enter
}

# List desktops
menu_list_desktops() {
  print_header "Installed Desktops"
  run_script "setup_desktops.sh" list
  press_enter
}

# Remove desktop
menu_remove_desktop() {
  print_header "Remove Desktop Environment"
  run_script "setup_desktops.sh" list
  echo ""
  read -r -p "Desktop name to remove: " name
  if [[ -n "$name" ]]; then
    run_script "setup_desktops.sh" remove "$name"
  fi
  press_enter
}

# Open shell
menu_open_shell() {
  print_header "Open Desktop Shell"
  run_script "setup_desktops.sh" list
  echo ""
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "setup_desktops.sh" shell "$name"
  fi
  press_enter
}

# Create launch script
menu_create_launch() {
  print_header "Create Launch Script"
  run_script "desktop-launch.sh" create-interactive
  press_enter
}

# List launch scripts
menu_list_launch() {
  print_header "Launch Scripts"
  run_script "desktop-launch.sh" list
  press_enter
}

# Remove launch script
menu_remove_launch() {
  print_header "Remove Launch Script"
  run_script "desktop-launch.sh" list
  echo ""
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "desktop-launch.sh" remove "$name"
  fi
  press_enter
}

# Create session
menu_create_session() {
  print_header "Create Display Manager Session"
  run_script "desktop-sessions.sh" create-interactive
  press_enter
}

# List sessions
menu_list_sessions() {
  print_header "Display Manager Sessions"
  run_script "desktop-sessions.sh" list
  press_enter
}

# Remove session
menu_remove_session() {
  print_header "Remove Session File"
  run_script "desktop-sessions.sh" list
  echo ""
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "desktop-sessions.sh" remove "$name"
  fi
  press_enter
}

# Prepare dotfiles
menu_prepare_dotfiles() {
  print_header "Prepare Dotfiles Structure"
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "dotfiles-link.sh" prepare "$name"
  fi
  press_enter
}

# Link dotfiles
menu_link_dotfiles() {
  print_header "Link Dotfiles"
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "dotfiles-link.sh" link-config "$name"
  fi
  press_enter
}

# Adopt config
menu_adopt_config() {
  print_header "Adopt Existing Config"
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "dotfiles-link.sh" adopt-config "$name"
  fi
  press_enter
}

# Show dotfiles status
menu_dotfiles_status() {
  print_header "Dotfiles Status"
  run_script "dotfiles-link.sh" status
  press_enter
}

# Open in editor
menu_open_editor() {
  print_header "Open in Editor"
  run_script "dev-open.sh" interactive
  press_enter
}

# Git snapshot
menu_git_snapshot() {
  print_header "Create Git Snapshot"
  run_script "dev-sync.sh" snapshot-interactive
  press_enter
}

# Git status
menu_git_status() {
  print_header "Git Status"
  read -r -p "Desktop name: " name
  if [[ -n "$name" ]]; then
    run_script "dev-sync.sh" status "$name"
  fi
  press_enter
}

# List repositories
menu_list_repos() {
  print_header "Available Desktop Repositories"
  run_script "repos-desktops.sh" list
  press_enter
}

# Add repository
menu_add_repo() {
  print_header "Add Desktop Repository"
  run_script "repos-desktops.sh" add-interactive
  press_enter
}

# Remove repository
menu_remove_repo() {
  print_header "Remove Desktop Repository"
  run_script "repos-desktops.sh" list
  echo ""
  read -r -p "Repository name to remove: " name
  if [[ -n "$name" ]]; then
    run_script "repos-desktops.sh" remove "$name"
  fi
  press_enter
}

# Quick setup
menu_quick_setup() {
  print_header "Quick Setup - Full Workflow"
  
  echo "This will guide you through the complete setup:"
  echo "  1. Install desktop environment"
  echo "  2. Adopt existing config (if present)"
  echo "  3. Create launch script"
  echo "  4. Create display manager session"
  echo ""
  
  read -r -p "Continue? [Y/n]: " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    return 0
  fi
  
  # Step 1: Install
  echo ""
  print_info "Step 1/4: Installing desktop environment..."
  if ! run_script "setup_desktops.sh" create; then
    print_error "Installation failed"
    press_enter
    return 1
  fi
  
  # Get desktop name for next steps
  echo ""
  read -r -p "Desktop name that was installed: " name
  if [[ -z "$name" ]]; then
    print_error "No desktop name provided"
    press_enter
    return 1
  fi
  
  # Step 2: Adopt config
  echo ""
  print_info "Step 2/4: Adopting configuration..."
  read -r -p "Adopt existing config? [Y/n]: " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    run_script "dotfiles-link.sh" adopt-config "$name" || true
  fi
  
  # Step 3: Launch script
  echo ""
  print_info "Step 3/4: Creating launch script..."
  if ! run_script "desktop-launch.sh" create "$name"; then
    print_warning "Launch script creation failed, but continuing..."
  fi
  
  # Step 4: Session file
  echo ""
  print_info "Step 4/4: Creating display manager session..."
  read -r -p "Create session file? [Y/n]: " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    run_script "desktop-sessions.sh" create-interactive || true
  fi
  
  echo ""
  print_success "Quick setup complete!"
  echo ""
  print_info "Next steps:"
  echo "  1. Restart your display manager (or reboot)"
  echo "  2. Select '$name (Isolated)' from login screen"
  echo "  3. Log in and enjoy your isolated desktop!"
  echo ""
  
  press_enter
}

# System information
menu_system_info() {
  print_header "System Information"
  
  echo "${COLOR_BOLD}Project:${COLOR_RESET}"
  echo "  Name:    $PROJECT_NAME"
  echo "  Version: $PROJECT_VERSION"
  echo "  URL:     $PROJECT_URL"
  echo ""
  
  echo "${COLOR_BOLD}Paths:${COLOR_RESET}"
  echo "  Project: $SCRIPT_DIR"
  echo "  Scripts: $SCRIPTS_DIR"
  echo "  Config:  ${CONFIG_BASE_PREFIX:-$HOME/.}"
  echo "  Dotfiles: ${DOTFILES_ROOT:-$HOME/isolated-desktops/desktops}"
  echo ""
  
  echo "${COLOR_BOLD}Dependencies:${COLOR_RESET}"
  local deps=("bash" "git" "curl")
  for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
      local ver
      ver=$("$dep" --version 2>/dev/null | head -n1 || echo "unknown")
      printf "  %-10s ${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$dep" "$ver"
    else
      printf "  %-10s ${COLOR_RED}✗ not found${COLOR_RESET}\n" "$dep"
    fi
  done
  echo ""
  
  echo "${COLOR_BOLD}Optional:${COLOR_RESET}"
  local opt_deps=("code" "codium" "fzf" "pacman")
  for dep in "${opt_deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
      printf "  %-10s ${COLOR_GREEN}✓${COLOR_RESET}\n" "$dep"
    else
      printf "  %-10s ${COLOR_YELLOW}- not installed${COLOR_RESET}\n" "$dep"
    fi
  done
  
  echo ""
  press_enter
}

# Help
menu_help() {
  print_header "Help & Documentation"
  
  cat <<EOF
${COLOR_BOLD}DOCUMENTATION${COLOR_RESET}

For detailed documentation, visit:
  $PROJECT_URL

${COLOR_BOLD}QUICK START${COLOR_RESET}

1. Add a desktop repository (if needed):
   ${COLOR_CYAN}Repository Management → Add new desktop${COLOR_RESET}

2. Install a desktop:
   ${COLOR_CYAN}Desktop Management → Install isolated desktop${COLOR_RESET}

3. Create launch script:
   ${COLOR_CYAN}Launch Scripts → Create launch script${COLOR_RESET}

4. Create session file:
   ${COLOR_CYAN}Display Manager Sessions → Create session file${COLOR_RESET}

5. Restart display manager and log in

${COLOR_BOLD}OR USE QUICK SETUP${COLOR_RESET}

The Quick Setup option (21) will guide you through all steps.

${COLOR_BOLD}COMMON WORKFLOWS${COLOR_RESET}

${COLOR_CYAN}Test a new desktop:${COLOR_RESET}
  Install → Create launch → Test from TTY

${COLOR_CYAN}Production setup:${COLOR_RESET}
  Install → Adopt config → Create launch → Create session → Login

${COLOR_CYAN}Development:${COLOR_RESET}
  Install → Adopt config → Open in editor → Make changes → Git snapshot

${COLOR_BOLD}SUPPORT${COLOR_RESET}

For issues, suggestions, or contributions:
  $PROJECT_URL/issues

EOF
  
  press_enter
}

# -------------------------------------------------------------------
# MAIN LOOP
# -------------------------------------------------------------------

main() {
  # Check if scripts directory exists
  if [[ ! -d "$SCRIPTS_DIR" ]]; then
    print_error "Scripts directory not found: $SCRIPTS_DIR"
    echo "Make sure you're running this from the project root"
    exit 1
  fi
  
  # Main loop
  while true; do
    show_main_menu
    
    local choice
    read -r -p "Choose an option [0-23]: " choice
    
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
        print_info "Thank you for using $PROJECT_NAME!"
        echo ""
        exit 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter
        ;;
    esac
  done
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
