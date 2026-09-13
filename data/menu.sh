#!/bin/bash
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf

UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init

service_status() {
    if systemctl is-active --quiet "$1" 2>/dev/null; then
        printf '%bONLINE%b' "$UI_GOOD" "$UI_RESET"
    else
        printf '%bOFFLINE%b' "$UI_BAD" "$UI_RESET"
    fi
}
read_value() { cat "$1" 2>/dev/null || printf '%s' "$2"; }

set_domain() {
    ui_clear
    ui_header "SET DOMAIN" "TLS CONFIGURATION"
    ui_card_start
    ui_notice "Enter the domain or subdomain used by this VPS."
    ui_card_end
    printf '\n%b›%b New domain: ' "$UI_ACCENT" "$UI_RESET"
    read -r new_domain
    if [ -z "$new_domain" ]; then
        ui_notice "${UI_WARN}No domain entered. Nothing was changed.${UI_RESET}"
        printf 'Press any key to return…'; read -r -n 1 -s
        exec menu
    fi
    printf 'IP=%s\n' "$new_domain" > /var/lib/yudhynetwork-pro/ipvps.conf
    printf '%s\n' "$new_domain" > /etc/xray/domain
    ui_card_start
    ui_notice "${UI_GOOD}✓${UI_RESET} Domain saved. Renew the certificate to activate it."
    ui_card_end
    printf 'Press any key to renew the certificate…'; read -r -n 1 -s
    exec crtxray
}

ssh_status=$(service_status ws-stunnel)
xray_status=$(service_status xray)
nginx_status=$(service_status nginx)
api_status=$(service_status autosc-api)
memory_total=$(free -m 2>/dev/null | awk 'NR==2 {print $2}')
memory_used=$(free -m 2>/dev/null | awk 'NR==2 {print $3}')
memory_free=$(( ${memory_total:-0} - ${memory_used:-0} ))
uptime_value=$(uptime -p 2>/dev/null | sed 's/^up //')
domain=$(read_value /etc/xray/domain 'not configured')
public_ip=$(read_value /etc/lukman/ip 'unavailable')
version=$(read_value /opt/.ver 'unknown')
eval "$(katsu-update status 2>/dev/null | grep -E '^(STATE|AUTO_UPDATE|LATEST)=')"
if [ "${AUTO_UPDATE:-on}" = on ]; then update_status="${UI_GOOD}AUTO${UI_RESET}"; else update_status="${UI_WARN}MANUAL${UI_RESET}"; fi

ui_clear
ui_header "VPS DASHBOARD" "SECURE SERVER AUTOMATION"
ui_card_start
ui_kv "DOMAIN" "$domain"
ui_kv "PUBLIC IP" "$public_ip"
ui_kv "UPTIME" "${uptime_value:-unavailable}"
ui_kv "MEMORY" "${memory_used:-?} MB used • ${memory_free} MB available"
ui_card_end
ui_card_start
ui_kv "SSH WEBSOCKET" "$ssh_status       XRAY  $xray_status"
ui_kv "NGINX" "$nginx_status       API   $api_status"
ui_card_end
ui_card_start
ui_menu_pair 1 "SSH & OPENVPN" "$ssh_status" 7 "APPEARANCE" "THEMES"
ui_menu_pair 2 "VMESS" "$xray_status" 8 "BACKUP & RESTORE" "TOOLS"
ui_menu_pair 3 "VLESS" "$xray_status" 9 "SET DOMAIN" "TLS"
ui_menu_pair 4 "TROJAN" "$xray_status" 10 "RENEW CERTIFICATE" "TLS"
ui_menu_pair 5 "SHADOWSOCKS" "$xray_status" 11 "SERVER SETTINGS" "TOOLS"
ui_menu_pair 6 "DNS MANAGER" "TOOLS" 12 "SYSTEM INFO" "VIEW"
ui_menu_pair 13 "REST API" "$api_status" 14 "UPDATE MANAGER" "$update_status"
ui_blank
ui_menu_item 0 "EXIT PANEL" "LOGOUT"
ui_card_end
if [ "${STATE:-uptodate}" = available ]; then
    ui_card_start
    ui_notice "${UI_WARN}●${UI_RESET} Update available: ${LATEST:-new version}. Select ${UI_TEXT}14${UI_RESET} to review it."
    ui_card_end
fi
ui_card_start
ui_kv "VERSION" "$version • Source: ${REPO_URL:-unknown}"
ui_card_end
ui_footer
ui_prompt
read -r opt

case $opt in
    01|1) clear; exec menu-ssh ;;
    02|2) clear; exec menu-vmess ;;
    03|3) clear; exec menu-vless ;;
    04|4) clear; exec menu-trojan ;;
    05|5) clear; exec menu-ss ;;
    06|6) clear; exec menu-dns ;;
    07|7) clear; exec menu-theme ;;
    08|8) clear; exec menu-backup ;;
    09|9) set_domain ;;
    10) clear; crtxray ;;
    11) clear; exec menu-set ;;
    12) clear; exec info ;;
    13) clear; exec menu-api ;;
    14) clear; exec menu-update ;;
    100) clear; update; read -r -n 1 -s; exec menu ;;
    00|0|x|X) clear; exit 0 ;;
    *) clear; exec menu ;;
esac
