#!/bin/bash
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf

UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
ui_clear

ui_header "APPEARANCE" "PERSONALIZE YOUR PANEL"
ui_card_start
ui_notice "Choose an accent color for this server."
ui_blank
ui_menu_pair 1 "BLUE" "COOL" 4 "CYAN" "DEFAULT"
ui_menu_pair 2 "RED" "BOLD" 5 "GREEN" "FRESH"
ui_menu_pair 3 "YELLOW" "WARM" 6 "MAGENTA" "VIVID"
ui_blank
ui_menu_item 0 "BACK TO DASHBOARD" "EXIT"
ui_card_end
ui_footer
ui_prompt
read -r colormenu

case $colormenu in
    01|1) selected=blue ; label="Blue" ;;
    02|2) selected=red ; label="Red" ;;
    03|3) selected=yellow ; label="Yellow" ;;
    04|4) selected=cyan ; label="Cyan" ;;
    05|5) selected=green ; label="Green" ;;
    06|6) selected=magenta ; label="Magenta" ;;
    00|0) clear; menu; exit 0 ;;
    *) clear; exec menu-theme ;;
esac

printf '%s\n' "$selected" > /etc/yudhynetwork/theme/color.conf
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
ui_clear
ui_header "THEME UPDATED" "APPEARANCE"
ui_card_start
ui_notice "${UI_GOOD}✓${UI_RESET} ${UI_TEXT}${label}${UI_RESET} is now the active accent color."
ui_card_end
ui_footer
printf '\nPress any key to return to Appearance…'
read -r -n 1 -s
exec menu-theme
