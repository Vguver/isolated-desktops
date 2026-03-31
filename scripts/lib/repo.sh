#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/manifest.sh"
repo_clone_or_update() {
  local name="$1" repo_url ref repo_dir safe_url temp_dir
  repo_url="$(manifest_get "$name" repo_url)"
  ref="$(manifest_get "$name" ref)"
  repo_dir="$(profile_repo_dir "$name")"
  safe_url="$(sanitize_url "$repo_url")"
  need_cmd git
  validate_git_url "$repo_url"
  mkdir -p -- "$(dirname "$repo_dir")"
  if [[ ! -d "$repo_dir/.git" ]]; then
    progress_step 1 2 "Cloning repository for $name from $safe_url"
    temp_dir="$(create_temp_dir)/repo"
    git clone -- "$repo_url" "$temp_dir" || die_with_code "$EX_IOERR" "Failed to clone repository: $safe_url"
    rm -rf -- "$repo_dir"
    mv -- "$temp_dir" "$repo_dir"
  else
    progress_step 1 2 "Updating repository for $name"
    git -C "$repo_dir" remote set-url origin "$repo_url" || die_with_code "$EX_IOERR" "Failed to update remote URL for $name"
    git -C "$repo_dir" fetch --all --tags --prune || die_with_code "$EX_IOERR" "Failed to fetch repository updates for $name"
  fi

  progress_step 2 2 "Checking out requested ref: $ref"
  git -C "$repo_dir" fetch --all --tags --prune || die_with_code "$EX_IOERR" "Failed to refresh repository refs for $name"

  if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$ref"; then
    git -C "$repo_dir" checkout -B "$ref" "origin/$ref" || die_with_code "$EX_IOERR" "Failed to checkout remote branch '$ref' for $name"
  elif git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$ref"; then
    git -C "$repo_dir" checkout -f "$ref" || die_with_code "$EX_IOERR" "Failed to checkout local branch '$ref' for $name"
  elif git -C "$repo_dir" show-ref --verify --quiet "refs/tags/$ref"; then
    git -C "$repo_dir" checkout -f "$ref" || die_with_code "$EX_IOERR" "Failed to checkout tag '$ref' for $name"
  elif git -C "$repo_dir" rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
    git -C "$repo_dir" checkout -f "$ref" || die_with_code "$EX_IOERR" "Failed to checkout commit '$ref' for $name"
  else
    git -C "$repo_dir" checkout -f FETCH_HEAD || die_with_code "$EX_IOERR" "Failed to checkout FETCH_HEAD for $name"
  fi
}
