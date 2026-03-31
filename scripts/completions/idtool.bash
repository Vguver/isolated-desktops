# bash completion for idtool
_idtool_profiles() {
  local root config
  root="${IDTOOL_COMPLETION_ROOT:-${ID_ROOT:-$HOME/isolated-desktops}}"
  config="${IDTOOL_COMPLETION_CONFIG:-$HOME/.config/isolated-desktops/profiles.d}"
  {
    if [[ -d "$root/manifests" ]]; then
      find "$root/manifests" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null | sed 's/\.json$//'
    fi
    if [[ -d "$config" ]]; then
      find "$config" -maxdepth 1 -type f -name '*.json' -printf '%f\n' 2>/dev/null | sed 's/\.json$//'
    fi
  } | sort -u
}
_idtool_presets() { local root; root="${IDTOOL_COMPLETION_ROOT:-${ID_ROOT:-$HOME/isolated-desktops}}"; if [[ -d "$root/presets" ]]; then find "$root/presets" -maxdepth 1 -type f -name '*.txt' -printf '%f\n' 2>/dev/null | sed 's/\.txt$//'; fi; }
_idtool_trash_entries() { local root; root="${IDTOOL_COMPLETION_TRASH:-$HOME/.local/share/isolated-desktops/trash}"; if [[ -d "$root" ]]; then find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort; fi; }
_idtool_complete() {
  local cur prev prev2 cword words
  COMPREPLY=()
  words=("${COMP_WORDS[@]}")
  cword="$COMP_CWORD"
  cur="${words[cword]:-}"
  prev="${words[cword-1]:-}"
  prev2="${words[cword-2]:-}"
  case "$prev" in
    idtool) COMPREPLY=( $(compgen -W 'bootstrap list status analyze install update verify start shell launcher session open links workspace sync export import preset trash completion self-update extract compare remove help' -- "$cur") ); return 0 ;;
    analyze|install|update|verify|start|shell|export|remove) COMPREPLY=( $(compgen -W "$(_idtool_profiles)" -- "$cur") ); return 0 ;;
    create) case "$prev2" in launcher|session|workspace) COMPREPLY=( $(compgen -W "$(_idtool_profiles)" -- "$cur") ); return 0 ;; esac ;;
    open) if (( cword == 2 )); then COMPREPLY=( $(compgen -W 'home repo logs reports dotfiles workspace' -- "$cur") ); else COMPREPLY=( $(compgen -W "$(_idtool_profiles)" -- "$cur") ); fi; return 0 ;;
    prepare|link|adopt|repair|status) if [[ "$prev2" == 'links' ]]; then COMPREPLY=( $(compgen -W "$(_idtool_profiles)" -- "$cur") ); return 0; fi ;;
    show|install) if [[ "$prev2" == 'preset' ]]; then COMPREPLY=( $(compgen -W "$(_idtool_presets)" -- "$cur") ); return 0; fi ;;
    restore) if [[ "$prev2" == 'trash' ]]; then COMPREPLY=( $(compgen -W "$(_idtool_trash_entries)" -- "$cur") ); return 0; fi ;;
  esac
}
complete -F _idtool_complete idtool
