#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
UI_LIB=/usr/local/lib/katsutun/ui.sh
[ -r "$UI_LIB" ] || { echo "KatsuTun UI library is missing. Run: katsu-update apply --force"; exit 1; }
# shellcheck source=data/katsu-ui.sh
. "$UI_LIB"
ui_init
red="$UI_BAD"; green="$UI_GOOD"; yell="$UI_WARN"; tyblue="$UI_ACCENT"
# Legacy palette names used by the screens below now map onto the shared theme.
NC="$UI_RESET"; RED="$UI_BAD"; GREEN="$UI_GOOD"; YELLOW="$UI_WARN"
COLOR1="$UI_ACCENT"; COLBG1="$UI_BAR"; WH="$UI_TEXT"
###########- END COLOR CODE -##########

ipes=$(curl -sS ipv4.icanhazip.com)
[[ ! -f /usr/bin/jq ]] && {
    red "Mengunduh file jq!"
    wget -q --no-check-certificate "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -O /usr/bin/jq
    chmod +x usr/bin/jq
}

dircreate() {
    [[ ! -d /root/multi ]] && mkdir -p /root/multi && touch /root/multi/voucher && touch /root/multi/claimed && touch /root/multi/reseller && touch /root/multi/public && touch /root/multi/hist && echo "off" >/root/multi/public
    [[ ! -d /etc/.maAsiss ]] && mkdir -p /etc/.maAsiss
}

x="ok"

function botonoff(){
clear
ui_title "BOT PANEL"
dircreate
[[ ! -f /root/multi/bot.conf ]] && {
echo -e "
• Status ${GREEN}Installer${NC} And ${GREEN}Running!${NC}
"
[[ ! -f /root/ResBotAuth ]] && {
echo -ne " API TOKEN : "
read bot_tkn
echo "Toket: $bot_tkn" >/root/ResBotAuth
echo -ne " ID ADMIN  : "
read adm_ids
echo "Admin_ID: $adm_ids" >>/root/ResBotAuth
}
echo -ne " NAMA BOT : "
read bot_user
[[ -z $bot_user ]] && bot_user="Yudhy_Bot"
echo ""
echo -ne " LIMIT     : "
read limit_pnl
[[ -z $limit_pnl ]] && limit_pnl="1"
echo ""
cat <<-EOF >/root/multi/bot.conf
Botname: $bot_user
Limit: $limit_pnl
EOF

fun_bot1() {
clear
[[ ! -e "/etc/.maAsiss/.Shellbtsss" ]] && {
# Only persist the payload when the download actually succeeded, otherwise an
# empty file would permanently short-circuit this check.
wget -qO /tmp/.Shellbtsss "$RAW/data/BotAPI.sh" &&
    [[ -s /tmp/.Shellbtsss ]] && mv /tmp/.Shellbtsss /etc/.maAsiss/.Shellbtsss
rm -f /tmp/.Shellbtsss
}
[[ "$(grep -wc "sam_bot" "/etc/rc.local")" = '0' ]] && {
sed -i '$ i\screen -dmS sam_bot bbt' /etc/rc.local >/dev/null 2>&1
}
}
screen -dmS sam_bot bbt >/dev/null 2>&1
fun_bot1
[[ $(ps x | grep "sam_bot" | grep -v grep | wc -l) != '0' ]] && {
ui_title "BOT PANEL"
echo -e ""
echo -e " [INFO]  Bot successfully activated !"
echo -e ""
ui_divider
echo -e ""
ui_pause
menu-bot
} || {
ui_title "BOT PANEL"
echo -e ""
echo -e " [INFO] Information not valid !"
echo -e ""
ui_divider
echo -e ""
ui_pause
menu-bot
}
} || {
clear
fun_bot2() {
screen -r -S "sam_bot" -X quit >/dev/null 2>&1
[[ $(grep -wc "sam_bot" /etc/rc.local) != '0' ]] && {
sed -i '/sam_bot/d' /etc/rc.local
}
rm -f /root/multi/bot.conf
sleep 1
}
fun_bot2
ui_title "BOT PANEL"
echo -e ""
echo -e " [INFO] Bot Stoped Successfully"
echo -e ""
ui_divider
echo -e ""
ui_pause
menu-bot
}
}
ui_screen "TELEGRAM BOT" "notifications and remote control"
ui_card_start
ui_options "01:Start / stop bot"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; botonoff ;;
02 | 2) clear ; menu2 ;;
03 | 3) clear ; menu3 ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-bot ;;
esac