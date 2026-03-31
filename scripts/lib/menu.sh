#!/usr/bin/env bash
set -euo pipefail
show_main_menu() {
  while true; do
    cat <<'EOM'
1) Status dashboard
2) List profiles
3) Analyze profile
4) Install profile
5) Update profile
6) Verify profile
7) Start profile
8) Open shell inside profile home
9) Create launcher
10) Create session
11) Prepare managed dotfiles
12) Repair managed dotfiles links
13) Create or open editor workspace
14) Sync profile snapshot
15) Export profile
16) Import profile archive
17) Install preset
18) Compare profiles
19) Remove profile
20) Trash tools
21) Install bash completion
22) Self-update project checkout
0) Exit
EOM
    read -r -p 'Select: ' choice
    case "$choice" in
      1) "$ID_ROOT/scripts/idtool.sh" status ;;
      2) "$ID_ROOT/scripts/idtool.sh" list ;;
      3) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" analyze "$name" ;;
      4) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" install "$name" ;;
      5) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" update "$name" ;;
      6) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" verify "$name" ;;
      7) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" start "$name" ;;
      8) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" shell "$name" ;;
      9) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" launcher create "$name" ;;
      10) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" session create "$name" ;;
      11) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" links prepare "$name" ;;
      12) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" links repair "$name" ;;
      13) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" workspace open "$name" ;;
      14) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" sync "$name" ;;
      15) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" export "$name" ;;
      16) read -r -p 'Archive path: ' archive; "$ID_ROOT/scripts/idtool.sh" import "$archive" ;;
      17) read -r -p 'Preset name: ' preset; "$ID_ROOT/scripts/idtool.sh" preset install "$preset" ;;
      18) read -r -p 'Left profile: ' left; read -r -p 'Right profile: ' right; "$ID_ROOT/scripts/idtool.sh" compare "$left" "$right" ;;
      19) read -r -p 'Profile name: ' name; "$ID_ROOT/scripts/idtool.sh" remove "$name" ;;
      20)
        echo '1) List trash'
        echo '2) Restore trash entry'
        echo '3) Purge old trash'
        read -r -p 'Choice [1-3]: ' tchoice
        case "$tchoice" in
          1) "$ID_ROOT/scripts/idtool.sh" trash list ;;
          2) read -r -p 'Trash entry: ' entry; "$ID_ROOT/scripts/idtool.sh" trash restore "$entry" ;;
          3) "$ID_ROOT/scripts/idtool.sh" trash purge ;;
          *) echo 'Invalid choice' ;;
        esac
        ;;
      21) "$ID_ROOT/scripts/idtool.sh" completion install ;;
      22) "$ID_ROOT/scripts/idtool.sh" self-update ;;
      0) exit 0 ;;
      *) echo 'Invalid choice' ;;
    esac
    echo
  done
}
