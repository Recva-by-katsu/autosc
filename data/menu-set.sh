#!/bin/bash
#dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
#biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- Yudhy Network -##########
function status(){
clear
cek=$(service ssh status | grep active | cut -d ' ' -f5)
if [ "$cek" = "active" ]; then
stat=-f5
else
stat=-f7
fi
cekray=`cat /root/log-install.txt | grep -ow "XRAY" | sort | uniq`
if [ "$cekray" = "XRAY" ]; then
rekk='xray'
becek='XRAY'
else
rekk='v2ray'
becek='V2RAY'
fi

ssh=$(service ssh status | grep active | cut -d ' ' $stat)
if [ "$ssh" = "active" ]; then
ressh="${WH}ONLINE${NC}"
else
ressh="${red}OFFLINE${NC}"
fi
sshstunel=$(service stunnel4 status | grep active | cut -d ' ' $stat)
if [ "$sshstunel" = "active" ]; then
resst="${WH}ONLINE${NC}"
else
resst="${red}OFFLINE${NC}"
fi
sshws=$(service ws-dropbear status | grep active | cut -d ' ' $stat)
if [ "$sshws" = "active" ]; then
rews="${WH}ONLINE${NC}"
else
rews="${red}OFFLINE${NC}"
fi

sshws2=$(service ws-stunnel status | grep active | cut -d ' ' $stat)
if [ "$sshws2" = "active" ]; then
rews2="${WH}ONLINE${NC}"
else
rews2="${red}OFFLINE${NC}"
fi

db=$(service dropbear status | grep active | cut -d ' ' $stat)
if [ "$db" = "active" ]; then
resdb="${WH}ONLINE${NC}"
else
resdb="${red}OFFLINE${NC}"
fi

v2r=$(service $rekk status | grep active | cut -d ' ' $stat)
if [ "$v2r" = "active" ]; then
resv2r="${WH}ONLINE${NC}"
else
resv2r="${red}OFFLINE${NC}"
fi
vles=$(service $rekk status | grep active | cut -d ' ' $stat)
if [ "$vles" = "active" ]; then
resvles="${WH}ONLINE${NC}"
else
resvles="${red}OFFLINE${NC}"
fi
trj=$(service $rekk status | grep active | cut -d ' ' $stat)
if [ "$trj" = "active" ]; then
restr="${WH}ONLINE${NC}"
else
restr="${red}OFFLINE${NC}"
fi

tcp="$(systemctl show --now openvpn-server@server-tcp-1194 --no-page)"
status1=$(echo "${tcp}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status1}" = "active" ]; then
ovpntcp="${WH}ONLINE${NC}"
else
ovpntcp="${red}OFFLINE${NC}"
fi

udp="$(systemctl show --now openvpn-server@server-udp-2200 --no-page)"
status2=$(echo "${udp}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status2}" = "active" ]; then
ovpnudp="${WH}ONLINE${NC}"
else
ovpnudp="${red}OFFLINE${NC}"
fi

ovhp="$(systemctl show ohp.service --no-page)"
status3=$(echo "${ovhp}" | grep 'ActiveState=' | cut -f2 -d=)
if [ "${status3}" = "active" ]; then
ohp="${WH}ONLINE${NC}"
else
ohp="${red}OFFLINE${NC}"
fi

ningx=$(service nginx status | grep active | cut -d ' ' $stat)
if [ "$ningx" = "active" ]; then
resnx="${WH}ONLINE${NC}"
else
resnx="${red}OFFLINE${NC}"
fi

squid=$(service squid status | grep active | cut -d ' ' $stat)
if [ "$squid" = "active" ]; then
ressq="${WH}ONLINE${NC}"
else
ressq="${red}OFFLINE${NC}"
fi
ui_title "SERVER STATUS"
ui_card_start
ui_kv "SSH & VPN" "$ressh"
ui_kv "OVPN TCP" "$ovpntcp"
ui_kv "OVPN UDP" "$ovpnudp"
ui_kv "OVPN OHP" "$ohp"
ui_kv "SQUID" "$ressq"
ui_kv "DROPBEAR" "$resdb"
ui_kv "NGINX" "$resnx"
ui_kv "WS DROPBEAR" "$rews"
ui_kv "WS STUNNEL" "$rews2"
ui_kv "STUNNEL" "$resst"
ui_kv "XRAY-SS" "$resv2r"
ui_kv "XRAY" "$resv2r"
ui_kv "VLESS" "$resvles"
ui_kv "TROJAN" "$restr"
ui_card_end
echo ""
ui_pause
menu-set
}
function restart(){
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
menu-set
}

[[ -f /etc/ontorrent ]] && sts_plain="ON" || sts_plain="OFF"

enabletorrent() {
[[ ! -f /etc/ontorrent ]] && {
sudo iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
sudo iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
sudo iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
sudo iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
sudo iptables-save > /etc/iptables.up.rules
sudo iptables-restore -t < /etc/iptables.up.rules
sudo netfilter-persistent save >/dev/null 2>&1
sudo netfilter-persistent reload >/dev/null 2>&1
touch /etc/ontorrent
menu-set
} || {
sudo iptables -D FORWARD -m string --string "get_peers" --algo bm -j DROP
sudo iptables -D FORWARD -m string --string "announce_peer" --algo bm -j DROP
sudo iptables -D FORWARD -m string --string "find_node" --algo bm -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "BitTorrent" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "peer_id=" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string ".torrent" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "torrent" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "announce" -j DROP
sudo iptables -D FORWARD -m string --algo bm --string "info_hash" -j DROP
sudo iptables-save > /etc/iptables.up.rules
sudo iptables-restore -t < /etc/iptables.up.rules
sudo netfilter-persistent save >/dev/null 2>&1
sudo netfilter-persistent reload >/dev/null 2>&1
rm -f /etc/ontorrent
menu-set
}
}

ui_screen "SERVER SETTINGS" "status, tweaks and tools"
ui_card_start
ui_options "01:Running services" "06:Restart all" "02:Set banner" "07:Auto reboot" "03:Bandwidth usage" "08:Speedtest" "04:Anti torrent:$sts_plain" "09:HideSSH" "05:TCP tweak" "10:Region checker"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; status ;;
02 | 2) clear ; nano /etc/issue.net ; menu-set ;;
03 | 3) clear ; mbandwith ;;
04 | 4) clear ; enabletorrent ;;
05 | 5) clear ; menu-tcp ;;
06 | 6) clear ; restart ;;
07 | 7) clear ; autoboot ;;
08 | 8) clear ; mspeed ;;
09 | 9) clear ; hidessh ;;
10) clear ; regionchecker ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-set ;;
esac
