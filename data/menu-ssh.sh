#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
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
function addssh(){
clear
domen=`cat /etc/xray/domain`
portsshws=`cat ~/log-install.txt | grep -w "SSH Websocket" | cut -d: -f2 | awk '{print $1}'`
wsssl=`cat /root/log-install.txt | grep -w "SSH SSL Websocket" | cut -d: -f2 | awk '{print $1}'`

ui_title "SSH PANEL MENU"
ui_card_start
IFS= read -r -p "   Username : " Login

if [ -z "$Login" ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu-ssh
return
fi

CEKFILE=/etc/xray/ssh.txt
if [ -f "$CEKFILE" ]; then
file001="OK"
else
touch /etc/xray/ssh.txt
fi

if grep -qw "$Login" /etc/xray/ssh.txt || id "$Login" >/dev/null 2>&1; then
ui_line "[Error] Username \e[31m$Login\e[0m already exist"
ui_card_end
echo ""
ui_pause
menu-ssh
return
fi

IFS= read -r -p "   Password : " Pass
if [ -z "$Pass" ]; then
ui_line "[Error] Password cannot be empty "
ui_card_end
echo ""
ui_pause
menu-ssh
return
fi
IFS= read -r -p "   Expired (hari): " masaaktif
if ! [[ "$masaaktif" =~ ^[1-9][0-9]*$ ]]; then
ui_line "[Error] Expired days must be a positive number "
ui_card_end
echo ""
ui_pause
menu-ssh
return
fi

IP=$(curl -sS ifconfig.me);
ossl=`cat /root/log-install.txt | grep -w "OpenVPN" | cut -f2 -d: | awk '{print $6}'`
opensh=`cat /root/log-install.txt | grep -w "OpenSSH" | cut -f2 -d: | awk '{print $1}'`
db=`cat /root/log-install.txt | grep -w "Dropbear" | cut -f2 -d: | awk '{print $1,$2}'`
ssl="$(cat ~/log-install.txt | grep -w "Stunnel4" | cut -d: -f2)"
sqd="$(cat ~/log-install.txt | grep -w "Squid" | cut -d: -f2)"
ovpn="$(netstat -nlpt | grep -i openvpn | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2)"
ovpn2="$(netstat -nlpu | grep -i openvpn | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2)"

OhpSSH=`cat /root/log-install.txt | grep -w "OHP SSH" | cut -d: -f2 | awk '{print $1}'`
OhpDB=`cat /root/log-install.txt | grep -w "OHP DBear" | cut -d: -f2 | awk '{print $1}'`
OhpOVPN=`cat /root/log-install.txt | grep -w "OHP OpenVPN" | cut -d: -f2 | awk '{print $1}'`
sleep 1
clear
if ! useradd -e "$(date -d "$masaaktif days" +"%Y-%m-%d")" -s /bin/false -M "$Login"; then
echo -e "$RED [Error] Could not create SSH user $Login${NC}"
ui_pause
menu-ssh
return
fi
printf '%s\n' "$Login" >> /etc/xray/ssh.txt
exp="$(chage -l "$Login" | grep "Account expires" | awk -F": " '{print $2}')"
# chpasswd -c hashes locally and bypasses PAM pwquality, so short customer
# passwords always apply (passwd rejected them silently). Undo on failure.
if ! printf '%s:%s\n' "$Login" "$Pass" | chpasswd -c SHA512 2>/tmp/katsu-passwd.err; then
userdel "$Login" >/dev/null 2>&1
sed -i "/^$Login\$/d" /etc/xray/ssh.txt
ui_card_start
ui_err "Could not set password for $Login"
ui_line "$(head -c 200 /tmp/katsu-passwd.err)"
ui_card_end
rm -f /tmp/katsu-passwd.err
ui_pause
menu-ssh
return
fi
rm -f /tmp/katsu-passwd.err
PID=`ps -ef |grep -v grep | grep sshws |awk '{print $2}'`

if [[ ! -z "${PID}" ]]; then
ui_title "SSH PANEL MENU" | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_kv "Username" "$Login"  | tee -a /etc/log-create-user.log
ui_kv "Password" "$Pass" | tee -a /etc/log-create-user.log
ui_kv "Expired On" "$exp"  | tee -a /etc/log-create-user.log
ui_card_end | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_kv "IP" "$IP"  | tee -a /etc/log-create-user.log
ui_kv "Host" "$domen"  | tee -a /etc/log-create-user.log
ui_kv "OpenSSH" "$opensh" | tee -a /etc/log-create-user.log
ui_kv "Dropbear" "$db"  | tee -a /etc/log-create-user.log
ui_kv "SSH-WS" "$portsshws"  | tee -a /etc/log-create-user.log
ui_kv "SSH-SSL-WS" "$wsssl"  | tee -a /etc/log-create-user.log
ui_kv "SSL/TLS" "$ssl"  | tee -a /etc/log-create-user.log
ui_kv "UDPGW" "7100-7300"  | tee -a /etc/log-create-user.log
ui_card_end | tee -a /etc/log-create-user.log
ui_copy "Payload WebSocket" "GET http://bug.com HTTP/1.1[crlf]Host: $domen[crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/log-create-user.log
else
ui_title "SSH PANEL MENU" | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_kv "Username" "$Login"  | tee -a /etc/log-create-user.log
ui_kv "Password" "$Pass" | tee -a /etc/log-create-user.log
ui_kv "Expired On" "$exp"  | tee -a /etc/log-create-user.log
ui_card_end | tee -a /etc/log-create-user.log
ui_card_start | tee -a /etc/log-create-user.log
ui_kv "IP" "$IP"  | tee -a /etc/log-create-user.log
ui_kv "Host" "$domen"  | tee -a /etc/log-create-user.log
ui_kv "OpenSSH" "$opensh" | tee -a /etc/log-create-user.log
ui_kv "Dropbear" "$db"  | tee -a /etc/log-create-user.log
ui_kv "SSH-WS" "$portsshws"  | tee -a /etc/log-create-user.log
ui_kv "SSH-SSL-WS" "$wsssl"  | tee -a /etc/log-create-user.log
ui_kv "SSL/TLS" "$ssl"  | tee -a /etc/log-create-user.log
ui_kv "UDPGW" "7100-7300"  | tee -a /etc/log-create-user.log
ui_card_end | tee -a /etc/log-create-user.log
ui_copy "Payload WebSocket" "GET http://bug.com HTTP/1.1[crlf]Host: $domen[crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/log-create-user.log
fi
echo -e ""
ui_pause
menu-ssh
}
function sshwss(){
    clear
portdb=`cat ~/log-install.txt | grep -w "Dropbear" | cut -d: -f2|sed 's/ //g' | cut -f2 -d","`
portsshws=`cat ~/log-install.txt | grep -w "SSH Websocket" | cut -d: -f2 | awk '{print $1}'`
if [ -f "/etc/systemd/system/sshws.service" ]; then
clear
else
wget -q -O /usr/bin/proxy3.js "$RAW/data/proxy3.js"
cat <<EOF > /etc/systemd/system/sshws.service
[Unit]
Description=WSenabler
Documentation=By yudhyNet

[Service]
Type=simple
ExecStart=/usr/bin/ssh-wsenabler
KillMode=process
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOF

fi

function start() {
        clear
ui_screen "SSH WEBSOCKET" "enable or disable the WS proxy"
ui_card_start
wget -q -O /usr/bin/ssh-wsenabler "$RAW/data/sshws-true.sh" && chmod +x /usr/bin/ssh-wsenabler
systemctl daemon-reload >/dev/null 2>&1
systemctl enable sshws.service >/dev/null 2>&1
systemctl start sshws.service >/dev/null 2>&1
sed -i "/SSH Websocket/c\   - SSH Websocket           : $portsshws [ON]" /root/log-install.txt
ui_line "${WH}[${COLOR1}INFO${WH}]${NC} ${COLOR1}•${NC} ${green}SSH Websocket Started${NC}"
ui_line "${WH}[${COLOR1}INFO${WH}]${NC} ${COLOR1}•${NC} ${WH}Restart is require for Changes"
ui_line "       to take effect"
ui_card_end
echo -e ""
ui_pause
sshwss
}

function stop() {
        clear
ui_screen "SSH WEBSOCKET" "enable or disable the WS proxy"
ui_card_start
systemctl stop sshws.service >/dev/null 2>&1
tmux kill-session -t sshws >/dev/null 2>&1
sed -i "/SSH Websocket/c\   - SSH Websocket           : $portsshws [OFF]" /root/log-install.txt
ui_line "${WH}[${COLOR1}INFO${WH}] ${COLOR1}•${NC} ${red}SSH Websocket Stopped${NC}"
ui_line "${WH}[${COLOR1}INFO${WH}] ${COLOR1}•${NC} ${WH}Restart is require for Changes"
ui_line "       to take effect"
ui_card_end
echo -e ""
ui_pause
sshwss
}

clear
ui_screen "SSH WEBSOCKET" "enable or disable the WS proxy"
ui_card_start
PID=`ps -ef |grep -v grep | grep sshws |awk '{print $2}'`
if [[ ! -z "${PID}" ]]; then
ui_kv "WebSocket" "$(ui_badge active)"
else
ui_kv "WebSocket" "$(ui_badge inactive)"
fi
ui_blank
ui_options "01:Enable SSH WebSocket" "02:Disable SSH WebSocket"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; start ;;
02 | 2) clear ; stop ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-set ;;
esac
}
function cekssh(){

clear
ui_title "SSH ACTIVE USERS"
ui_card_start
echo -e ""

if [ -e "/var/log/auth.log" ]; then
        LOG="/var/log/auth.log";
fi
if [ -e "/var/log/secure" ]; then
        LOG="/var/log/secure";
fi

data=( `ps aux | grep -i dropbear | awk '{print $2}'`);
cat $LOG | grep -i dropbear | grep -i "Password auth succeeded" > /tmp/login-db.txt;
for PID in "${data[@]}"
do
        cat /tmp/login-db.txt | grep "dropbear\[$PID\]" > /tmp/login-db-pid.txt;
        NUM=`cat /tmp/login-db-pid.txt | wc -l`;
        USER=`cat /tmp/login-db-pid.txt | awk '{print $10}'`;
        IP=`cat /tmp/login-db-pid.txt | awk '{print $12}'`;
        if [ $NUM -eq 1 ]; then
                echo "$PID - $USER - $IP";
        fi

done
echo " "
cat $LOG | grep -i sshd | grep -i "Accepted password for" > /tmp/login-db.txt
data=( `ps aux | grep "\[priv\]" | sort -k 72 | awk '{print $2}'`);

for PID in "${data[@]}"
do
        cat /tmp/login-db.txt | grep "sshd\[$PID\]" > /tmp/login-db-pid.txt;
        NUM=`cat /tmp/login-db-pid.txt | wc -l`;
        USER=`cat /tmp/login-db-pid.txt | awk '{print $9}'`;
        IP=`cat /tmp/login-db-pid.txt | awk '{print $11}'`;
        if [ $NUM -eq 1 ]; then
                echo "$PID - $USER - $IP";
        fi


done
if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
        echo " "

        cat /etc/openvpn/server/openvpn-tcp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
        cat /tmp/vpn-login-tcp.txt
fi

if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
        echo " "

        cat /etc/openvpn/server/openvpn-udp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
        cat /tmp/vpn-login-udp.txt
fi


rm -f /tmp/login-db-pid.txt
rm -f /tmp/login-db.txt
rm -f /tmp/vpn-login-tcp.txt
rm -f /tmp/vpn-login-udp.txt
ui_card_end
echo "";
ui_pause
menu-ssh
}

function delssh(){
clear
ui_title "SSH DELETE USERS"
ui_card_start
read -p "   Username : " Pengguna

if [ -z $Pengguna ]; then
echo -e "   [Error] Username cannot be empty "
else
if getent passwd $Pengguna > /dev/null 2>&1; then
userdel $Pengguna > /dev/null 2>&1
sed -i "s/$Pengguna//g" /etc/xray/ssh.txt
echo -e "   ${WH}[${COLOR1}INFO${WH}]${NC} ${WH}User ${COLOR1}$Pengguna ${WH}was removed.${NC}"
else
echo -e "   ${WH}[${COLOR1}INFO${WH}]${NC} ${WH}Failure${COLOR1}: ${WH}User ${COLOR1}$Pengguna ${WH}Not Exist.${NC}"
fi
fi
ui_card_end
echo -e ""
ui_pause
menu-ssh
}

function renewssh(){
clear
ui_card_start
ui_line "${COLBG1}             ${WH}• RENEW SSH ACCOUNT •              $COLOR1 $NC"
ui_card_end
ui_card_start
read -p "   Username : " User

if getent passwd $User > /dev/null 2>&1; then
ok="ok"
else
ui_line "[INFO] Failure: User $User Not Exist."
ui_card_end
echo ""
ui_pause
menu
fi

if [ -z $User ]; then
ui_line "[Error] Username cannot be empty "
ui_card_end
echo ""
ui_pause
menu
fi

egrep "^$User" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
read -p "Day Extend : " Days
if [ -z $Days ]; then
Days="1"
fi
Today=`date +%s`
Days_Detailed=$(( $Days * 86400 ))
Expire_On=$(($Today + $Days_Detailed))
Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')
passwd -u $User
usermod -e  $Expiration $User
clear
ui_title "RENEW SSH ACCOUNT"
ui_card_start
echo -e "   ${WH}Username   ${COLOR1}: ${WH}$User"
echo -e "   ${WH}Days Added ${COLOR1}: ${WH}$Days Days"
echo -e "   ${WH}Expires on ${COLOR1}: ${WH}$Expiration_Display"
ui_card_end
else
clear
ui_title "RENEW SSH ACCOUNT"
ui_card_start
echo -e "   Username Doesnt Exist      "
ui_card_end
fi
echo ""
ui_pause
menu-ssh
}


function memberssh(){
clear
ui_title "RENEW SSH ACCOUNT"
ui_card_start
echo "   USERNAME          EXP DATE          STATUS"
ui_card_end
ui_card_start
while read expired
do
AKUN="$(echo $expired | cut -d: -f1)"
ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
status="$(passwd -S $AKUN | awk '{print $2}' )"
if [[ $ID -ge 1000 ]]; then
if [[ "$status" = "L" ]]; then
printf "%-17s %2s %-17s %2s \n" "   • $AKUN" "$exp     " "LOCKED"
else
printf "%-17s %2s %-17s %2s \n" "   • $AKUN" "$exp     " "UNLOCKED"
fi
fi
done < /etc/passwd
JUMLAH="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
ui_card_end
ui_card_start
echo "   Total: $JUMLAH User"
ui_card_end
echo ""
ui_pause
menu-ssh
}

function trialssh(){
clear
domen=`cat /etc/xray/domain`
portsshws=`cat ~/log-install.txt | grep -w "SSH Websocket" | cut -d: -f2 | awk '{print $1}'`
wsssl=`cat /root/log-install.txt | grep -w "SSH SSL Websocket" | cut -d: -f2 | awk '{print $1}'`
clear
IP=$(curl -sS ifconfig.me);
ossl=`cat /root/log-install.txt | grep -w "OpenVPN" | cut -f2 -d: | awk '{print $6}'`
opensh=`cat /root/log-install.txt | grep -w "OpenSSH" | cut -f2 -d: | awk '{print $1}'`
db=`cat /root/log-install.txt | grep -w "Dropbear" | cut -f2 -d: | awk '{print $1,$2}'`
ssl="$(cat ~/log-install.txt | grep -w "Stunnel4" | cut -d: -f2)"
OhpSSH=`cat /root/log-install.txt | grep -w "OHP SSH" | cut -d: -f2 | awk '{print $1}'`


Login=zenhost-`</dev/urandom tr -dc X-Z0-9 | head -c4`
hari="1"
Pass=1
echo Ping Host &> /dev/null
echo Create Akun: $Login &> /dev/null
sleep 0.5
echo Setting Password: $Pass &> /dev/null
sleep 0.5
clear
useradd -e "$(date -d "$hari days" +"%Y-%m-%d")" -s /bin/false -M "$Login"
exp="$(chage -l $Login | grep "Account expires" | awk -F": " '{print $2}')"
printf '%s:%s\n' "$Login" "$Pass" | chpasswd -c SHA512
PID=`ps -ef |grep -v grep | grep sshws |awk '{print $2}'`

if [[ ! -z "${PID}" ]]; then
ui_title "SSH TRIAL ACCOUNT"
ui_card_start
ui_line "${WH}Username   ${COLOR1}: ${WH}$Login"
ui_line "${WH}Password   ${COLOR1}: ${WH}$Pass"
ui_line "${WH}Expired On ${COLOR1}: ${WH}$exp"
ui_card_end
ui_card_start
ui_line "${WH}IP         ${COLOR1}: ${WH}$IP"
ui_line "${WH}Host       ${COLOR1}: ${WH}$domen"
ui_line "${WH}OpenSSH    ${COLOR1}: ${WH}$opensh"
ui_line "${WH}Dropbear   ${COLOR1}: ${WH}$db"
ui_line "${WH}SSH-WS     ${COLOR1}: ${WH}$portsshws"
ui_line "${WH}SSH-SSL-WS ${COLOR1}: ${WH}$wsssl"
ui_line "${WH}SSL/TLS    ${COLOR1}:${WH}$ssl"
ui_line "${WH}UDPGW      ${COLOR1}: ${WH}7100-7300"
ui_card_end
ui_card_start
echo -e "  ${WH}GET http://bug.com HTTP/1.1[crlf]Host: $domen [crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]Connection: Keep-Alive[crlf][crlf]${NC}"
ui_card_end
else

ui_title "SSH TRIAL ACCOUNT"
ui_card_start
ui_line "${WH}Username   ${COLOR1}: ${WH}$Login"
ui_line "${WH}Password   ${COLOR1}: ${WH}$Pass"
ui_line "${WH}Expired On ${COLOR1}: ${WH}$exp"
ui_card_end
ui_card_start
ui_line "${WH}IP         ${COLOR1}: ${WH}$IP"
ui_line "${WH}Host       ${COLOR1}: ${WH}$domen"
ui_line "${WH}OpenSSH    ${COLOR1}: ${WH}$opensh"
ui_line "${WH}Dropbear   ${COLOR1}: ${WH}$db"
ui_line "${WH}SSH-WS     ${COLOR1}: ${WH}$portsshws"
ui_line "${WH}SSH-SSL-WS ${COLOR1}: ${WH}$wsssl"
ui_line "${WH}SSL/TLS    ${COLOR1}:${WH}$ssl"
ui_line "${WH}UDPGW      ${COLOR1}: ${WH}7100-7300"
ui_card_end
ui_copy "Payload WebSocket" "GET http://bug.com HTTP/1.1[crlf]Host: $domen [crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]Connection: Keep-Alive[crlf][crlf]"
fi
echo ""
ui_pause
menu-ssh
}
ui_screen "SSH & OPENVPN" "accounts, trials, online users"
ui_card_start
ui_options "01:Add account" "05:Delete account" "02:Trial account" "06:Renew account" "03:Online users" "07:Account list" "04:Enable WebSocket" ""
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; addssh ;;
02 | 2) clear ; trialssh ;;
03 | 3) clear ; cekssh ;;
04 | 4) clear ; sshwss ;;
05 | 5) clear ; delssh ;;
06 | 6) clear ; renewssh ;;
07 | 7) clear ; memberssh ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-ssh ;;
esac
