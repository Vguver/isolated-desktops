#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
normalize_home_rel() {
  local rel="$1"
  rel="${rel#./}"
  rel="${rel%/}"
  validate_relative_path "$rel" 'relative home path'
  printf '%s\n' "$rel"
}
links_default_paths() { printf '%s\n' '.config' '.local/bin' '.local/share'; }
links_file_init() {
  local name="$1" file
  file="$(profile_links_file "$name")"
  mkdir -p -- "$(dirname "$file")"
  [[ -f "$file" ]] || printf '{\n  "paths": []\n}\n' > "$file"
}
links_file_add() {
  local name="$1" rel="$2" file
  need_cmd python3
  file="$(profile_links_file "$name")"
  links_file_init "$name"
  python3 - "$file" "$rel" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]); rel = sys.argv[2]
data = {"paths": []}
if path.exists():
    data = json.loads(path.read_text(encoding='utf-8'))
paths = sorted(set(data.get('paths', []) + [rel]))
data['paths'] = paths
path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
PY
}
links_file_list() {
  local name="$1" file
  need_cmd python3
  file="$(profile_links_file "$name")"
  [[ -f "$file" ]] || return 0
  python3 - "$file" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(0)
for item in json.loads(path.read_text(encoding='utf-8')).get('paths', []):
    print(item)
PY
}
collect_default_existing_paths() {
  local name="$1" rel home_path
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    home_path="$(home_target_for "$name" "$rel")"
    if [[ -e "$home_path" || -L "$home_path" ]]; then
      printf '%s\n' "$rel"
    fi
  done < <(links_default_paths)
}
infer_target_kind() {
  local rel="$1" home_path="$2" target="$3" base
  if [[ -d "$home_path" || -d "$target" ]]; then printf 'dir\n'; return 0; fi
  case "$rel" in .config|.local|.local/bin|.local/share|.themes|.icons|.fonts) printf 'dir\n'; return 0;; esac
  base="${rel##*/}"
  case "$base" in .*.*|*.*) printf 'file\n';; *) printf 'dir\n';; esac
}
ensure_target_placeholder() {
  local name="$1" rel="$2" home_path target kind
  home_path="$(profile_home_dir "$name")/$rel"
  target="$(profile_dotfiles_path "$name" "$rel")"
  if [[ -e "$target" || -L "$target" ]]; then return 0; fi
  mkdir -p -- "$(dirname "$target")"
  kind="$(infer_target_kind "$rel" "$home_path" "$target")"
  if [[ "$kind" == 'dir' ]]; then mkdir -p -- "$target"; else : > "$target"; fi
}
path_is_effectively_empty() {
  local path="$1"
  if [[ ! -e "$path" && ! -L "$path" ]]; then return 0; fi
  if [[ -d "$path" && ! -L "$path" ]]; then
    shopt -s nullglob dotglob
    local files=("$path"/*)
    shopt -u nullglob dotglob
    [[ ${#files[@]} -eq 0 ]]
  elif [[ -f "$path" ]]; then
    [[ ! -s "$path" ]]
  else
    return 1
  fi
}
link_target_for() { local name="$1" rel="$2"; printf '%s\n' "$(profile_dotfiles_path "$name" "$rel")"; }
home_target_for() { local name="$1" rel="$2"; printf '%s\n' "$(profile_home_dir "$name")/$rel"; }
_dotfiles_backup_path() {
  local name="$1" rel="$2" label="$3" stamp root
  stamp="$(date +%Y%m%d-%H%M%S)"
  root="$(profile_backups_dir "$name")/dotfiles-${stamp}/${label}"
  mkdir -p -- "$root"
  printf '%s/%s\n' "$root" "$rel"
}
backup_path_if_present() {
  local src="$1" backup="$2"
  [[ -e "$src" || -L "$src" ]] || return 0
  mkdir -p -- "$(dirname "$backup")"
  cp -a -- "$src" "$backup"
}
restore_path_from_backup_if_present() {
  local dst="$1" backup="$2"
  rm -rf -- "$dst"
  [[ -e "$backup" || -L "$backup" ]] || return 0
  mkdir -p -- "$(dirname "$dst")"
  cp -a -- "$backup" "$dst"
}
create_link_for_rel() {
  local name="$1" rel="$2" home_path target current
  rel="$(normalize_home_rel "$rel")"
  home_path="$(home_target_for "$name" "$rel")"
  target="$(link_target_for "$name" "$rel")"
  mkdir -p -- "$(dirname "$home_path")"
  ensure_target_placeholder "$name" "$rel"
  links_file_add "$name" "$rel"
  if [[ -L "$home_path" ]]; then
    current="$(readlink "$home_path")"
    [[ "$current" == "$target" ]] && return 0
    rm -f -- "$home_path"
  elif [[ -e "$home_path" ]]; then
    if path_is_effectively_empty "$home_path"; then rm -rf -- "$home_path"; else die "Profile path already exists as a real file or directory: $home_path (use adopt or repair)"; fi
  fi
  ln -s -- "$target" "$home_path"
}
adopt_rel() {
  local name="$1" rel="$2" home_path target current kind
  local source_backup target_backup stage created_target=0 removed_source=0
  rel="$(normalize_home_rel "$rel")"
  home_path="$(home_target_for "$name" "$rel")"
  target="$(link_target_for "$name" "$rel")"
  mkdir -p -- "$(dirname "$home_path")" "$(dirname "$target")"
  links_file_add "$name" "$rel"
  if [[ -L "$home_path" ]]; then
    current="$(readlink "$home_path")"
    [[ "$current" == "$target" ]] && return 0
    rm -f -- "$home_path"
  fi
  if [[ ! -e "$home_path" ]]; then
    ensure_target_placeholder "$name" "$rel"
    ln -s -- "$target" "$home_path"
    return 0
  fi
  source_backup="$(_dotfiles_backup_path "$name" "$rel" source)"
  target_backup="$(_dotfiles_backup_path "$name" "$rel" target)"
  backup_path_if_present "$home_path" "$source_backup"
  backup_path_if_present "$target" "$target_backup"
  warn "Backups created before adopt for $rel"
  stage="$(create_temp_dir)/incoming"
  kind="$(infer_target_kind "$rel" "$home_path" "$target")"
  if [[ "$kind" == 'dir' ]]; then mkdir -p -- "$stage"; copy_tree "$home_path" "$stage"; else mkdir -p -- "$(dirname "$stage")"; cp -a -- "$home_path" "$stage"; fi
  rm -rf -- "$target"
  mv -- "$stage" "$target"
  created_target=1
  rm -rf -- "$home_path"
  removed_source=1
  if ! ln -s -- "$target" "$home_path"; then
    warn "Failed to create symlink after adopt; attempting restore for: $rel"
    rm -rf -- "$home_path"
    if (( removed_source == 1 )); then restore_path_from_backup_if_present "$home_path" "$source_backup"; fi
    if (( created_target == 1 )); then restore_path_from_backup_if_present "$target" "$target_backup"; fi
    die_with_code "$EX_IOERR" "Failed to create symlink after adopt: $home_path"
  fi
}
prepare_links() {
  local name="$1"; shift || true; local rel
  if [[ $# -eq 0 ]]; then while IFS= read -r rel; do ensure_target_placeholder "$name" "$rel"; done < <(links_default_paths); else for rel in "$@"; do rel="$(normalize_home_rel "$rel")"; ensure_target_placeholder "$name" "$rel"; done; fi
}
backup_existing_path() {
  local name="$1" rel="$2" home_path backup_path
  home_path="$(home_target_for "$name" "$rel")"
  backup_path="$(_dotfiles_backup_path "$name" "$rel" repair-conflicts)"
  [[ -e "$home_path" || -L "$home_path" ]] || return 0
  mkdir -p -- "$(dirname "$backup_path")"
  mv -- "$home_path" "$backup_path"
  warn "Backed up conflicting profile path to: $backup_path"
}
repair_rel() {
  local name="$1" rel="$2" home_path target current
  rel="$(normalize_home_rel "$rel")"
  home_path="$(home_target_for "$name" "$rel")"
  target="$(link_target_for "$name" "$rel")"
  mkdir -p -- "$(dirname "$home_path")" "$(dirname "$target")"
  links_file_add "$name" "$rel"
  if [[ -L "$home_path" ]]; then current="$(readlink "$home_path")"; if [[ "$current" == "$target" ]]; then return 0; fi; rm -f -- "$home_path"; ensure_target_placeholder "$name" "$rel"; ln -s -- "$target" "$home_path"; success "Re-linked $rel"; return 0; fi
  if [[ ! -e "$home_path" ]]; then ensure_target_placeholder "$name" "$rel"; ln -s -- "$target" "$home_path"; success "Restored missing link for $rel"; return 0; fi
  if [[ ! -e "$target" && ! -L "$target" ]]; then mkdir -p -- "$(dirname "$target")"; mv -- "$home_path" "$target"; ln -s -- "$target" "$home_path"; success "Moved current profile content into managed target for $rel"; return 0; fi
  backup_existing_path "$name" "$rel"; ensure_target_placeholder "$name" "$rel"; ln -s -- "$target" "$home_path"; success "Repaired link for $rel"
}
repair_recorded_links() { local name="$1" rel; while IFS= read -r rel; do [[ -n "$rel" ]] || continue; repair_rel "$name" "$rel"; done < <(links_file_list "$name"); }
link_status_for_rel() {
  local name="$1" rel="$2" home_path target state current
  home_path="$(home_target_for "$name" "$rel")"; target="$(link_target_for "$name" "$rel")"
  if [[ -L "$home_path" ]]; then current="$(readlink "$home_path")"; if [[ "$current" == "$target" ]]; then state='linked'; else state='wrong-link'; fi; elif [[ -e "$home_path" ]]; then state='real-path'; else state='missing-home'; fi
  if [[ ! -e "$target" && ! -L "$target" ]]; then state="${state}+missing-target"; fi
  printf '%-18s %-22s %s\n' "$name" "$state" "$rel"
}
show_links_status() {
  local requested="${1:-}" rel name profile
  printf '%-18s %-22s %s\n' 'PROFILE' 'STATE' 'PATH'; printf '%-18s %-22s %s\n' '-------' '-----' '----'
  if [[ -n "$requested" ]]; then safe_name "$requested"; while IFS= read -r rel; do [[ -n "$rel" ]] || continue; link_status_for_rel "$requested" "$rel"; done < <(links_file_list "$requested"); return 0; fi
  for profile in "$ID_PROFILES_ROOT"/*; do [[ -d "$profile" ]] || continue; name="$(basename "$profile")"; while IFS= read -r rel; do [[ -n "$rel" ]] || continue; link_status_for_rel "$name" "$rel"; done < <(links_file_list "$name"); done
}
audit_recorded_links() {
  local name="$1" rel home_path target current issues=0
  while IFS= read -r rel; do [[ -n "$rel" ]] || continue; home_path="$(home_target_for "$name" "$rel")"; target="$(link_target_for "$name" "$rel")"; if [[ -L "$home_path" ]]; then current="$(readlink "$home_path")"; [[ "$current" == "$target" ]] || { warn "Managed path drift for $name: $rel points to $current"; issues=1; }; else warn "Managed path drift for $name: $rel is not a symlink"; issues=1; fi; if [[ ! -e "$target" && ! -L "$target" ]]; then warn "Managed target missing for $name: $rel"; issues=1; fi; done < <(links_file_list "$name")
  return "$issues"
}
