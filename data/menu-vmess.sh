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
function delvmess(){
    clear
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_title "DELETE XRAY USER"
ui_card_start
ui_line "• You Dont have any existing clients!"
ui_card_end
echo ""
ui_pause
menu-vmess
fi
clear
ui_title "DELETE XRAY USER"
ui_card_start
grep -E "^### " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "• ${WH}[${COLOR1}NOTE${WH}] ${WH}Press any key to back on menu${NC}"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-vmess
else
exp=$(grep -wE "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "DELETE XRAY USER"
ui_card_start
ui_line "• Accound Delete Successfully"
ui_blank
ui_line "• Client Name : $user"
ui_line "• Expired On  : $exp"
ui_card_end
echo ""
ui_pause
menu-vmess
fi
}
function renewvmess(){
clear
ui_title "RENEW VMESS USER"
ui_card_start
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/etc/xray/config.json")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
ui_line "• You have no existing clients!"
ui_card_end
echo ""
ui_pause
menu-vmess
fi
clear
ui_title "RENEW VMESS USER"
ui_card_start
grep -E "^### " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq | nl
ui_blank
ui_line "${COLOR1}• ${WH}[${COLOR1}NOTE${WH}] Press any key to back on menu"
ui_card_end
ui_divider
read -rp "   Input Username : " user
if [ -z $user ]; then
menu-vmess
else
read -p "   Expired (days): " masaaktif
if [ -z $masaaktif ]; then
masaaktif="1"
fi
exp=$(grep -E "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))
exp3=$(($exp2 + $masaaktif))
exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
sed -i "/### $user/c\### $user $exp4" /etc/xray/config.json
systemctl restart xray > /dev/null 2>&1
clear
ui_title "RENEW VMESS USER"
ui_card_start
ui_line "[INFO]  $user Account Renewed Successfully"
ui_blank
ui_line "Client Name : $user"
ui_line "Days Added  : $masaaktif Days"
ui_line "Expired On  : $exp4"
ui_card_end
echo ""
ui_pause
menu-vmess
fi
}

function cekvmess(){
clear
echo -n > /tmp/other.txt
data=( `cat /etc/xray/config.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
ui_title "VMESS USER ONLINE"
ui_card_start

for akun in "${data[@]}"
do
if [[ -z "$akun" ]]; then
akun="tidakada"
fi

echo -n > /tmp/ipvmess.txt
data2=( `cat /var/log/xray/access.log | tail -n 500 | cut -d " " -f 4 | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq`);
for ip in "${data2[@]}"
do

jum=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 4 | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
if [[ "$jum" = "$ip" ]]; then
echo "$jum" >> /tmp/ipvmess.txt
else
echo "$ip" >> /tmp/other.txt
fi
jum2=$(cat /tmp/ipvmess.txt)
sed -i "/$jum2/d" /tmp/other.txt > /dev/null 2>&1
done

jum=$(cat /tmp/ipvmess.txt)
if [[ -z "$jum" ]]; then
echo > /dev/null
else
jum2=$(cat /tmp/ipvmess.txt | nl)
echo -e "  ${COLOR1}${NC}user: $akun";
echo -e "$COLOR1${NC}$jum2";
fi
rm -rf /tmp/ipvmess.txt
done

rm -rf /tmp/other.txt
ui_card_end
echo ""
ui_pause
menu-vmess
}

function addvmess(){
clear
source /var/lib/yudhynetwork-pro/ipvps.conf
domain=$(cat /etc/xray/domain)
ui_title "CREATE VMESS USER"
ui_card_start
tls="$(cat ~/log-install.txt | grep -w "Xray Vmess Ws Tls" | cut -d: -f2|sed 's/ //g')"
none="$(cat ~/log-install.txt | grep -w "Xray Vmess Ws None Tls" | cut -d: -f2|sed 's/ //g')"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${CLIENT_EXISTS} == '0' ]]; do

read -rp "   Input Username : " -e user

if [ -z $user ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu
fi
		CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)

		if [[ ${CLIENT_EXISTS} == '1' ]]; then
clear
ui_title "CREATE VMESS USER"
ui_card_start
ui_line "${WH}Please choose another name.${NC}"
ui_card_end
ui_pause
menu
		fi
	done

#uuid=$(cat /proc/sys/kernel/random/uuid)
read -p " Silakan atur kata sandi (dibuat secara acak jika Anda tidak Mengisi Pasword) :" uuid
    [[ -z "$uuid" ]] && uuid=`cat /proc/sys/kernel/random/uuid`

read -p "   Expired (days): " masaaktif
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#vmess$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#vmessgrpc$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
asu=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "sni": "${domain}",
      "tls": "tls"
}
EOF`
ask=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`
grpc=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "grpc",
      "path": "vmess-grpc",
      "type": "none",
      "host": "${domain}",
      "sni": "${domain}",
      "tls": "tls"
}
EOF`
vmess_base641=$( base64 -w 0 <<< $vmess_json1)
vmess_base642=$( base64 -w 0 <<< $vmess_json2)
vmess_base643=$( base64 -w 0 <<< $vmess_json3)
vmess_base644=$( base64 -w 0 <<< $vmess_json4)
vmess_base645=$( base64 -w 0 <<< $vmess_json5)
vmess_base646=$( base64 -w 0 <<< $vmess_json6)
vmess_base647=$( base64 -w 0 <<< $vmess_json7)
vmess_base648=$( base64 -w 0 <<< $vmess_json8)
vmess_base649=$( base64 -w 0 <<< $vmess_json9)
vmess_base650=$( base64 -w 0 <<< $vmess_json10)
vmesslink1="vmess://$(echo $asu | base64 -w 0)"
vmesslink2="vmess://$(echo $ask | base64 -w 0)"
vmesslink3="vmess://$(echo $grpc | base64 -w 0)"

systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1
clear
ui_title "CREATE VMESS USER" | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_line "${WH}Remarks       ${COLOR1}: ${WH}${user}" | tee -a /etc/log-create-user.log
ui_line "${WH}Expired On    ${COLOR1}: ${WH}$exp"  | tee -a /etc/log-create-user.log
ui_line "${WH}Domain        ${COLOR1}: ${WH}${domain}"  | tee -a /etc/log-create-user.log
ui_line "${WH}Port TLS      ${COLOR1}: ${WH}${tls}"  | tee -a /etc/log-create-user.log
ui_line "${WH}Port none TLS ${COLOR1}: ${WH}${none}"  | tee -a /etc/log-create-user.log
ui_line "${WH}Port  GRPC    ${COLOR1}: ${WH}${tls}"  | tee -a /etc/log-create-user.log
ui_line "${WH}id            ${COLOR1}: ${WH}${uuid}"  | tee -a /etc/log-create-user.log
ui_line "${WH}alterId       ${COLOR1}: ${WH}0"  | tee -a /etc/log-create-user.log
ui_line "${WH}Security      ${COLOR1}: ${WH}auto"  | tee -a /etc/log-create-user.log
ui_line "${WH}Network       ${COLOR1}: ${WH}ws"  | tee -a /etc/log-create-user.log
ui_line "${WH}Path          ${COLOR1}: ${WH}/vmess-(custom path) " | tee -a /etc/log-create-user.log
ui_line "${WH}ServiceName   ${COLOR1}: ${WH}vmess-grpc"  | tee -a /etc/log-create-user.log
ui_card_end  | tee -a /etc/log-create-user.log
ui_copy "Link WebSocket TLS" "$vmesslink1" | tee -a /etc/log-create-user.log
ui_copy "Link WebSocket non-TLS" "$vmesslink2" | tee -a /etc/log-create-user.log
ui_copy "Link gRPC" "$vmesslink3" | tee -a /etc/log-create-user.log
echo "" | tee -a /etc/log-create-user.log

ui_pause
menu-vmess
}


ui_screen "VMESS" "Xray accounts"
ui_card_start
ui_options "01:Add account" "03:Delete account" "02:Renew account" "04:Online users"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; addvmess ;;
02 | 2) clear ; renewvmess ;;
03 | 3) clear ; delvmess ;;
04 | 4) clear ; cekvmess ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-vmess ;;
esac


