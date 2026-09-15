#!/bin/bash
# Shared terminal components for KatsuTun menus.
# Palette follows the dashboard reference: blue frame, gold labels, green values.
# KATSU_ASCII=1 forces ASCII borders, NO_COLOR disables colours.

ui_init() {
    local theme cols
    theme=$(cat /etc/yudhynetwork/theme/color.conf 2>/dev/null || printf 'blue')
    case "$theme" in
        red)     UI_ACCENT='\033[38;5;203m'; UI_BAR='\033[1;37;48;5;124m' ;;
        green)   UI_ACCENT='\033[38;5;78m';  UI_BAR='\033[1;37;48;5;29m' ;;
        yellow)  UI_ACCENT='\033[38;5;220m'; UI_BAR='\033[1;30;48;5;178m' ;;
        magenta) UI_ACCENT='\033[38;5;177m'; UI_BAR='\033[1;37;48;5;91m' ;;
        cyan)    UI_ACCENT='\033[38;5;80m';  UI_BAR='\033[1;37;48;5;30m' ;;
        blue|*)  UI_ACCENT='\033[38;5;75m';  UI_BAR='\033[1;37;48;5;25m' ;;
    esac
    UI_MUTED='\033[38;5;245m'
    UI_TEXT='\033[38;5;252m'
    UI_LABEL='\033[38;5;222m'
    UI_GOOD='\033[38;5;80m'
    UI_WARN='\033[38;5;220m'
    UI_BAD='\033[38;5;203m'
    UI_BOLD='\033[1m'
    UI_RESET='\033[0m'
    if [ -n "$NO_COLOR" ]; then
        UI_ACCENT= UI_BAR= UI_MUTED= UI_TEXT= UI_LABEL= UI_GOOD= UI_WARN= UI_BAD= UI_BOLD= UI_RESET=
    fi

    # bash counts ${#var} in bytes under the C locale, which breaks padding
    # around box characters; use a UTF-8 locale or fall back to ASCII.
    if [ "${KATSU_ASCII:-0}" != "1" ]; then
        case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in
            *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;;
            *) if locale -a 2>/dev/null | grep -qi '^C\.utf-\?8$'; then export LC_ALL=C.UTF-8
               elif locale -a 2>/dev/null | grep -qi '^en_US\.utf-\?8$'; then export LC_ALL=en_US.UTF-8
               else KATSU_ASCII=1; fi ;;
        esac
    fi
    if [ "${KATSU_ASCII:-0}" = "1" ]; then
        UI_TL='+' UI_TR='+' UI_BL='+' UI_BR='+' UI_H='-' UI_V='|' UI_DOT='*' UI_ARROW='>'
    else
        UI_TL='╭' UI_TR='╮' UI_BL='╰' UI_BR='╯' UI_H='─' UI_V='│' UI_DOT='•' UI_ARROW='›'
    fi
    cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 60)}
    UI_WIDTH=$(( cols > 60 ? 60 : cols ))
    [ "$UI_WIDTH" -lt 36 ] && UI_WIDTH=36
    UI_INNER=$(( UI_WIDTH - 4 ))
}

ui_clear() { clear 2>/dev/null || printf '\033c'; }
ui_plain() { printf '%b' "$*" | sed 's/\x1b\[[0-9;]*m//g'; }
ui_vlen() { local s; s=$(ui_plain "$1"); printf '%s' "${#s}"; }
ui_repeat() { local i out=''; for ((i = 0; i < $2; i++)); do out+=$1; done; printf '%s' "$out"; }
ui_pad() { local n; n=$(( $2 - $(ui_vlen "$1") )); printf '%b%s' "$1" "$( (( n > 0 )) && ui_repeat ' ' "$n")"; }
ui_fit() {  # ui_fit TEXT WIDTH : truncate plain text to WIDTH cells
    local s; s=$(ui_plain "$1")
    [ "${#s}" -gt "$2" ] && s="${s:0:$(( $2 - 1 ))}~"
    printf '%s' "$s"
}

ui_edge() {  # ui_edge LEFT RIGHT [LABEL]
    local rule label=$3
    if [ -n "$label" ]; then
        rule="${UI_H} ${UI_RESET}${UI_BOLD}${UI_TEXT}${label}${UI_RESET}${UI_ACCENT} $(ui_repeat "$UI_H" $(( UI_WIDTH - ${#label} - 5 )))"
    else
        rule=$(ui_repeat "$UI_H" $(( UI_WIDTH - 2 )))
    fi
    printf '%b%s%b%s%b\n' "$UI_ACCENT" "$1" "$rule" "$2" "$UI_RESET"
}
ui_top() { ui_edge "$UI_TL" "$UI_TR" "$1"; }
ui_bottom() { ui_edge "$UI_BL" "$UI_BR"; }
ui_divider() { ui_edge "$UI_V" "$UI_V"; }
ui_line() {  # one framed row, padded (or clipped) to the frame width
    local text=" $*"
    if [ "$(ui_vlen "$text")" -gt "$UI_INNER" ]; then text=$(ui_fit "$text" "$UI_INNER"); fi
    printf '%b%s%b %b%b %b%s%b\n' "$UI_ACCENT" "$UI_V" "$UI_RESET" \
        "$(ui_pad "$text" "$UI_INNER")" "$UI_RESET" "$UI_ACCENT" "$UI_V" "$UI_RESET"
}
ui_blank() { ui_line ''; }
ui_center() {
    local text n
    text=$1
    if [ "$(ui_vlen "$text")" -gt $(( UI_INNER - 2 )) ]; then text=$(ui_fit "$text" $(( UI_INNER - 2 ))); fi
    n=$(( (UI_INNER - $(ui_vlen "$text")) / 2 - 1 ))
    ui_line "$(ui_repeat ' ' $(( n > 0 ? n : 0 )))$text"
}

ui_title() {  # ui_title TITLE [SUBTITLE] : reference-style filled title bar
    local title; title=$(ui_fit "$1" $(( UI_INNER - 2 )))
    local n=$(( (UI_INNER - ${#title}) / 2 ))
    ui_top
    ui_line "${UI_BAR}$(ui_repeat ' ' "$n")${title}$(ui_repeat ' ' $(( UI_INNER - n - ${#title} - 1 )))${UI_RESET}"
    [ -n "$2" ] && ui_center "${UI_MUTED}$2${UI_RESET}"
    ui_bottom
}
ui_header() { ui_title "${BRAND:-KATSUTUN} ${UI_DOT} $1" "$2"; }

ui_card_start() { ui_top "$1"; }
ui_card_end() { ui_bottom; }
ui_kv() { ui_line "$(ui_pad "${UI_LABEL}$1${UI_RESET}" 12)${UI_ACCENT}:${UI_RESET} ${UI_TEXT}$2${UI_RESET}"; }
ui_notice() { ui_line "${UI_ACCENT}${UI_DOT}${UI_RESET} $1"; }
ui_ok()   { ui_line "${UI_GOOD}[OK]${UI_RESET} $*"; }
ui_warn() { ui_line "${UI_WARN}[!]${UI_RESET} $(ui_fit "$*" $((UI_INNER - 5)))"; }
ui_err()  { ui_line "${UI_BAD}[ERROR]${UI_RESET} $*"; }
ui_badge() {  # ui_badge STATE : coloured ON/OFF style word
    case "$1" in
        active|running|on|ON|ONLINE) printf '%b' "${UI_GOOD}ON${UI_RESET}" ;;
        ''|N/A|unknown) printf '%b' "${UI_MUTED}N/A${UI_RESET}" ;;
        *) printf '%b' "${UI_BAD}OFF${UI_RESET}" ;;
    esac
}

ui_option() {  # ui_option NUMBER LABEL [NOTE] : returns one option cell
    local note=''; [ -n "$3" ] && note=" ${UI_MUTED}$3${UI_RESET}"
    printf '%b' "${UI_LABEL}[$(printf '%02d' "$((10#$1))")]${UI_RESET} ${UI_TEXT}$2${UI_RESET}$note"
}
ui_options() {  # ui_options "NN:Label[:note]" ... : two columns when the frame is wide enough
    local items=("$@") i half cell left right
    if [ "$UI_INNER" -ge 52 ]; then
        half=$(( (UI_INNER - 2) / 2 ))
        for ((i = 0; i < ${#items[@]}; i += 2)); do
            IFS=: read -r n l x <<<"${items[i]}"; left=$(ui_option "$n" "$l" "$x")
            right=''
            if [ -n "${items[i+1]}" ]; then IFS=: read -r n l x <<<"${items[i+1]}"; right=$(ui_option "$n" "$l" "$x"); fi
            ui_line "$(ui_pad "$left" "$half")$right"
        done
    else
        for cell in "${items[@]}"; do
            [ -z "$cell" ] && continue
            IFS=: read -r n l x <<<"$cell"; ui_line "$(ui_option "$n" "$l" "$x")"
        done
    fi
}
ui_menu_pair() { ui_options "$1:$2:$3" "$4:$5:$6"; }
ui_menu_item() { ui_line "$(ui_option "$1" "$2" "$3")"; }

ui_copy() {  # ui_copy LABEL VALUE : full-width value meant to be copied (never clipped)
    printf '%b%s%b\n' "$UI_LABEL" "$1" "$UI_RESET"
    printf '%b%s%b\n\n' "$UI_TEXT" "$2" "$UI_RESET"
}
ui_footer() { printf '  %b%s %s %s %s%b\n' "$UI_MUTED" "$(ui_repeat "$UI_H" 3)" "${BRAND:-KatsuTun}" "$UI_DOT" "$(date '+%d %b %Y %H:%M')" "$UI_RESET"; }
ui_back_hint() { printf '  %b[00]%b %bBack%b   %b[x]%b %bExit%b\n' "$UI_LABEL" "$UI_RESET" "$UI_MUTED" "$UI_RESET" "$UI_LABEL" "$UI_RESET" "$UI_MUTED" "$UI_RESET"; }
ui_prompt() { printf '\n%b%s%b %b%s%b ' "$UI_ACCENT" "$UI_ARROW" "$UI_RESET" "$UI_TEXT" "${1:-Select an option:}" "$UI_RESET"; }
ui_pause() { printf '\n%b%s%b Press any key to continue' "$UI_ACCENT" "$UI_ARROW" "$UI_RESET"; read -r -n 1 -s; printf '\n'; }
ui_screen() {  # ui_screen TITLE [SUBTITLE] : clear and draw the title bar
    ui_clear; ui_title "$1" "$2"
}
