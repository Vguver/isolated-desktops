#!/usr/bin/env bash
set -euo pipefail
ID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ID_ROOT
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/common.sh"
# shellcheck source=/dev/null
source "$ID_ROOT/scripts/lib/paths.sh"

name="${1:-}"
module="${2:-}"
destination="${3:-$PWD/extracted-$module-$name}"
[[ -n "$name" && -n "$module" ]] || die "Usage: idtool extract <profile> <module-or-path> [destination]"

case "$module" in
  hypr) src_rel='.config/hypr' ;;
  waybar) src_rel='.config/waybar' ;;
  kitty) src_rel='.config/kitty' ;;
  rofi) src_rel='.config/rofi' ;;
  dunst) src_rel='.config/dunst' ;;
  gtk3) src_rel='.config/gtk-3.0' ;;
  gtk4) src_rel='.config/gtk-4.0' ;;
  *) src_rel="$module" ;;
esac
src="$(profile_home_dir "$name")/$src_rel"
[[ -e "$src" ]] || die "Module or path not found in profile: $src_rel"
copy_tree "$src" "$destination"
info "Extracted $src_rel to $destination"
