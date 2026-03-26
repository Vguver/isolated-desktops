#!/usr/bin/env bash
# dev-sync.sh
#
# Developer helper to manage Git snapshots for per-desktop dotfiles.
# Works with both GitHub and GitLab (any Git remote URL).
#
# Each desktop has a dotfiles directory, e.g.:
#   $HOME/isolated-desktops/desktops/omarchy
#
# This script:
#   - initializes a Git repo if needed
#   - sets or updates "origin" remote
#   - creates a snapshot commit
#   - optionally pushes to remote
#
# Version: 2.0
# Author: Vguver
# License: MIT

set -euo pipefail

# -------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------

DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-"main"}"

# -------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------

# Get dotfiles path
dotfiles_path_for() {
  local name="$1"
  printf '%s/%s\n' "$DOTFILES_ROOT" "$name"
}

# Validate desktop name
validate_desktop_name() {
  local name="$1"
  
  if [[ -z "$name" ]]; then
    echo "Error: Desktop name cannot be empty" >&2
    return 1
  fi
  
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Invalid desktop name: $name" >&2
    return 1
  fi
  
  return 0
}

# Validate branch name
validate_branch_name() {
  local branch="$1"
  
  if [[ -z "$branch" ]]; then
    echo "Error: Branch name cannot be empty" >&2
    return 1
  fi
  
  if [[ ! "$branch" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
    echo "Error: Invalid branch name: $branch" >&2
    return 1
  fi
  
  return 0
}

# Validate Git URL
validate_git_url() {
  local url="$1"
  
  if [[ -z "$url" ]]; then
    return 0  # Empty is OK (for local-only repos)
  fi
  
  # Check for common Git URL patterns
  if [[ ! "$url" =~ ^(https?://|git@|ssh://|git://) ]]; then
    echo "Error: Invalid Git URL format: $url" >&2
    echo "       Expected: https://, git@, ssh://, or git://" >&2
    return 1
  fi
  
  return 0
}

# Check if directory is a Git repository
is_git_repo() {
  local path="$1"
  [[ -d "$path/.git" ]]
}

# Check if Git is installed
check_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is not installed" >&2
    echo "       Please install Git to use this tool" >&2
    return 1
  fi
  return 0
}

# -------------------------------------------------------------------
# GIT OPERATIONS
# -------------------------------------------------------------------

# Ensure Git repository exists
ensure_git_repo() {
  local path="$1"
  local branch="$2"
  
  if ! check_git; then
    return 1
  fi
  
  if [[ ! -d "$path" ]]; then
    echo "Error: Dotfiles directory does not exist: $path" >&2
    return 1
  fi
  
  (
    cd "$path" || exit 1
    
    if ! is_git_repo "$path"; then
      echo "[INFO] Initializing Git repository in $path"
      if ! git init; then
        echo "Error: Failed to initialize Git repository" >&2
        return 1
      fi
      
      # Create initial branch
      if ! git checkout -b "$branch" 2>/dev/null; then
        echo "Warning: Failed to create branch '$branch'" >&2
      fi
    else
      # Ensure branch exists
      if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
        echo "[INFO] Creating branch: $branch"
        if ! git checkout -b "$branch" 2>/dev/null; then
          echo "Warning: Failed to create branch '$branch'" >&2
        fi
      fi
    fi
    
    echo "✓ Git repository ready"
  )
}

# Set or update remote origin
set_remote_origin() {
  local path="$1"
  local remote_url="$2"
  
  if [[ -z "$remote_url" ]]; then
    return 0  # No remote URL, skip
  fi
  
  (
    cd "$path" || exit 1
    
    if git remote get-url origin >/dev/null 2>&1; then
      local current_url
      current_url="$(git remote get-url origin)"
      
      if [[ "$current_url" == "$remote_url" ]]; then
        echo "[INFO] Remote 'origin' already set to: $remote_url"
      else
        echo "[INFO] Updating remote 'origin'"
        echo "       From: $current_url"
        echo "       To:   $remote_url"
        if ! git remote set-url origin "$remote_url"; then
          echo "Error: Failed to update remote" >&2
          return 1
        fi
        echo "✓ Remote updated"
      fi
    else
      echo "[INFO] Setting remote 'origin' to: $remote_url"
      if ! git remote add origin "$remote_url"; then
        echo "Error: Failed to add remote" >&2
        return 1
      fi
      echo "✓ Remote added"
    fi
  )
}

# Check if working directory is clean
is_git_clean() {
  local path="$1"
  (
    cd "$path" || exit 1
    git diff --quiet && git diff --cached --quiet
  )
}

# Create snapshot commit
create_snapshot() {
  local path="$1"
  local name="$2"
  
  (
    cd "$path" || exit 1
    
    # Check if there are changes
    git add -A
    
    if is_git_clean "$path"; then
      echo "[INFO] No changes to commit"
      return 0
    fi
    
    # Create commit
    local timestamp message
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    message="snapshot($name): $timestamp"
    
    if ! git commit -m "$message"; then
      echo "Error: Failed to create commit" >&2
      return 1
    fi
    
    echo "✓ Created snapshot commit"
    echo "  Message: $message"
  )
}

# Push to remote
push_to_remote() {
  local path="$1"
  local branch="$2"
  
  (
    cd "$path" || exit 1
    
    if ! git remote get-url origin >/dev/null 2>&1; then
      echo "Error: No remote 'origin' configured" >&2
      return 1
    fi
    
    echo "[INFO] Pushing to remote: origin/$branch"
    
    if git push -u origin "$branch"; then
      echo "✓ Successfully pushed to remote"
    else
      echo "Error: Failed to push to remote" >&2
      echo "       You may need to resolve conflicts or check credentials" >&2
      return 1
    fi
  )
}

# -------------------------------------------------------------------
# MAIN OPERATIONS
# -------------------------------------------------------------------

# Snapshot and push dotfiles
snapshot_and_push() {
  local name="$1"
  local remote_url="${2:-}"
  local branch="${3:-$DEFAULT_BRANCH}"
  local push="${4:-1}"
  
  # Validate inputs
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if ! validate_branch_name "$branch"; then
    return 1
  fi
  
  if ! validate_git_url "$remote_url"; then
    return 1
  fi
  
  # Get dotfiles path
  local path
  path="$(dotfiles_path_for "$name")"
  
  echo ">>> Creating snapshot for: $name"
  echo ""
  echo "Configuration:"
  echo "  Dotfiles:  $path"
  echo "  Branch:    $branch"
  echo "  Remote:    ${remote_url:-"(local only)"}"
  echo "  Push:      ${push}"
  echo ""
  
  # Ensure Git repo
  if ! ensure_git_repo "$path" "$branch"; then
    return 1
  fi
  
  echo ""
  
  # Set remote if provided
  if [[ -n "$remote_url" ]]; then
    if ! set_remote_origin "$path" "$remote_url"; then
      return 1
    fi
    echo ""
  fi
  
  # Create snapshot
  if ! create_snapshot "$path" "$name"; then
    return 1
  fi
  
  echo ""
  
  # Push if requested
  if [[ "$push" == "1" && -n "$remote_url" ]]; then
    if ! push_to_remote "$path" "$branch"; then
      return 1
    fi
  elif [[ "$push" == "1" && -z "$remote_url" ]]; then
    echo "[INFO] Skipping push (no remote URL configured)"
  else
    echo "[INFO] Skipping push (push=0)"
  fi
  
  echo ""
  echo "✓ Snapshot complete for: $name"
  echo ""
  
  return 0
}

# Initialize repository only
init_only() {
  local name="$1"
  local branch="${2:-$DEFAULT_BRANCH}"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  if ! validate_branch_name "$branch"; then
    return 1
  fi
  
  local path
  path="$(dotfiles_path_for "$name")"
  
  echo ">>> Initializing Git repository for: $name"
  echo ""
  echo "Configuration:"
  echo "  Dotfiles:  $path"
  echo "  Branch:    $branch"
  echo ""
  
  ensure_git_repo "$path" "$branch"
  
  echo ""
  echo "✓ Repository initialized"
  echo ""
  echo "Next steps:"
  echo "  1. Add remote: cd $path && git remote add origin <url>"
  echo "  2. Or snapshot: $0 snapshot $name <url>"
  echo ""
}

# Show repository status
show_status() {
  local name="$1"
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  local path
  path="$(dotfiles_path_for "$name")"
  
  if [[ ! -d "$path" ]]; then
    echo "Error: Dotfiles directory does not exist: $path" >&2
    return 1
  fi
  
  echo "Status for: $name"
  echo "Path: $path"
  echo ""
  
  if ! is_git_repo "$path"; then
    echo "Git: Not initialized"
    echo ""
    echo "Initialize with: $0 init-only $name"
    return 0
  fi
  
  (
    cd "$path" || exit 1
    
    echo "Git: Initialized"
    echo ""
    
    # Branch info
    local current_branch
    current_branch="$(git branch --show-current 2>/dev/null || echo "unknown")"
    echo "Branch: $current_branch"
    
    # Remote info
    if git remote get-url origin >/dev/null 2>&1; then
      local remote_url
      remote_url="$(git remote get-url origin)"
      echo "Remote: $remote_url"
    else
      echo "Remote: (not configured)"
    fi
    
    echo ""
    
    # Status
    echo "Working directory:"
    if is_git_clean "$path"; then
      echo "  ✓ Clean (no uncommitted changes)"
    else
      echo "  ✗ Has uncommitted changes"
      echo ""
      git status --short
    fi
    
    echo ""
    
    # Last commit
    if git rev-parse HEAD >/dev/null 2>&1; then
      echo "Last commit:"
      git log -1 --pretty=format:"  %h - %s (%ar)" 2>/dev/null || true
      echo ""
    else
      echo "No commits yet"
    fi
  )
  
  echo ""
}

# -------------------------------------------------------------------
# INTERACTIVE MODE
# -------------------------------------------------------------------

snapshot_interactive() {
  echo "=== Create Dotfiles Snapshot ==="
  echo ""
  
  # Get desktop name
  read -r -p "Desktop name: " name
  if [[ -z "$name" ]]; then
    echo "Error: Empty name" >&2
    return 1
  fi
  
  if ! validate_desktop_name "$name"; then
    return 1
  fi
  
  # Get remote URL
  echo ""
  echo "Git remote URL (leave empty for local-only):"
  echo "Examples:"
  echo "  - git@github.com:user/repo.git"
  echo "  - https://github.com/user/repo.git"
  echo "  - git@gitlab.com:user/repo.git"
  echo ""
  read -r -p "Remote URL: " remote_url
  
  if [[ -n "$remote_url" ]] && ! validate_git_url "$remote_url"; then
    return 1
  fi
  
  # Get branch
  echo ""
  read -r -p "Branch name [default: $DEFAULT_BRANCH]: " branch
  branch="${branch:-$DEFAULT_BRANCH}"
  
  if ! validate_branch_name "$branch"; then
    return 1
  fi
  
  # Ask about pushing
  local push="0"
  if [[ -n "$remote_url" ]]; then
    echo ""
    read -r -p "Push to remote after commit? [Y/n]: " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      push="1"
    fi
  fi
  
  echo ""
  snapshot_and_push "$name" "$remote_url" "$branch" "$push"
}

# -------------------------------------------------------------------
# CLI INTERFACE
# -------------------------------------------------------------------

show_help() {
  cat <<EOF
Usage: $0 <command> [args]

COMMANDS:
  snapshot <n> [url] [branch] [push]
      Create snapshot and optionally push to remote
      
      url:    Git remote URL (GitHub/GitLab)
      branch: Branch name (default: main)
      push:   1 to push, 0 to skip (default: 1)
      
  snapshot-interactive
      Interactive snapshot creation
      
  init-only <n> [branch]
      Initialize Git repository without committing
      
  status <n>
      Show Git status for a desktop
      
  help
      Show this help message

EXAMPLES:
  $0 snapshot omarchy
  $0 snapshot omarchy git@github.com:user/omarchy-dots.git
  $0 snapshot omarchy git@github.com:user/dots.git main 1
  $0 snapshot-interactive
  $0 init-only jakoolit
  $0 status omarchy

GIT REMOTES:
  GitHub:  git@github.com:user/repo.git
  GitLab:  git@gitlab.com:user/repo.git
  HTTPS:   https://github.com/user/repo.git

ENVIRONMENT:
  DOTFILES_ROOT       Base directory for dotfiles
                      (default: \$HOME/isolated-desktops/desktops)
  DEFAULT_BRANCH      Default branch name
                      (default: main)
  GIT_REMOTE_URL      Default remote URL if not specified

WORKFLOW:
  1. Install desktop:     setup_desktops.sh create omarchy
  2. Adopt config:        dotfiles-link.sh adopt-config omarchy
  3. Initialize Git:      $0 init-only omarchy
  4. Set remote:          cd ~/isolated-desktops/desktops/omarchy
                          git remote add origin <url>
  5. Create snapshot:     $0 snapshot omarchy

OR:
  1-2. Same as above
  3. Snapshot with URL:   $0 snapshot omarchy <url>

NOTES:
  - Creates automatic commits with timestamps
  - Commit message format: "snapshot(name): YYYY-MM-DD HH:MM:SS"
  - Supports any Git hosting service (GitHub, GitLab, etc.)
  - Can work offline (local commits only)

EOF
}

main() {
  local cmd="${1:-}"
  
  case "$cmd" in
    snapshot)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 snapshot <n> [url] [branch] [push]" >&2
        exit 1
      fi
      
      local name="${2}"
      local remote_url="${3:-${GIT_REMOTE_URL:-}}"
      local branch="${4:-$DEFAULT_BRANCH}"
      local push="${5:-1}"
      
      snapshot_and_push "$name" "$remote_url" "$branch" "$push"
      ;;
      
    snapshot-interactive|interactive)
      snapshot_interactive
      ;;
      
    init-only|init)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 init-only <n> [branch]" >&2
        exit 1
      fi
      init_only "${2}" "${3:-$DEFAULT_BRANCH}"
      ;;
      
    status)
      if [[ -z "${2:-}" ]]; then
        echo "Error: Desktop name required" >&2
        echo "Usage: $0 status <n>" >&2
        exit 1
      fi
      show_status "${2}"
      ;;
      
    ""|help|-h|--help)
      show_help
      ;;
      
    *)
      echo "Error: Unknown command: $cmd" >&2
      echo "Use '$0 help' for usage information" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
