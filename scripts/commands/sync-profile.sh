#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
source "$ID_ROOT/scripts/lib/dotfiles.sh"
source "$ID_ROOT/scripts/lib/lock.sh"
need_cmd git
name="${1:-}"; remote="${2:-}"; branch="${3:-main}"; push="${4:-1}"
[[ -n "$name" ]] || die_usage "Usage: idtool sync <profile> [remote] [branch] [push]"
safe_name "$name"
[[ "$push" == '0' || "$push" == '1' ]] || die_usage 'push must be 0 or 1'
[[ -n "$remote" ]] && validate_git_url "$remote"
source_dir="$(profile_home_dir "$name")"; repo_dir="$(profile_snapshots_dir "$name")/git"
[[ -d "$source_dir" ]] || die_with_code "$EX_NOINPUT" "Profile not installed: $name"
mkdir -p -- "$repo_dir"
acquire_profile_lock "$name"; trap 'release_profile_lock' EXIT
if [[ ! -d "$repo_dir/.git" ]]; then if git -C "$repo_dir" init -b "$branch" >/dev/null 2>&1; then :; else git -C "$repo_dir" init >/dev/null || die_with_code "$EX_IOERR" "Failed to initialize snapshot repository for $name"; git -C "$repo_dir" checkout -B "$branch" >/dev/null 2>&1 || die_with_code "$EX_IOERR" "Failed to create branch '$branch' for snapshot repo"; fi; else git -C "$repo_dir" checkout -B "$branch" >/dev/null 2>&1 || die_with_code "$EX_IOERR" "Failed to switch snapshot repo to branch '$branch'"; fi
git -C "$repo_dir" config user.name "${ID_GIT_AUTHOR_NAME:-Isolated Desktops}"
git -C "$repo_dir" config user.email "${ID_GIT_AUTHOR_EMAIL:-isolated-desktops@local}"
sync_rel_into_repo() { local rel="$1" src="$source_dir/$rel" dst="$repo_dir/$rel"; if [[ -d "$src" ]]; then sync_tree "$src" "$dst"; elif [[ -f "$src" || -L "$src" ]]; then mkdir -p -- "$(dirname "$dst")"; rm -rf -- "$dst"; cp -a -- "$src" "$dst"; else rm -rf -- "$dst"; fi; }
synced_any=0
if [[ -f "$(profile_links_file "$name")" ]]; then while IFS= read -r rel; do [[ -n "$rel" ]] || continue; sync_rel_into_repo "$rel"; synced_any=1; done < <(links_file_list "$name"); fi
if [[ $synced_any -eq 0 ]]; then [[ -d "$source_dir/.config" ]] && sync_rel_into_repo '.config'; [[ -f "$source_dir/.gtkrc-2.0" ]] && sync_rel_into_repo '.gtkrc-2.0'; [[ -f "$source_dir/.Xresources" ]] && sync_rel_into_repo '.Xresources'; fi
git -C "$repo_dir" add -A || die_with_code "$EX_IOERR" "Failed to stage snapshot changes for $name"
if ! git -C "$repo_dir" diff --cached --quiet; then git -C "$repo_dir" commit -m "snapshot: $name $(date +%Y-%m-%dT%H:%M:%S)" >/dev/null || die_with_code "$EX_IOERR" "Failed to create snapshot commit for $name"; success "Created snapshot commit for: $name"; else info "No snapshot changes detected for: $name"; fi
if [[ -n "$remote" ]]; then if git -C "$repo_dir" remote get-url origin >/dev/null 2>&1; then git -C "$repo_dir" remote set-url origin "$remote" || die_with_code "$EX_IOERR" "Failed to update remote origin for $name"; else git -C "$repo_dir" remote add origin "$remote" || die_with_code "$EX_IOERR" "Failed to add remote origin for $name"; fi; if [[ "$push" == '1' ]]; then git -C "$repo_dir" push -u origin "$branch" || die_with_code "$EX_IOERR" "Failed to push snapshot repo for $name"; else info "Remote configured but push skipped for: $name"; fi; fi
info "Snapshot repo: $repo_dir"
