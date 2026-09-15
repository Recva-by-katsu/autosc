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
###########- KatsuTun -##########

function cektrojan(){
clear
echo -n > /tmp/other.txt
data=( `cat /etc/xray/config.json | grep '^#!' | cut -d ' ' -f 2 | sort | uniq`);
ui_title "TROJAN ONLINE NOW"
ui_card_start

for akun in "${data[@]}"
do
if [[ -z "$akun" ]]; then
akun="tidakada"
fi

echo -n > /tmp/iptrojan.txt
data2=( `cat /var/log/xray/access.log | tail -n 500 | cut -d " " -f 4 | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq`);
for ip in "${data2[@]}"
do

jum=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 4 | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
if [[ "$jum" = "$ip" ]]; then
echo "$jum" >> /tmp/iptrojan.txt
else
echo "$ip" >> /tmp/other.txt
fi
jum2=$(cat /tmp/iptrojan.txt)
sed -i "/$jum2/d" /tmp/other.txt > /dev/null 2>&1
done

jum=$(cat /tmp/iptrojan.txt)
if [[ -z "$jum" ]]; then
echo > /dev/null
else
jum2=$(cat /tmp/iptrojan.txt | nl)
echo -e "$COLOR1  ${NC}user: $akun";
echo -e "${COLOR1}${NC}$jum2";
fi
rm -rf /tmp/iptrojan.txt
done

rm -rf /tmp/other.txt
ui_card_end
echo ""
ui_pause
menu-trojan
}


function deltrojan(){
    clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#! " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_title "DELETE TROJAN USER"
ui_card_start
ui_line "• You Dont have any existing clients!"
ui_card_end
echo ""
ui_pause
menu-trojan
fi
clear
ui_title "DELETE TROJAN USER"
ui_card_start
grep -E "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-trojan
else
exp=$(grep -wE "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "DELETE TROJAN USER"
ui_card_start
ui_line "• Accound Delete Successfully"
ui_blank
ui_line "• Client Name : $user"
ui_line "• Expired On  : $exp"
ui_card_end
echo ""
ui_pause
menu-trojan
fi
}

function renewtrojan(){
clear
ui_title "RENEW TROJAN USER"
ui_card_start
NUMBER_OF_CLIENTS=$(grep -c -E "^#! " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_line "• You have no existing clients!"
ui_card_end
echo ""
ui_pause
menu-trojan
fi
clear
ui_title "RENEW TROJAN USER"
ui_card_start
grep -E "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-trojan
else
read -p "   Expired (days): " masaaktif
if [ -z $masaaktif ]; then
masaaktif="1"
fi
exp=$(grep -E "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
sed -i "/#! $user/c\#! $user $exp4" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "RENEW TROJAN USER"
ui_card_start
ui_line "[INFO]  $user Account Renewed Successfully"
ui_blank
ui_line "Client Name : $user"
ui_line "Days Added  : $masaaktif Days"
ui_line "Expired On  : $exp4"
ui_card_end
echo ""
ui_pause
menu-trojan
fi
}

function addtrojan(){
source /var/lib/yudhynetwork-pro/ipvps.conf
domain=$(cat /etc/xray/domain)
ui_title "CREATE TROJAN USER"
ui_card_start
tr="$(cat ~/log-install.txt | grep -w "Websocket Trojan" | cut -d: -f2|sed 's/ //g')"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
read -rp "   Input Username : " -e user
if [ -z $user ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu
fi
user_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)
if [[ ${user_EXISTS} == '1' ]]; then
clear
ui_title "CREATE TROJAN USER"
ui_card_start
ui_line "Please choose another name."
ui_card_end
ui_pause
trojan-menu
fi
done
#uuid=$(cat /proc/sys/kernel/random/uuid)
read -p " Silakan atur kata sandi (dibuat secara acak jika Anda tidak Mengisi Pasword) :" uuid
    [[ -z "$uuid" ]] && uuid=`cat /proc/sys/kernel/random/uuid`

read -p "   Expired (days): " masaaktif
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#trojanws$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#trojangrpc$/a\#! '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
systemctl restart xray
trojanlink1="trojan://${uuid}@${domain}:${tr}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"
trojanlink="trojan://${uuid}@${domain}:${tr}?path=%2Ftrojan&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
clear
ui_title "CREATE TROJAN USER"
ui_card_start
ui_line "${WH}Remarks     ${COLOR1}: ${WH}${user}"
ui_line "${WH}Expired On  ${COLOR1}: ${WH}$exp"
ui_line "${WH}Host/IP     ${COLOR1}: ${WH}${domain}"
ui_line "${WH}Port        ${COLOR1}: ${WH}${tr}"
ui_line "${WH}Key         ${COLOR1}: ${WH}${uuid}"
ui_line "${WH}Path        ${COLOR1}: ${WH}/trojan (/Custom path)"
ui_line "${WH}Path WSS    ${COLOR1}: ${WH}wss://${domain}/trojan (/Custom path)"
ui_line "${WH}ServiceName ${COLOR1}: ${WH}trojan-grpc"
ui_card_end
ui_copy "Link WebSocket TLS" "$trojanlink"
ui_copy "Link gRPC" "$trojanlink1"
echo ""
ui_pause
menu-trojan
}


ui_screen "TROJAN" "Xray accounts"
ui_card_start
ui_options "01:Add account" "03:Delete account" "02:Renew account" "04:Online users"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; addtrojan ;;
02 | 2) clear ; renewtrojan ;;
03 | 3) clear ; deltrojan ;;
04 | 4) clear ; cektrojan ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-trojan ;;
esac


