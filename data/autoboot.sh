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
###########- END COLOR CODE -##########

MYIP=$(wget -qO- ipinfo.io/ip);

function menu1(){
    clear
ui_screen "AUTO REBOOT" "scheduled restart"
ui_card_start
FILE=/etc/cron.d/re_otm
if [ -f "$FILE" ]; then
rm -f /etc/cron.d/re_otm
else
re="ok"
fi
rm -f /etc/cron.d/auto_reboot
echo "*/30 * * * * root /usr/bin/rebootvps" > /etc/cron.d/auto_reboot && chmod +x /etc/cron.d/auto_reboot
ui_line "[INFO] Auto Reboot Active Successfully"
ui_line "[INFO] Auto Reboot : Every 30 Min"
ui_line "[INFO] Active & Running Automaticly"
ui_card_end
echo ""
ui_pause
autoboot
}
function menu2(){
        clear
ui_screen "AUTO REBOOT" "scheduled restart"
ui_card_start
FILE=/etc/cron.d/re_otm
if [ -f "$FILE" ]; then
rm -f /etc/cron.d/re_otm
else
re="ok"
fi
rm -f /etc/cron.d/auto_reboot
echo "0 * * * * root /usr/bin/rebootvps" > /etc/cron.d/auto_reboot && chmod +x /etc/cron.d/auto_reboot
ui_line "[INFO] Auto Reboot Active Successfully"
ui_line "[INFO] Auto Reboot : Every 1 Hours"
ui_line "[INFO] Active & Running Automaticly"
ui_card_end
echo ""
ui_pause
autoboot
}
function menu3(){
        clear
ui_screen "AUTO REBOOT" "scheduled restart"
ui_card_start
FILE=/etc/cron.d/re_otm
if [ -f "$FILE" ]; then
rm -f /etc/cron.d/re_otm
else
re="ok"
fi
rm -f /etc/cron.d/auto_reboot
echo "0 */12 * * * root /usr/bin/rebootvps" > /etc/cron.d/auto_reboot && chmod +x /etc/cron.d/auto_reboot
ui_line "[INFO] Auto Reboot Active Successfully"
ui_line "[INFO] Auto Reboot : Every 12 Hours"
ui_line "[INFO] Active & Running Automaticly"
ui_card_end
echo ""
ui_pause
autoboot
}
function menu4(){
        clear
ui_screen "AUTO REBOOT" "scheduled restart"
ui_card_start
FILE=/etc/cron.d/re_otm
if [ -f "$FILE" ]; then
rm -f /etc/cron.d/re_otm
else
re="ok"
fi
rm -f /etc/cron.d/auto_reboot
echo "0 5 * * * root /usr/bin/rebootvps" > /etc/cron.d/auto_reboot && chmod +x /etc/cron.d/auto_reboot
ui_line "[INFO] Auto Reboot Active Successfully"
ui_line "[INFO] Auto Reboot : Every 24 Hours"
ui_line "[INFO] Active & Running Automaticly"
ui_card_end
echo ""
ui_pause
autoboot
}
clear
ui_screen "AUTO REBOOT" "scheduled restart"
ui_card_start
ui_options "01:Every 30 minutes" "03:Every 12 hours" "02:Every 60 minutes" "04:Every 24 hours" "05:Restart now"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; menu1 ;;
02 | 2) clear ; menu2 ;;
03 | 3) clear ; menu3 ;;
04 | 4) clear ; menu4 ;;
05 | 5) clear ; restart ;;
00 | 0) clear ; menu-set ;;
*) clear ; autoboot ;;
esac
