#!/bin/bash
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf

UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init

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

ui_clear
katsu-dashboard || { echo "Dashboard unavailable. Run: katsu-update apply --force"; exit 1; }
printf '\n'
options=("SSH & OPENVPN" "VMESS" "VLESS" "TROJAN" "SHADOWSOCKS" "DNS MANAGER"
         "APPEARANCE" "BACKUP & RESTORE" "SET DOMAIN" "RENEW CERTIFICATE"
         "SERVER SETTINGS" "SYSTEM INFO" "REST API" "UPDATE MANAGER")
for i in "${!options[@]}"; do
    printf '  [%02d] %s\n' "$((i + 1))" "${options[$i]}"
done
printf '  [00] EXIT PANEL\n'
ui_prompt
read -r opt || exit 0

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
