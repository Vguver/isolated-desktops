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

set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-"$HOME/isolated-desktops/desktops"}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-"main"}"

dotfiles_path_for() {
  local name="$1"
  printf '%s/%s\n' "$DOTFILES_ROOT" "$name"
}

ensure_git_repo() {
  local path="$1"
  local branch="$2"

  if [[ ! -d "$path" ]]; then
    echo "Error: dotfiles directory does not exist: $path" >&2
    return 1
  fi

  (
    cd "$path" || exit 1
    if [[ ! -d ".git" ]]; then
      echo "[INFO] Initializing new Git repository in $path"
      git init
      git checkout -b "$branch" 2>/dev/null || git branch -M "$branch"
    else
      # Ensure branch name
      git branch -M "$branch" 2>/dev/null || true
    fi
  )
}

set_remote_origin() {
  local path="$1"
  local remote_url="$2"

  (
    cd "$path" || exit 1
    if git remote get-url origin >/dev/null 2>&1; then
      echo "[INFO] Updating existing 'origin' remote to: $remote_url"
      git remote set-url origin "$remote_url"
    else
      echo "[INFO] Setting 'origin' remote to: $remote_url"
      git remote add origin "$remote_url"
    fi
  )
}

snapshot_and_push() {
  local name="$1"
  local remote_url="$2"
  local branch="$3"
  local push="${4:-1}"

  local path
  path="$(dotfiles_path_for "$name")"

  ensure_git_repo "$path" "$branch"

  if [[ -n "$remote_url" ]]; then
    set_remote_origin "$path" "$remote_url"
  else
    echo "[WARN] No remote URL provided. Snapshot will be local only."
  fi

  (
    cd "$path" || exit 1
    echo "[INFO] Creating snapshot for desktop '$name' in $path"
    git add -A
    local ts msg
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    msg="snapshot($name) $ts"
    if git diff --cached --quiet; then
      echo "[INFO] No changes to commit."
    else
      git commit -m "$msg"
      echo "[INFO] Created commit: $msg"
    fi

    if [[ "$push" == "1" && -n "$remote_url" ]]; then
      echo "[INFO] Pushing to remote 'origin' ($branch)..."
      git push -u origin "$branch"
    else
      echo "[INFO] Skipping push (either push=0 or no remote URL)."
    fi
  )
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    snapshot)
      # dev-sync.sh snapshot <name> [remote_url] [branch] [push]
      local name="${1:-}"
      local remote_url="${2:-"${GIT_REMOTE_URL:-}"}"
      local branch="${3:-"$DEFAULT_BRANCH"}"
      local push="${4:-1}"

      if [[ -z "$name" ]]; then
        echo "Usage: $0 snapshot <name> [remote_url] [branch] [push]" >&2
        echo "  remote_url: GitHub/GitLab (e.g. git@github.com:user/repo.git)" >&2
        echo "  branch    : default '$DEFAULT_BRANCH'" >&2
        echo "  push      : 1 to push (default), 0 to skip push" >&2
        exit 1
      fi

      snapshot_and_push "$name" "$remote_url" "$branch" "$push"
      ;;
    init-only)
      # dev-sync.sh init-only <name> [branch]
      local name="${1:-}"
      local branch="${2:-"$DEFAULT_BRANCH"}"
      if [[ -z "$name" ]]; then
        echo "Usage: $0 init-only <name> [branch]" >&2
        exit 1
      fi
      ensure_git_repo "$(dotfiles_path_for "$name")" "$branch"
      ;;
    ""|help|-h|--help)
      cat <<EOF
Usage: $0 <command> [args]

Commands:
  snapshot <name> [remote_url] [branch] [push]
      Create local snapshot commit and optionally push.
      remote_url can be GitHub or GitLab, for example:
        git@github.com:Vguver/omarchy-config.git
        git@gitlab.com:Vguver/jakoolit-config.git

      If remote_url is omitted, the script uses GIT_REMOTE_URL env var if set.
      push=1 pushes to origin, push=0 only commits locally.

  init-only <name> [branch]
      Initialize a Git repo for the desktop dotfiles (no remote, no commit).

Environment:
  DOTFILES_ROOT   Base dir for per-desktop dotfiles (default: $HOME/isolated-desktops/desktops)
  DEFAULT_BRANCH  Git branch name (default: "main")
  GIT_REMOTE_URL  Default remote URL if not provided as argument
EOF
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
