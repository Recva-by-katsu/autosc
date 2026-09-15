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
 WH='\033[1;37m'
###########- KatsuTun -##########

function cekvless(){
clear
echo -n > /tmp/other.txt
data=( `cat /etc/xray/config.json | grep '#&' | cut -d ' ' -f 2 | sort | uniq`);
ui_title "RENEW VLESS USER"
ui_card_start

for akun in "${data[@]}"
do
if [[ -z "$akun" ]]; then
akun="tidakada"
fi

echo -n > /tmp/ipvless.txt
data2=( `cat /var/log/xray/access.log | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq`);
for ip in "${data2[@]}"
do

jum=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
if [[ "$jum" = "$ip" ]]; then
echo "$jum" >> /tmp/ipvless.txt
else
echo "$ip" >> /tmp/other.txt
fi
jum2=$(cat /tmp/ipvless.txt)
sed -i "/$jum2/d" /tmp/other.txt > /dev/null 2>&1
done

jum=$(cat /tmp/ipvless.txt)
if [[ -z "$jum" ]]; then
echo > /dev/null
else
jum2=$(cat /tmp/ipvless.txt | nl)
ui_line "user : $akun";
echo -e "$COLOR1${NC}$jum2";
fi
rm -rf /tmp/ipvless.txt
done

rm -rf /tmp/other.txt
ui_card_end
echo ""
ui_pause
menu-vless
}

function renewvless(){
clear
ui_title "RENEW VLESS USER"
ui_card_start
NUMBER_OF_CLIENTS=$(grep -c -E "^#& " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_line "• You have no existing clients!"
ui_card_end
echo ""
ui_pause
menu-vless
fi
clear
ui_title "RENEW VLESS USER"
ui_card_start
grep -E "^#& " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-vless
else
read -p "   Expired (days): " masaaktif
if [ -z $masaaktif ]; then
masaaktif="1"
fi
exp=$(grep -E "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
sed -i "/#& $user/c\#& $user $exp4" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "RENEW VLESS USER"
ui_card_start
ui_line "[INFO]  $user Account Renewed Successfully"
ui_blank
ui_line "Client Name : $user"
ui_line "Days Added  : $masaaktif Days"
ui_line "Expired On  : $exp4"
ui_card_end
echo ""
ui_pause
menu-vless
fi
}

function delvless(){
    clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#& " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_title "DELETE VLESS USER"
ui_card_start
ui_line "• You Dont have any existing clients!"
ui_card_end
echo ""
ui_pause
menu-vless
fi
clear
ui_title "DELETE VLESS USER"
ui_card_start
grep -E "^#& " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-vless
else
exp=$(grep -wE "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "DELETE VLESS USE"
ui_card_start
ui_line "• Accound Delete Successfully"
ui_blank
ui_line "• Client Name : $user"
ui_line "• Expired On  : $exp"
ui_card_end
echo ""
ui_pause
menu-vless
fi
}

function addvless(){
domain=$(cat /etc/xray/domain)
ui_title "CREATE VLESS USER"
ui_card_start
tls="$(cat ~/log-install.txt | grep -w "Xray Vless Ws Tls" | cut -d: -f2|sed 's/ //g')"
none="$(cat ~/log-install.txt | grep -w "Xray Vless Ws None Tls" | cut -d: -f2|sed 's/ //g')"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do
		read -rp "  Input Username : " -e user
        if [ -z $user ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu
fi
		CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
ui_line "Please choose another name."
ui_card_end
echo ""
ui_pause
menu
fi
done

#uuid=$(cat /proc/sys/kernel/random/uuid)
read -p " Silakan atur kata sandi (dibuat secara acak jika Anda tidak Mengisi Pasword) :" uuid
    [[ -z "$uuid" ]] && uuid=`cat /proc/sys/kernel/random/uuid`

read -p "  Expired (days): " masaaktif
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#vless$/a\#& '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vlessgrpc$/a\#& '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
vlesslink1="vless://${uuid}@${domain}:$tls?path=/vlessws&security=tls&encryption=none&type=ws&host=${domain}&sni=${domain}#${user}"
vlesslink2="vless://${uuid}@${domain}:$none?path=/vlessws&encryption=none&type=ws&host=${domain}#${user}"
vlesslink3="vless://${uuid}@${domain}:$tls?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"
systemctl restart xray
clear
ui_title "CREATE VLESS USER" | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_line "${WH}Remarks       ${COLOR1}: ${WH}${user}"  | tee -a /etc/log-create-user.log
ui_line "${WH}Expired On    ${COLOR1}: ${WH}$exp"  | tee -a /etc/log-create-user.log
ui_line "${WH}Domain        ${COLOR1}: ${WH}${domain}"  | tee -a /etc/log-create-user.log
ui_line "${WH}port TLS      ${COLOR1}: ${WH}$tls"  | tee -a /etc/log-create-user.log
ui_line "${WH}port none TLS ${COLOR1}: ${WH}$none"  | tee -a /etc/log-create-user.log
ui_line "${WH}id            ${COLOR1}: ${WH}${uuid}" | tee -a /etc/log-create-user.log
ui_line "${WH}Encryption    ${COLOR1}: ${WH}none"  | tee -a /etc/log-create-user.log
ui_line "${WH}Network       ${COLOR1}: ${WH}ws"  | tee -a /etc/log-create-user.log
ui_line "${WH}Path          ${COLOR1}: ${WH}/vlessws (Custom Path) " | tee -a /etc/log-create-user.log
ui_line "${WH}Path          ${COLOR1}: ${WH}vless-grpc"  | tee -a /etc/log-create-user.log
ui_card_end  | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_line "${COLOR1}Link Websocket TLS      ${WH}:${NC}" | tee -a /etc/log-create-user.log
ui_line "${WH}${vlesslink1}${NC}"  | tee -a /etc/log-create-user.log
ui_divider | tee -a /etc/log-create-user.log
ui_line "${COLOR1}Link Websocket None TLS ${WH}: ${NC}" | tee -a /etc/log-create-user.log
ui_line "${WH}${vlesslink2}${NC}"  | tee -a /etc/log-create-user.log
ui_divider | tee -a /etc/log-create-user.log
ui_line "${COLOR1}Link Websocket GRPC     ${WH}: ${NC}" | tee -a /etc/log-create-user.log
ui_line "${WH}${vlesslink3}${NC}"  | tee -a /etc/log-create-user.log
ui_divider | tee -a /etc/log-create-user.log
ui_card_end | tee -a /etc/log-create-user.log
echo ""  | tee -a /etc/log-create-user.log
ui_pause
menu-vless
}


ui_screen "VLESS" "Xray accounts"
ui_card_start
ui_options "01:Add account" "03:Delete account" "02:Renew account" "04:Online users"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; addvless ;;
02 | 2) clear ; renewvless ;;
03 | 3) clear ; delvless ;;
04 | 4) clear ; cekvless ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-vless ;;
esac


