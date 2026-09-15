#!/bin/bash
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- KatsuTun -##########
clear
ui_title "SERVER STATUS"
ui_card_start
systemctl daemon-reload
ui_notice "Starting ..."
sleep 1
systemctl restart ssh
ui_notice "Restarting SSH Services"
sleep 1
systemctl restart squid
ui_notice "Restarting Squid Services"
sleep 1
systemctl restart openvpn
systemctl restart --now openvpn-server@server-tcp-1194
systemctl restart --now openvpn-server@server-udp-2200
ui_notice "Restarting OpenVPN Services"
sleep 1
systemctl restart nginx
ui_notice "Restarting Nginx Services"
sleep 1
systemctl restart dropbear
ui_notice "Restarting Dropbear Services"
sleep 1
systemctl restart ws-dropbear
ui_notice "Restarting Ws-Dropbear Services"
sleep 1
systemctl restart ws-stunnel
ui_notice "Restarting Ws-Stunnel Services"
sleep 1
systemctl restart stunnel4
ui_notice "Restarting Stunnel4 Services"
sleep 1
systemctl restart xray
ui_notice "Restarting Xray Services"
sleep 1
systemctl restart cron
ui_notice "Restarting Cron Services"
ui_notice "All Services Restates Successfully"
sleep 1
ui_card_end
echo ""
ui_pause
menu
