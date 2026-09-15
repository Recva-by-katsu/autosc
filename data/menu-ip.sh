#!/bin/bash
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


function setapi(){
    clear
ui_title "IPVPS GITHUB API"
ui_card_start

if [[ -f /etc/yudhynetwork/github/api && -f /etc/yudhynetwork/github/email && /etc/yudhynetwork/github/username ]]; then
   rec="OK"
else
    mkdir /etc/yudhynetwork/github > /dev/null 2>&1
fi

read -p " E-mail   : " EMAIL1
if [ -z $EMAIL1 ]; then
ui_line "[INFO] Please Input Your Github Email Adress"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi

read -p " Username : " USERNAME1
if [ -z $USERNAME1 ]; then
ui_line "[INFO] Please Input Your Github Username"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi

read -p " API      : " API1
if [ -z $API1 ]; then
ui_line "[INFO] Please Input Your Github API"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi

sleep 2
echo "$EMAIL1" > /etc/yudhynetwork/github/email
echo "$USERNAME1" > /etc/yudhynetwork/github/username
echo "$API1" > /etc/yudhynetwork/github/api
echo "ON" > /etc/yudhynetwork/github/gitstat
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "[INFO] Github Api Setup Successfully"
ui_blank
ui_line "• Email : $EMAIL1"
ui_line "• User  : $USERNAME1"
ui_line "• API   : $API1"
ui_card_end
echo -e ""
ui_pause
menu-ip
}

function viewapi(){
    clear
ui_title "LIST REGISTER IP"
ui_card_start
ui_line "• Email : $EMAILGIT"
ui_line "• User  : $USERGIT"
ui_line "• API   : $APIGIT"
ui_line "• All U need Is Create a new repository "
ui_line "& Nammed : permission "
ui_card_end
echo -e ""
ui_pause
menu-ip
}

function add_ip(){
clear
ui_title "REGISTER IPVPS"
ui_card_start
rm -rf /root/permission
read -p "   NEW IPVPS : " daftar
ui_blank
ui_line "[INFO] Checking the IPVPS!"
sleep 1
REQIP=$(curl -sS https://raw.githubusercontent.com/${USERGIT}/permission/main/ipmini | awk '{print $4}' | grep $daftar)
if [[ $daftar = $REQIP ]]; then
ui_line "[INFO] VPS IP Already Registered!!"
ui_card_end
echo -e ""
ui_pause
menu-ip
else
ui_line "[INFO] OK! IP VPS is not Registered!"
ui_line "[INFO] Lets Regester it!"
sleep 3
clear
fi
ui_title "REGISTER IPVPS"
ui_card_start
read -p "   User Name  : " client
if [ -z $client ]; then
cd
ui_line "[INFO] Please Input client"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi


read -p "   EXP Date   : " exp
if [ -z $exp ]; then
cd
ui_line "[INFO] Please Input exp date"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi

x="ok"

satu="ON"
dua="OFF"
while true $x != "ok"
do
ui_blank
ui_line "${COLOR1}[01]${NC} • ADMIN   ${COLOR1}[02]${NC} • NORMAL"
ui_blank
echo -ne "   Input your choice : "; read list
echo ""
case "$list" in
   1) isadmin="$satu";break;;
   2) isadmin="$dua";break;;
esac
done


exp=$(date -d "$exp days" +"%Y-%m-%d")
hariini=$(date -d "0 days" +"%Y-%m-%d")
git config --global user.email "${EMAILGIT}" &> /dev/null
git config --global user.name "${USERGIT}" &> /dev/null
git clone https://github.com/${USERGIT}/permission.git &> /dev/null
cd /root/permission/ &> /dev/null
rm -rf .git &> /dev/null
git init &> /dev/null
touch ipmini &> /dev/null
touch newuser &> /dev/null
TEXT="
Name        : $client
Admin Panel : $isadmin
Exp         : $exp
IPVPS       : $daftar
Reg Date    : $hariini
"
echo "${TEXT}" >>/root/permission/newuser
echo "### $client $exp $daftar $isadmin" >>/root/permission/ipmini
git add .
git commit -m register &> /dev/null
git branch -M main &> /dev/null
git remote add origin https://github.com/${USERGIT}/permission.git &> /dev/null
git push -f https://${APIGIT}@github.com/${USERGIT}/permission.git &> /dev/null
sleep 1
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "Client IP Regested Successfully"
ui_blank
ui_line "Client Name   : $client"
ui_line "Admin Panel   : $isadmin"
ui_line "IP VPS        : $daftar"
ui_line "Register Date : $hariini"
ui_line "Expired Date  : $exp"
cd
rm -rf /root/permission
ui_card_end
echo ""
ui_pause
menu-ip
}
function delipvps(){
clear
rm -rf /root/permission &> /dev/null
git config --global user.email "${EMAILGIT}" &> /dev/null
git config --global user.name "${USERGIT}" &> /dev/null
git clone https://github.com/${USERGIT}/permission.git &> /dev/null
cd /root/permission/ &> /dev/null
rm -rf .git &> /dev/null
git init &> /dev/null
touch ipmini &> /dev/null
clear
ui_title "DELETE IPVPS"
ui_card_start
grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 2-4 | nl -s '. '
ui_card_end
echo ""
read -rp "   Please Input Number : " nombor
if [ -z $nombor ]; then
cd
clear
ui_title "DELETE IPVPS"
ui_line "[INFO] Please Input Correct Number"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi

name1=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 2 | sed -n "$nombor"p) #name
exp=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 3 | sed -n "$nombor"p) #exp
ivps1=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 4 | sed -n "$nombor"p) #ip
sed -i "s/### $name1 $exp $ivps1//g" /root/permission/ipmini &> /dev/null
hariini2=$(date -d "0 days" +"%Y-%m-%d")
TEXTD="
Name     : $name1
IPVPS    : $ivps1
Status   : Deleted on  $hariini2
"
echo "${TEXTD}" >>/root/permission/delete_log  &> /dev/null

git add . &> /dev/null
git commit -m remove &> /dev/null
git branch -M main &> /dev/null
git remote add origin https://github.com/${USERGIT}/permission.git &> /dev/null
git push -f https://${APIGIT}@github.com/${USERGIT}/permission.git &> /dev/null
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "Client IP Deleted Successfully"
ui_blank
ui_line "Ip VPS       : $ivps1"
ui_line "Expired Date : $exp"
ui_line "Client Name  : $name1"
cd
rm -rf /root/permission
ui_card_end
echo ""
ui_pause
menu-ip
}

function renewipvps(){
 clear
ui_title "REGISTER IPVPS"
ui_card_start
rm -rf /root/permission
git config --global user.email "${EMAILGIT}" &> /dev/null
git config --global user.name "${USERGIT}" &> /dev/null
git clone https://github.com/${USERGIT}/permission.git
cd /root/permission/
rm -rf .git
git init
touch ipmini
echo -e "   [ ${Lyellow}INFO${NC} ] Checking list.."

NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/root/permission/ipmini")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
  clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "[INFO] You have no existing clients!"
ui_card_end
echo ""
ui_pause
menu-ip
fi
clear
ui_title "REGISTER IPVPS"
ui_card_start
grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 2-4 | nl -s '. '
ui_card_end
echo -e ""
until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
  if [[ ${CLIENT_NUMBER} == '1' ]]; then
    read -rp " Select one client [1]: " CLIENT_NUMBER
  else
    read -rp " Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
  fi
if [ -z $CLIENT_NUMBER ]; then
cd
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "[INFO] Please Input Correct Number"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi
done
echo -e ""
read -p " Expired (days): " masaaktif
if [ -z $masaaktif ]; then
cd
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "[INFO] Please Input Correct Number"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi
name1=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p) #name
exp=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p) #exp
ivps1=$(grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p) #ip

now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(((d1 - d2) / 86400))
exp3=$(($exp2 + $masaaktif))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")
sed -i "s/### $name1 $exp $ivps1/### $name1 $exp4 $ivps1/g" /root/permission/ipmini
git add .
git commit -m renew
git branch -M main
git remote add origin https://github.com/${USERGIT}/permission.git
git push -f https://${APIGIT}@github.com/${USERGIT}/permission.git
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "Client IP VPS Renew Successfully"
ui_blank
ui_line "Ip VPS        : $ivps1"
ui_line "Renew Date    : $now"
ui_line "Days Added    : $masaaktif Days"
ui_line "Expired Date  : $exp4"
ui_line "Client Name   : $name1"
cd
rm -rf /root/permission
ui_card_end
echo ""
ui_pause
menu-ip
}

function useripvps(){
clear
rm -rf /root/permission
git config --global user.email "${EMAILGIT}"
git config --global user.name "${USERGIT}"
git clone https://github.com/${USERGIT}/permission.git
cd /root/permission/
rm -rf .git
git init
touch ipmini
clear
ui_title "REGISTER IPVPS"
ui_card_start
grep -E "^### " "/root/permission/ipmini" | cut -d ' ' -f 2 | nl -s '. '
ui_card_end
cd
rm -rf /root/permission
echo -e ""
ui_pause
menu-ip
}
function resetipvps(){
clear
rm -f /etc/yudhynetwork/github/email
rm -f /etc/yudhynetwork/github/username
rm -f /etc/yudhynetwork/github/api
rm -f /etc/yudhynetwork/github/gitstat
echo "OFF" > /etc/yudhynetwork/github/gitstat
ui_title "RESET GITHUB API"
ui_card_start
ui_line "[INFO] Github API Reseted Successfully"
ui_card_end
echo -e ""
ui_pause
menu-ip
}
Isadmin=$(curl -sS https://raw.githubusercontent.com/kenDevXD/permission/main/ipmini | grep $MYIP | awk '{print $5}')
if [ "$Isadmin" = "OFF" ]; then
clear
ui_title "PREMIUM USER ONLY"
ui_card_start
ui_line "[INFO] Only PRO Users Can Use This Panel"
ui_line "[INFO] Buy Premium Membership : "
ui_line "[INFO] PM : t.me/zenhost_official/"
ui_card_end
echo -e ""
ui_pause
menu-ip
fi
clear
ui_title "REGISTER IPVPS"
ui_card_start
GITREQ=/etc/yudhynetwork/github/gitstat
if [ -f "$GITREQ" ]; then
    cekk="ok"
else
    mkdir /etc/yudhynetwork/github
    touch /etc/yudhynetwork/github/gitstat
    echo "OFF" > /etc/yudhynetwork/github/gitstat
fi

stst1=$(cat /etc/yudhynetwork/github/gitstat)
if [ "$stst1" = "OFF" ]; then
clear
ui_title "REGISTER IPVPS"
ui_card_start
ui_line "• You Need To Set Github API First!"
ui_card_end
echo -e ""
ui_pause
setapi
fi
stst=$(cat /etc/yudhynetwork/github/gitstat)
if [ "$stst" = "ON" ]; then
APIOK="CEK API"
rex="viewapi"
else
APIOK="SET API"
rex="setapi"
fi
if [ "$stst" = "ON" ]; then
ISON="RESET API"
ressee="resetipvps"
else
ISON=""
ressee="menu-ip"
fi
ui_options "01:$APIOK" "04:Renew IP VPS" "02:Add IP VPS" "05:List IP VPS" "03:Delete IP VPS" "06:${ISON:-—}"
ui_card_end
ui_back_hint
ui_prompt
read -r opt
case $opt in
01 | 1) clear ; $rex ;;
02 | 2) clear ; add_ip ;;
03 | 3) clear ; delipvps ;;
04 | 4) clear ; renewipvps ;;
05 | 5) clear ; useripvps ;;
06 | 6) clear ; $ressee ;;
00 | 0 | x | X) clear ; menu ;;
*) clear ; menu-ip ;;
esac
