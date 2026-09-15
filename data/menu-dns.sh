#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
MYIP=$(wget -qO- ipinfo.io/ip);

UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"

APIGIT=$(cat /etc/yudhynetwork/github/api)
EMAILGIT=$(cat /etc/yudhynetwork/github/email)
USERGIT=$(cat /etc/yudhynetwork/github/username)

export RED='\033[0;31m';
export GREEN='\033[0;32m';
export ERROR="[${RED}ERROR${NC}]";
export INFO="[${GREEN}INFO${NC}]";


function setdns(){
clear
ui_title "USERS LOGS"
ui_card_start
read -p "   DNS : " setdnss

if [ -z $setdnss ]; then
ui_blank
ui_line "${ERROR} DNS Cannot Be Empty";
ui_card_end
echo -e ""
ui_pause
menu-dns
else
echo "$setdnss" > /root/dns
ui_line "${INFO} Copy DNS To Resolv.conf";
echo "nameserver $setdnss" > /etc/resolv.conf
sleep 2
ui_line "${INFO} Copy DNS To Resolv.conf.d/head";
echo "nameserver $setdnss" > /etc/resolvconf/resolv.conf.d/head
sleep 2
ui_line "${INFO} DNS Update Successfully";
fi
ui_card_end
echo -e ""
ui_pause
menu-dns
}

function resdns(){
    clear
ui_title "USERS LOGS"
ui_card_start
read -p "    Reset Default DNS [Y/N]: " -e answer
if [[ "$answer" = 'y' ]]; then
dnsfile="/root/dns"
if test -f "$dnsfile"; then
rm /root/dns
fi
ui_blank
ui_line "${INFO} Delete Resolv.conf DNS";
echo "nameserver 8.8.8.8" > /etc/resolv.conf
sleep 2
ui_line "${INFO} Delete Resolv.conf.d/head DNS";
echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
sleep 2
else
ui_blank
ui_line "$INFO Operation Cancelled By User"
fi
ui_card_end
echo -e ""
ui_pause
menu-dns
}

function check-dns(){
    bash <(curl -sSL "$RAW/data/ceknet.sh")
ui_pause
menu
}

ui_screen "DNS MANAGER" "resolver used by this VPS"
ui_card_start
[ -f /root/dns ] && ui_kv "Active DNS" "$(cat /root/dns)"
ui_options "01:Change DNS" "03:Content check" "02:Reset DNS" "04:Reboot"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; setdns ;;
02 | 2) clear ; resdns ;;
03 | 3) clear ; check-dns ;;
04 | 4) clear ; renewipvps ;;
05 | 5) clear ; useripvps ;;
06 | 6) clear ; $ressee ;;
00 | 0) clear ; menu ;;
*) clear ; menu-dns ;;
esac
