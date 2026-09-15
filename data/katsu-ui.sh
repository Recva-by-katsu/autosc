#!/bin/bash
# Shared terminal components for KatsuTun menus. Set KATSU_ASCII=1 for legacy terminals.

ui_init() {
    local theme
    theme=$(cat /etc/yudhynetwork/theme/color.conf 2>/dev/null || printf 'cyan')
    case "$theme" in
        blue)    UI_ACCENT='\033[38;5;39m' ;;
        red)     UI_ACCENT='\033[38;5;203m' ;;
        green)   UI_ACCENT='\033[38;5;49m' ;;
        yellow)  UI_ACCENT='\033[38;5;220m' ;;
        magenta) UI_ACCENT='\033[38;5;213m' ;;
        cyan|*)  UI_ACCENT='\033[38;5;51m' ;;
    esac
    UI_MUTED='\033[38;5;245m'
    UI_TEXT='\033[38;5;255m'
    UI_GOOD='\033[38;5;48m'
    UI_WARN='\033[38;5;220m'
    UI_BAD='\033[38;5;203m'
    UI_BOLD='\033[1m'
    UI_RESET='\033[0m'
    if [ -n "$NO_COLOR" ]; then
        UI_ACCENT= UI_MUTED= UI_TEXT= UI_GOOD= UI_WARN= UI_BAD= UI_BOLD= UI_RESET=
    fi
    if [ "${KATSU_ASCII:-0}" = "1" ]; then
        UI_TL='+' UI_TR='+' UI_BL='+' UI_BR='+' UI_H='-' UI_V='|'
    else
        UI_TL='╭' UI_TR='╮' UI_BL='╰' UI_BR='╯' UI_H='─' UI_V='│'
    fi
}

ui_clear() { clear; }
ui_line() { printf '%b%b%b%b\n' "$UI_ACCENT" "$UI_V" "  $*" "$UI_RESET"; }
ui_edge() { printf '%b%b%b%b%b\n' "$UI_ACCENT" "$1" "$(printf '%*s' 57 '' | tr ' ' "$UI_H")" "$2" "$UI_RESET"; }
ui_top() { ui_edge "$UI_TL" "$UI_TR"; }
ui_bottom() { ui_edge "$UI_BL" "$UI_BR"; }
ui_divider() { printf '%b%b%b%b%b\n' "$UI_ACCENT" "$UI_V" "$(printf '%*s' 57 '' | tr ' ' "$UI_H")" "$UI_V" "$UI_RESET"; }
ui_blank() { ui_line ''; }

ui_header() {
    local title=$1 subtitle=${2:-CONTROL CENTER}
    ui_top
    ui_line "${UI_BOLD}${UI_TEXT}  KATSUTUN${UI_RESET} ${UI_MUTED}• ${subtitle}${UI_RESET}"
    ui_line "${UI_ACCENT}${UI_BOLD}  ${title}${UI_RESET}"
    ui_bottom
}

ui_card_start() { ui_top; }
ui_card_end() { ui_bottom; }
ui_kv() { ui_line "${UI_MUTED}  $1${UI_RESET}  ${UI_TEXT}$2${UI_RESET}"; }
ui_notice() { ui_line "${UI_ACCENT}  $1${UI_RESET}"; }
ui_menu_pair() {
    printf '%b%b  %b[%02d]%b %-20b %b[%b]%b    %b[%02d]%b %-20b %b[%b]%b  %b%b\n' \
        "$UI_ACCENT" "$UI_V" "$UI_TEXT" "$1" "$UI_RESET" "$2" "$UI_MUTED" "$3" "$UI_RESET" \
        "$UI_TEXT" "$4" "$UI_RESET" "$5" "$UI_MUTED" "$6" "$UI_RESET" "$UI_ACCENT" "$UI_RESET"
}
ui_menu_item() {
    printf '%b%b  %b[%02d]%b %-20b %b[%b]%b%b\n' \
        "$UI_ACCENT" "$UI_V" "$UI_TEXT" "$1" "$UI_RESET" "$2" "$UI_MUTED" "$3" "$UI_RESET" "$UI_RESET"
}
ui_footer() {
    ui_top
    ui_line "${UI_MUTED}  Secure VPS automation • ${UI_TEXT}${BRAND:-KatsuTun}${UI_RESET}"
    ui_bottom
}
ui_prompt() { printf '\n%b›%b Select an option: ' "$UI_ACCENT" "$UI_RESET"; }
