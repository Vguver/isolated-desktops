#!/usr/bin/env bash
set -euo pipefail
source "$ID_ROOT/scripts/lib/common.sh"
source "$ID_ROOT/scripts/lib/paths.sh"
ID_LOCK_MODE=''
ID_LOCK_TOKEN=''
ID_LOCK_PATH=''
ID_LOCK_FD=''
lock_dir_root() { printf '%s/locks\n' "$ID_STATE_ROOT"; }
profile_lock_path() { printf '%s/%s.lock\n' "$(lock_dir_root)" "$1"; }
_lock_token_dir() { printf '%s.d\n' "$1"; }
_lock_token_meta() { printf '%s/owner.tsv\n' "$(_lock_token_dir "$1")"; }
_lock_write_meta() { local file="$1"; printf 'pid\t%s\nhost\t%s\nstarted\t%s\n' "$$" "$(hostname 2>/dev/null || echo unknown)" "$(date +%s)" > "$file"; }
_lock_owner_summary() { local file="$1" pid host started; [[ -f "$file" ]] || return 1; pid="$(awk -F $'\t' '$1=="pid" {print $2; exit}' "$file" 2>/dev/null || true)"; host="$(awk -F $'\t' '$1=="host" {print $2; exit}' "$file" 2>/dev/null || true)"; started="$(awk -F $'\t' '$1=="started" {print $2; exit}' "$file" 2>/dev/null || true)"; printf 'pid=%s host=%s started=%s' "${pid:-unknown}" "${host:-unknown}" "${started:-unknown}"; }
_lock_owner_alive() { local meta="$1" pid=''; [[ -f "$meta" ]] || return 1; pid="$(awk -F $'\t' '$1=="pid" {print $2; exit}' "$meta" 2>/dev/null || true)"; [[ "$pid" =~ ^[0-9]+$ ]] || return 1; kill -0 "$pid" 2>/dev/null; }
_acquire_flock_lock() {
  local path="$1" owner=''
  mkdir -p -- "$(dirname "$path")"
  exec {ID_LOCK_FD}>"$path"
  if ! flock -n "$ID_LOCK_FD"; then
    owner="$(_lock_owner_summary "$path" 2>/dev/null || true)"
    [[ -n "$owner" ]] && die_with_code "$EX_TEMPFAIL" "Another operation is already running for: $(basename "$path" .lock) ($owner)"
    die_with_code "$EX_TEMPFAIL" "Another operation is already running for: $(basename "$path" .lock)"
  fi
  _lock_write_meta "$path"
  ID_LOCK_MODE='flock'
  ID_LOCK_PATH="$path"
}
_maybe_break_stale_mkdir_lock() {
  local path="$1" token meta age now mtime
  token="$(_lock_token_dir "$path")"
  meta="$(_lock_token_meta "$path")"
  [[ -d "$token" ]] || return 0
  if [[ -f "$meta" ]]; then
    if _lock_owner_alive "$meta"; then return 1; fi
    warn "Breaking stale lock for $(basename "$path" .lock): owner process is no longer alive"
    rm -rf -- "$token"
    return 0
  fi
  now="$(date +%s)"
  mtime="$(stat -c %Y "$token" 2>/dev/null || echo 0)"
  [[ "$mtime" =~ ^[0-9]+$ ]] || mtime=0
  age=$(( now - mtime ))
  if (( age >= ID_LOCK_STALE_SECONDS )); then
    warn "Breaking stale lock for $(basename "$path" .lock): metadata missing and age ${age}s exceeds threshold"
    rm -rf -- "$token"
    return 0
  fi
  return 1
}
_acquire_mkdir_lock() {
  local path="$1" token meta owner=''
  token="$(_lock_token_dir "$path")"
  meta="$(_lock_token_meta "$path")"
  mkdir -p -- "$(dirname "$token")"
  if ! mkdir "$token" 2>/dev/null; then
    _maybe_break_stale_mkdir_lock "$path" || {
      owner="$(_lock_owner_summary "$meta" 2>/dev/null || true)"
      [[ -n "$owner" ]] && die_with_code "$EX_TEMPFAIL" "Another operation is already running for: $(basename "$path" .lock) ($owner)"
      die_with_code "$EX_TEMPFAIL" "Another operation is already running for: $(basename "$path" .lock)"
    }
    mkdir "$token" 2>/dev/null || die_with_code "$EX_TEMPFAIL" "Another operation is already running for: $(basename "$path" .lock)"
  fi
  _lock_write_meta "$meta"
  ID_LOCK_MODE='mkdir'
  ID_LOCK_TOKEN="$token"
  ID_LOCK_PATH="$path"
}
acquire_profile_lock() { local name="$1" path; path="$(profile_lock_path "$name")"; if have_cmd flock; then _acquire_flock_lock "$path"; else _acquire_mkdir_lock "$path"; fi; }
release_profile_lock() {
  case "$ID_LOCK_MODE" in
    flock)
      if [[ -n "$ID_LOCK_FD" ]]; then flock -u "$ID_LOCK_FD" 2>/dev/null || true; eval "exec ${ID_LOCK_FD}>&-" || true; fi
      [[ -n "$ID_LOCK_PATH" ]] && rm -f -- "$ID_LOCK_PATH" 2>/dev/null || true
      ;;
    mkdir)
      [[ -n "$ID_LOCK_TOKEN" ]] && rm -rf -- "$ID_LOCK_TOKEN" 2>/dev/null || true
      ;;
  esac
  ID_LOCK_MODE=''; ID_LOCK_TOKEN=''; ID_LOCK_PATH=''; ID_LOCK_FD=''
}
