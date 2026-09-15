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
    ui_screen "SET DOMAIN" "TLS configuration"
    ui_card_start
    ui_notice "Enter the domain or subdomain that points to this VPS."
    ui_notice "Current: ${UI_TEXT}$(cat /etc/xray/domain 2>/dev/null || echo -)${UI_RESET}"
    ui_card_end
    ui_prompt "New domain:"
    read -r new_domain
    if [ -z "$new_domain" ]; then
        ui_card_start; ui_warn "No domain entered. Nothing was changed."; ui_card_end
        ui_pause; exec menu
    fi
    printf 'IP=%s\n' "$new_domain" > /var/lib/yudhynetwork-pro/ipvps.conf
    printf '%s\n' "$new_domain" > /etc/xray/domain
    ui_card_start
    ui_ok "Domain saved. Renew the certificate to activate it."
    ui_card_end
    ui_pause
    exec crtxray
}

svc() { ui_badge "$(systemctl is-active "$1" 2>/dev/null)"; }
eval "$(katsu-update status 2>/dev/null | grep -E '^(STATE|LATEST)=')"

ui_clear
if [ -x /usr/bin/katsu-dashboard ]; then
    KATSU_DASHBOARD_COMPACT=1 katsu-dashboard
else
    ui_title "${BRAND:-KATSUTUN}" "$(cat /etc/xray/domain 2>/dev/null)"
fi

ui_card_start "ACCOUNTS"
ui_options "01:SSH & OpenVPN" "02:VMess" "03:VLESS" "04:Trojan" "05:Shadowsocks" "06:DNS manager"
ui_card_end
ui_card_start "SERVER"
ui_options "07:Appearance" "08:Backup & restore" "09:Set domain" "10:Renew certificate" \
           "11:Server settings" "12:System info" "13:REST API:$(svc autosc-api)" "14:Update manager"
ui_card_end
if [ "${STATE:-uptodate}" = available ]; then
    ui_card_start
    ui_warn "Update ${LATEST} available - type 100 to install"
    ui_card_end
fi
ui_back_hint
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
    100) clear; update; ui_pause; exec menu ;;
    00|0|x|X|q) clear; exit 0 ;;
    *) exec menu ;;
esac
