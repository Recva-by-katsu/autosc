#!/bin/bash
# Shared terminal components for KatsuTun Premium menus.
#
# Design: blue frame, gold labels, green values, dim hints. Every framed row is
# padded or clipped to exactly one width so a menu never shreds on a narrow
# phone terminal. KATSU_ASCII=1 forces ASCII borders, NO_COLOR disables colours.
#
# All components keep the historic signatures so older menus keep working.

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
    UI_DIM='\033[2m'
    UI_RESET='\033[0m'
    if [ -n "$NO_COLOR" ]; then
        UI_ACCENT= UI_BAR= UI_MUTED= UI_TEXT= UI_LABEL= UI_GOOD= UI_WARN= UI_BAD= UI_BOLD= UI_DIM= UI_RESET=
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
        UI_TL='+' UI_TR='+' UI_BL='+' UI_BR='+' UI_H='-' UI_V='|'
        UI_DOT='*' UI_ARROW='>' UI_BULLET='*' UI_ONLINE='*' UI_OFFLINE='o'
        UI_SEP='|'
    else
        UI_TL='╭' UI_TR='╮' UI_BL='╰' UI_BR='╯' UI_H='─' UI_V='│'
        UI_DOT='•' UI_ARROW='❯' UI_BULLET='▪' UI_ONLINE='●' UI_OFFLINE='○'
        UI_SEP='│'
    fi
    cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 60)}
    UI_WIDTH=$(( cols > 60 ? 60 : cols ))
    [ "$UI_WIDTH" -lt 36 ] && UI_WIDTH=36
    UI_INNER=$(( UI_WIDTH - 4 ))
    [ -r /opt/.ver ] && UI_VERSION=$(head -n1 /opt/.ver 2>/dev/null) || UI_VERSION=''
}

# ---------------------------------------------------------------- low level
ui_clear() { clear 2>/dev/null || printf '\033c'; }
ui_plain() { printf '%b' "$*" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
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
        local plain; plain=$(ui_plain "$label")
        rule="${UI_H} ${UI_RESET}${UI_BOLD}${UI_TEXT}${label}${UI_RESET}${UI_ACCENT} $(ui_repeat "$UI_H" $(( UI_WIDTH - ${#plain} - 5 )))"
    else
        rule=$(ui_repeat "$UI_H" $(( UI_WIDTH - 2 )))
    fi
    printf '%b%s%b%s%b\n' "$UI_ACCENT" "$1" "$rule" "$2" "$UI_RESET"
}
ui_top() { ui_edge "$UI_TL" "$UI_TR" "$1"; }
ui_bottom() { ui_edge "$UI_BL" "$UI_BR"; }
ui_divider() { ui_edge "$UI_V" "$UI_V"; }
ui_soft_divider() {  # dim rule inside a card
    ui_line "${UI_DIM}$(ui_repeat "$UI_H" $(( UI_INNER - 2 )))${UI_RESET}"
}
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
ui_right() {  # ui_right LABEL VALUE : value pushed to the right edge
    local gap
    gap=$(( UI_INNER - $(ui_vlen "$1") - $(ui_vlen "$2") - 1 ))
    [ "$gap" -lt 1 ] && gap=1
    ui_line "$1$(ui_repeat ' ' "$gap")$2"
}

# ---------------------------------------------------------------- titles
ui_title() {  # ui_title TITLE [SUBTITLE] : filled title bar + optional subtitle
    local title tag bar taglen n
    title=$(ui_fit "$1" $(( UI_INNER - 4 )))
    tag=${3:-$UI_VERSION}
    ui_top
    if [ -n "$tag" ]; then
        taglen=$(ui_vlen "$tag")
        n=$(( UI_INNER - ${#title} - taglen - 4 ))
        [ "$n" -lt 1 ] && n=1
        ui_line "${UI_BAR} ${UI_BOLD}${title}${UI_RESET}${UI_BAR}$(ui_repeat ' ' "$n")${UI_MUTED}${tag}${UI_RESET}${UI_BAR} ${UI_RESET}"
    else
        n=$(( UI_INNER - ${#title} - 3 ))
        [ "$n" -lt 1 ] && n=1
        ui_line "${UI_BAR} ${UI_BOLD}${title}${UI_RESET}${UI_BAR}$(ui_repeat ' ' "$n") ${UI_RESET}"
    fi
    [ -n "$2" ] && ui_line " ${UI_MUTED}$(ui_fit "$2" $(( UI_INNER - 4 )))${UI_RESET}"
    ui_bottom
}
ui_header() { ui_title "${BRAND:-KATSUTUN} $UI_DOT $1" "$2"; }

ui_section() {  # ui_section LABEL : labelled group inside a card
    local label; label=$(ui_fit "$1" $(( UI_INNER - 8 )))
    ui_line "${UI_ACCENT}${UI_BULLET} ${UI_BOLD}${label}${UI_RESET}"
}
ui_heading() {  # ui_heading LABEL : dim rule with an accent caption
    local label; label=$(ui_fit "$1" $(( UI_INNER - 6 )))
    ui_line "${UI_DIM}$(ui_repeat "$UI_H" 2)${UI_RESET} ${UI_ACCENT}${label}${UI_RESET}"
}

# ---------------------------------------------------------------- content
ui_card_start() { ui_top "$1"; }
ui_card_end() { ui_bottom; }
ui_kv() {  # ui_kv LABEL VALUE
    local label; label=$(ui_fit "$1" 11)
    ui_line "$(ui_pad "${UI_LABEL}$label${UI_RESET}" 11)${UI_DIM}:${UI_RESET} ${UI_TEXT}$2${UI_RESET}"
}
ui_kv_long() {  # ui_kv_long LABEL VALUE : same, but keeps up to 26 cells for the label
    local label; label=$(ui_fit "$1" 26)
    ui_line "${UI_LABEL}$label${UI_RESET} ${UI_DIM}:${UI_RESET} ${UI_TEXT}$2${UI_RESET}"
}
ui_notice() { ui_line "${UI_ACCENT}${UI_DOT}${UI_RESET} $1"; }
ui_hint() { ui_line "${UI_MUTED}  $1${UI_RESET}"; }
ui_ok()   { ui_line "${UI_GOOD}[OK]${UI_RESET} ${UI_TEXT}$*${UI_RESET}"; }
ui_warn() { ui_line "${UI_WARN}[!]${UI_RESET} $(ui_fit "$*" $((UI_INNER - 5)))"; }
ui_err()  { ui_line "${UI_BAD}[ERROR]${UI_RESET} $(ui_fit "$*" $((UI_INNER - 9)))"; }
ui_status_row() {  # ui_status_row LABEL STATE : label + ON/OFF badge
    local state; state=$(ui_badge "$2")
    ui_right "${UI_TEXT}$1${UI_RESET}" "$state"
}
ui_badge() {  # ui_badge STATE : coloured ON/OFF style word
    case "$1" in
        active|running|on|ON|ONLINE|yes|enabled)
            printf '%b' "${UI_GOOD}${UI_ONLINE} ${UI_BOLD}ON${UI_RESET}" ;;
        ''|N/A|n/a|unknown|n/a)
            printf '%b' "${UI_MUTED}${UI_OFFLINE} N/A${UI_RESET}" ;;
        *)  printf '%b' "${UI_BAD}${UI_OFFLINE} ${UI_BOLD}OFF${UI_RESET}" ;;
    esac
}
ui_tag() {  # ui_tag TEXT COLOURNAME : inline pill
    case "$2" in
        good) printf '%b' "${UI_GOOD}${UI_BOLD}$1${UI_RESET}" ;;
        warn) printf '%b' "${UI_WARN}${UI_BOLD}$1${UI_RESET}" ;;
        bad)  printf '%b' "${UI_BAD}${UI_BOLD}$1${UI_RESET}" ;;
        muted) printf '%b' "${UI_MUTED}$1${UI_RESET}" ;;
        *)    printf '%b' "${UI_ACCENT}${UI_BOLD}$1${UI_RESET}" ;;
    esac
}

ui_option() {  # ui_option NUMBER LABEL [NOTE] : returns one option cell
    local note=''
    [ -n "$3" ] && note="  ${UI_MUTED}$3${UI_RESET}"
    printf '%b' "${UI_ACCENT}[${UI_RESET}${UI_LABEL}$(printf '%02d' "$((10#$1))")${UI_RESET}${UI_ACCENT}]${UI_RESET} ${UI_TEXT}$2${UI_RESET}$note"
}
ui_options() {  # ui_options "NN:Label[:note]" ... : two columns when the frame is wide enough
    local items=("$@") i half cell left right
    if [ "$UI_INNER" -ge 52 ]; then
        half=$(( (UI_INNER - 2) / 2 ))
        for ((i = 0; i < ${#items[@]}; i += 2)); do
            [ -z "${items[i]}" ] && continue
            IFS=: read -r n l x <<<"${items[i]}"; left=$(ui_option "$n" "$l" "$x")
            right=''
            if [ -n "${items[i+1]}" ]; then
                IFS=: read -r n l x <<<"${items[i+1]}"; right=$(ui_option "$n" "$l" "$x")
            fi
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

ui_table_row() {  # ui_table_row COL1 COL2 COL3 : three aligned columns (label/value/value)
    local a b c
    a=$(ui_fit "$1" 14); b=$(ui_fit "$2" 16); c=$(ui_fit "$3" $(( UI_INNER - 34 )))
    ui_line "${UI_TEXT}$(ui_pad "$a" 14)${UI_RESET} ${UI_MUTED}$(ui_pad "$b" 16)${UI_RESET} ${UI_GOOD}$c${UI_RESET}"
}

ui_copy() {  # ui_copy LABEL VALUE : full-width value meant to be copied (never clipped)
    printf '%b%s%b\n' "$UI_LABEL" "$1" "$UI_RESET"
    printf '%b%s%b\n\n' "$UI_TEXT" "$2" "$UI_RESET"
}
ui_footer() {
    local right="${BRAND:-KatsuTun Premium} $UI_DOT $(date '+%d %b %Y %H:%M')"
    printf '  %b%s%b\n' "$UI_MUTED" "$(ui_fit "$right" $(( UI_WIDTH - 2 )))" "$UI_RESET"
}
ui_back_hint() {
    printf '  %b[00]%b %bBack%b   %b[x]%b %bExit%b\n' \
        "$UI_LABEL" "$UI_RESET" "$UI_MUTED" "$UI_RESET" \
        "$UI_LABEL" "$UI_RESET" "$UI_MUTED" "$UI_RESET"
}
ui_prompt() { printf '\n%b%s%b %b%s%b ' "$UI_ACCENT" "$UI_ARROW" "$UI_RESET" "$UI_TEXT" "${1:-Select an option:}" "$UI_RESET"; }
ui_pause() { printf '\n%b%s%b %bPress any key to continue%b' "$UI_ACCENT" "$UI_ARROW" "$UI_RESET" "$UI_MUTED" "$UI_RESET"; read -r -n 1 -s; printf '\n'; }
ui_screen() {  # ui_screen TITLE [SUBTITLE] : clear and draw the title bar
    ui_clear; ui_title "$1" "$2"
}
