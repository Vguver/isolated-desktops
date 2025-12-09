#!/usr/bin/env bash
# install.sh
#
# Bootstrap installer for isolated-desktops.
# Can be run locally or via:
#   curl -fsSL https://raw.githubusercontent.com/Vguver/isolated-desktops/main/install.sh | bash
#
# Provides an interactive menu to:
#   - Install an isolated desktop
#   - Create launch scripts
#   - Create display manager sessions
#   - Open dev tools (VS Code / VSCodium)
#   - Create Git snapshots for per-desktop dotfiles

set -euo pipefail

GITHUB_USER="${GITHUB_USER:-"Vguver"}"
GITHUB_REPO="${GITHUB_REPO:-"isolated-desktops"}"
GITHUB_BRANCH="${GITHUB_BRANCH:-"main"}"
REPO_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
DOTFILES_DIR="${DOTFILES_DIR:-"$HOME/isolated-desktops"}"

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[ERROR] %s\n' "$*" >&2; }

pause() { read -r -p "Press Enter to continue..." _; }

check_command() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command '$1' not found."; exit 1; }
}

check_requirements() {
  log "Checking basic requirements..."
  check_command bash
  check_command git
  check_command curl
}

clone_or_update_repo() {
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    log "Updating repository at $DOTFILES_DIR"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "(dry-run) would run git pull"
      return
    fi
    (
      cd "$DOTFILES_DIR" || exit 1
      git fetch origin "$GITHUB_BRANCH"
      git checkout "$GITHUB_BRANCH"
      git pull --ff-only origin "$GITHUB_BRANCH"
    )
  else
    log "Cloning $REPO_URL -> $DOTFILES_DIR"
    if [[ $DRY_RUN -eq 1 ]]; then
      log "(dry-run) would run git clone"
      return
    fi
    git clone --branch "$GITHUB_BRANCH" "$REPO_URL" "$DOTFILES_DIR"
  fi
}

run_setup_desktop() {
  (
    cd "$DOTFILES_DIR/scripts" || exit 1
    ./setup_desktops.sh create
  )
}

run_create_launch_script() {
  (
    cd "$DOTFILES_DIR/scripts" || exit 1
    ./desktop-launch.sh create-interactive
  )
}

run_create_session() {
  (
    cd "$DOTFILES_DIR/scripts" || exit 1
    ./desktop-sessions.sh create-interactive
  )
}

run_full_flow() {
  log "Full interactive flow:"
  run_setup_desktop
  pause
  run_create_launch_script
  pause
  run_create_session
}

# -------------------------------------------------------------------
# DEV TOOLS (VS Code / VSCodium) - MENU OPTION 5
# -------------------------------------------------------------------

ensure_dev_open_script() {
  if [[ ! -x "$DOTFILES_DIR/scripts/dev-open.sh" ]]; then
    warn "scripts/dev-open.sh not found or not executable."
    warn "Make sure Module 2 (dev-open.sh) is in place and chmod +x."
    return 1
  fi
  return 0
}

detect_editor_binary() {
  # Prefer code, then codium
  if command -v code >/dev/null 2>&1; then
    echo "code"
    return 0
  fi
  if command -v codium >/dev/null 2>&1; then
    echo "codium"
    return 0
  fi
  return 1
}

install_editor_if_missing() {
  # Optional helper to install an editor if none is found.
  # This is best-effort and mainly oriented to Arch-based systems.
  if detect_editor_binary >/dev/null 2>&1; then
    return 0
  fi

  warn "No VS Code (code) or VSCodium (codium) found in PATH."

  # Allow override via environment variable
  if [[ -n "${DEV_EDITOR_INSTALL_CMD:-}" ]]; then
    log "Using custom editor install command from DEV_EDITOR_INSTALL_CMD."
    log "Command: $DEV_EDITOR_INSTALL_CMD"
    eval "$DEV_EDITOR_INSTALL_CMD"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    echo
    echo "No editor detected. You can try to install one:"
    echo "  1) Install VS Code (package: code)"
    echo "  2) Install VSCodium (package: vscodium)"
    echo "  0) Skip installation"
    read -r -p "Choice: " choice
    case "$choice" in
      1)
        sudo pacman -S --needed code || warn "Failed to install 'code' with pacman."
        ;;
      2)
        sudo pacman -S --needed vscodium || warn "Failed to install 'vscodium' with pacman."
        ;;
      0|"")
        warn "Skipping editor installation."
        ;;
      *)
        warn "Invalid choice. Skipping editor installation."
        ;;
    esac
  else
    warn "No known package manager (pacman) detected. Please install VS Code or VSCodium manually."
  fi
}

run_dev_tools_menu() {
  ensure_dev_open_script || return 1

  # Try to install or at least suggest an editor if missing
  install_editor_if_missing

  echo
  echo "=== Dev Tools (VS Code / VSCodium) ==="
  echo
  echo "1) Open real HOME in editor"
  echo "2) Open fake HOME for a desktop"
  echo "3) Open dotfiles directory for a desktop"
  echo "0) Back to main menu"
  echo

  read -r -p "Option: " opt
  case "$opt" in
    1)
      (
        cd "$DOTFILES_DIR/scripts" || exit 1
        ./dev-open.sh real-home
      )
      ;;
    2)
      read -r -p "Desktop name (e.g. omarchy, jakoolit): " name
      if [[ -z "$name" ]]; then
        warn "Empty name, aborting."
        return 1
      fi
      (
        cd "$DOTFILES_DIR/scripts" || exit 1
        ./dev-open.sh fake-home "$name"
      )
      ;;
    3)
      read -r -p "Desktop name (e.g. omarchy, jakoolit): " name
      if [[ -z "$name" ]]; then
        warn "Empty name, aborting."
        return 1
      fi
      (
        cd "$DOTFILES_DIR/scripts" || exit 1
        ./dev-open.sh dotfiles "$name"
      )
      ;;
    0|"")
      log "Returning to main menu."
      ;;
    *)
      warn "Invalid option."
      ;;
  esac
}

# -------------------------------------------------------------------
# GIT SNAPSHOT DOTFILES - MENU OPTION 6
# -------------------------------------------------------------------

ensure_dev_sync_script() {
  if [[ ! -x "$DOTFILES_DIR/scripts/dev-sync.sh" ]]; then
    warn "scripts/dev-sync.sh not found or not executable."
    warn "Make sure Module 3 (dev-sync.sh) is in place and chmod +x."
    return 1
  fi
  return 0
}

prompt_git_remote_for() {
  local name="$1"
  local provider choice username repo remote

  echo
  echo "Choose Git provider for desktop '$name':"
  echo "  1) GitHub"
  echo "  2) GitLab"
  echo "  3) Custom remote URL"
  echo

  read -r -p "Option: " choice
  case "$choice" in
    1)
      provider="github.com"
      read -r -p "GitHub username: " username
      read -r -p "Repository name (e.g. ${name}-config): " repo
      [[ -z "$username" || -z "$repo" ]] && {
        warn "Username or repo empty, aborting."
        return 1
      }
      remote="git@${provider}:${username}/${repo}.git"
      ;;
    2)
      provider="gitlab.com"
      read -r -p "GitLab username: " username
      read -r -p "Repository name (e.g. ${name}-config): " repo
      [[ -z "$username" || -z "$repo" ]] && {
        warn "Username or repo empty, aborting."
        return 1
      }
      remote="git@${provider}:${username}/${repo}.git"
      ;;
    3)
      read -r -p "Custom remote URL (e.g. git@github.com:user/repo.git): " remote
      [[ -z "$remote" ]] && {
        warn "Empty remote URL, aborting."
        return 1
      }
      ;;
    *)
      warn "Invalid option."
      return 1
      ;;
  esac

  printf '%s\n' "$remote"
}

run_git_snapshot_menu() {
  ensure_dev_sync_script || return 1

  echo
  echo "=== Git Snapshot for Desktop Dotfiles ==="
  echo
  read -r -p "Desktop name (e.g. omarchy, jakoolit): " name
  if [[ -z "$name" ]]; then
    warn "Empty name, aborting."
    return 1
  fi

  local remote_url
  if ! remote_url="$(prompt_git_remote_for "$name")"; then
    return 1
  fi

  read -r -p "Git branch [default: main]: " branch
  branch="${branch:-main}"

  echo
  log "Using remote: $remote_url"
  log "Branch     : $branch"
  echo "A 'snapshot' commit will be created and pushed (if there are changes)."
  echo "Git may ask for your SSH key password or access token if needed."
  echo

  read -r -p "Continue? [Y/n]: " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    warn "Aborted by user."
    return 1
  fi

  (
    cd "$DOTFILES_DIR/scripts" || exit 1
    ./dev-sync.sh snapshot "$name" "$remote_url" "$branch" 1
  )
}

# -------------------------------------------------------------------
# MAIN MENU
# -------------------------------------------------------------------

main_menu() {
  log "Repository ready at: $DOTFILES_DIR"
  cat <<EOF

=== Isolated Desktops Installer (idtool) ===

1) Install an isolated desktop environment
2) Create launch script (start-<name>.sh)
3) Create display manager session (.desktop)
4) Full interactive flow (1 -> 2 -> 3)
5) Dev tools (VS Code / VSCodium)
6) Git snapshot dotfiles
0) Exit

EOF
  read -r -p "Option: " choice
  case "$choice" in
    1) run_setup_desktop ;;
    2) run_create_launch_script ;;
    3) run_create_session ;;
    4) run_full_flow ;;
    5) run_dev_tools_menu ;;
    6) run_git_snapshot_menu ;;
    0|"") log "Exiting."; exit 0 ;;
    *) warn "Invalid option."; pause ;;
  esac

  # After finishing an option, show the menu again
  main_menu
}

main() {
  check_requirements
  if [[ $DRY_RUN -eq 1 ]]; then
    log "Running in dry-run mode"
  fi
  clone_or_update_repo
  if [[ $DRY_RUN -eq 1 ]]; then
    log "Dry-run finished"
    exit 0
  fi
  main_menu
}

main "$@"
