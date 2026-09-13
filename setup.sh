#!/bin/bash

dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`

############# KatsuTun #############
#Text Coloring
clear
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
############# KatsuTun #############

#System version number
cd
if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
fi

############# Sumber script #############
# Satu-satunya tempat identitas repo di-hardcode (bersama data/katsu-update.sh),
# karena setup.sh diunduh sendirian sebelum repo.conf ada di VPS.
# Override saat install:  GH_USER=namaku GH_REPO=forkku ./setup.sh
GH_USER="${GH_USER:-Recva-by-katsu}"
GH_REPO="${GH_REPO:-autosc}"
GH_BRANCH="${GH_BRANCH:-main}"
KATSU_CONF_DIR="${KATSU_CONF_DIR:-/etc/katsutun}"
BOOTSTRAP_RAW="${KATSU_GH_RAW:-https://raw.githubusercontent.com}/$GH_USER/$GH_REPO/$GH_BRANCH"

bootstrap_repo_conf() {
    mkdir -p "$KATSU_CONF_DIR"
    if ! curl -fsSL "$BOOTSTRAP_RAW/data/repo.conf" -o "$KATSU_CONF_DIR/repo.conf"; then
        echo "Gagal mengunduh data/repo.conf dari $GH_USER/$GH_REPO@$GH_BRANCH"
        return 1
    fi
    # Jadikan pilihan repo ini default baru supaya update berikutnya tetap ke sini.
    sed -i -e "s|^GH_USER=.*|GH_USER=\"\${GH_USER:-$GH_USER}\"|" \
           -e "s|^GH_REPO=.*|GH_REPO=\"\${GH_REPO:-$GH_REPO}\"|" \
           -e "s|^GH_BRANCH=.*|GH_BRANCH=\"\${GH_BRANCH:-$GH_BRANCH}\"|" \
           "$KATSU_CONF_DIR/repo.conf"
    chmod 644 "$KATSU_CONF_DIR/repo.conf"
}
bootstrap_repo_conf || exit 1
# shellcheck source=data/repo.conf
. "$KATSU_CONF_DIR/repo.conf"
############# /Sumber script #############

# Fail early on unsupported releases and persist a small, reusable resource
# profile for the component installers.
curl -fsSL "$RAW/data/system-check.sh" -o /tmp/katsu-system-check.sh || {
    echo "Gagal mengunduh pemeriksa kompatibilitas sistem"
    exit 1
}
bash /tmp/katsu-system-check.sh --write || exit 1
rm -f /tmp/katsu-system-check.sh

localip=$(hostname -I | cut -d\  -f1)
hst=( `hostname` )
dart=$(cat /etc/hosts | grep -w `hostname` | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
echo "$localip $(hostname)" >> /etc/hosts
fi
mkdir -p /etc/xray

clear
echo -e "[ ${tyblue}NOTE${NC} ] KATSUTUN AUTO INSTALL SCRIPT.... "
sleep 1
echo -e "[ ${tyblue}NOTE${NC} ] Multi path, Multi port, support debian 10 , Ubuntu 20-18"
sleep 2
echo -e "[ ${green}INFO${NC} ] By KatsuTun"
sleep 1
echo -e "[ ${green}INFO${NC} ] $REPO_URL"
sleep 5

echo ""
yellow "Add Your Domain"
echo " "
read -rp "Input your domain : " -e pp
echo "$pp" > /root/domain
echo "$pp" > /root/scdomain
echo "$pp" > /etc/xray/domain
echo "$pp" > /etc/xray/scdomain
#echo "IP=$pp" > /var/lib/yudhynetwork-pro/ipvps.conf
echo ""

secs_to_human() {
    echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}
start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Disable IPV6
#sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
#sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

coreselect=''
cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear
END

chmod 644 /root/.profile

echo -e "[ ${green}INFO${NC} ] Preparing the install file 🛠"
apt update >/dev/null 2>&1
apt install git curl vnstat nload htop python3 nethogs ufw -y >/dev/null 2>&1
echo -e "[ ${green}INFO${NC} ] Alright good ... installation file is ready 📡"
sleep 2
echo -ne "[ ${green}INFO${NC} ] Check permission : success 😁"
sleep 3
mkdir -p /etc/yudhynetwork
mkdir -p /etc/yudhynetwork/theme
mkdir -p /var/lib/yudhynetwork-pro >/dev/null 2>&1
echo "IP=" >> /var/lib/yudhynetwork-pro/ipvps.conf

if [ -f "/etc/xray/config.json" ]; then
echo ""
echo -e "[ ${green}INFO${NC} ] Script Already Installed"
echo -ne "[ ${yell}WARNING${NC} ] Do you want to install again ? (y/n)? "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
rm setup.sh
sleep 10
exit 0
else
clear
fi
fi

echo ""
wget -q "$RAW/data/dependencies.sh";chmod +x dependencies.sh;./dependencies.sh
rm dependencies.sh
clear

############# KatsuTun #############
#THEME RED
cat <<EOF>> /etc/yudhynetwork/theme/red
BG : \E[40;1;41m
TEXT : \033[0;31m
EOF
#THEME BLUE
cat <<EOF>> /etc/yudhynetwork/theme/blue
BG : \E[40;1;44m
TEXT : \033[0;34m
EOF
#THEME GREEN
cat <<EOF>> /etc/yudhynetwork/theme/green
BG : \E[40;1;42m
TEXT : \033[0;32m
EOF
#THEME YELLOW
cat <<EOF>> /etc/yudhynetwork/theme/yellow
BG : \E[40;1;43m
TEXT : \033[0;33m
EOF
#THEME MAGENTA
cat <<EOF>> /etc/yudhynetwork/theme/magenta
BG : \E[40;1;43m
TEXT : \033[0;33m
EOF
#THEME CYAN
cat <<EOF>> /etc/yudhynetwork/theme/cyan
BG : \E[40;1;46m
TEXT : \033[0;36m
EOF
#THEME CONFIG
cat <<EOF>> /etc/yudhynetwork/theme/color.conf
blue
EOF
############# KatsuTun #############

#install ssh ovpn
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|     PROCESS INSTALLED SSH & OPENVPN      |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/ssh-vpn.sh" && chmod +x ssh-vpn.sh && ./ssh-vpn.sh
#Install Xray
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|          PROCESS INSTALLED XRAY          |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/ins-xray.sh" && chmod +x ins-xray.sh && ./ins-xray.sh
#Install SSH Websocket
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|      PROCESS INSTALLED WEBSOCKET SSH     |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/insshws.sh" && chmod +x insshws.sh && ./insshws.sh
#Install OHP Websocket
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|          PROCESS INSTALLED OHP           |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/ohp.sh" && chmod +x ohp.sh && ./ohp.sh
#Install AutoBackup
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|          PROCESS INSTALLED AUTO BACKUP           |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/set-br.sh" && chmod +x set-br.sh && ./set-br.sh
#Install REST API & Documentation
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|      PROCESS INSTALLED API & DOCS        |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
clear
wget "$RAW/data/api/ins-api.sh" && chmod +x ins-api.sh && ./ins-api.sh
rm -f ins-api.sh
#Install newest version straight from the latest GitHub commit + auto update
echo -e "${tyblue}.------------------------------------------.${NC}"
echo -e "${tyblue}|   INSTALL LATEST VERSION & AUTO UPDATE   |${NC}"
echo -e "${tyblue}'------------------------------------------'${NC}"
sleep 2
wget -q -O /usr/bin/katsu-update "$RAW/data/katsu-update.sh" && chmod +x /usr/bin/katsu-update
# Pulls every menu/helper listed in data/manifest.txt from the newest commit,
# writes /opt/.ver and enables the auto update cron (manage with menu-update).
katsu-update apply --force
katsu-update enable
# Telegram backup sender (used by menu-backup); previously installed by update.sh
mkdir -p /etc/lukman
wget -q -O /etc/lukman/dependencies.sh "$RAW/data/v1.1.0/dependencies.sh"; bash /etc/lukman/dependencies.sh
curl -s ipinfo.io/ip > /etc/lukman/ip
curl -s ipinfo.io/org | cut -d " " -f 2-10 > /etc/lukman/isp
curl -s ipinfo.io/city > /etc/lukman/city
clear

############# KatsuTun #############
# /root/.profile is installed by katsu-update from data/profile (see manifest).

############# KatsuTun #############

if [ -f "/root/log-install.txt" ]; then
rm /root/log-install.txt > /dev/null 2>&1
fi
if [ -f "/etc/afak.conf" ]; then
rm /etc/afak.conf > /dev/null 2>&1
fi
if [ ! -f "/etc/log-create-user.log" ]; then
echo "Log All Account " > /etc/log-create-user.log
fi
history -c
aureb=$(cat /home/re_otm)
b=11
if [ $aureb -gt $b ]
then
gg="PM"
else
gg="AM"
fi
curl -sS ifconfig.me > /etc/myipvps

############# KatsuTun #############

echo " "
echo "Installation has been completed!!"
echo " "
echo "=========================[SCRIPT PREMIUM]========================"
echo ""  | tee -a log-install.txt
echo "   >>> Service & Port"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "    [INFORMASI SSH ]" | tee -a log-install.txt
echo "    -------------------------" | tee -a log-install.txt
echo "   - OpenSSH                 : 22"  | tee -a log-install.txt
echo "   - Stunnel4                : 447, 777"  | tee -a log-install.txt
echo "   - Dropbear                : 109, 143"  | tee -a log-install.txt
echo "   - SSH Websocket           : 80"  | tee -a log-install.txt
echo "   - SSH SSL Websocket       : 443"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "    [INFORMASI  Badvpn, Nginx]" | tee -a log-install.txt
echo "    ---------------------------" | tee -a log-install.txt
echo "   - Badvpn                  : 7100-7900"  | tee -a log-install.txt
echo "   - Nginx                   : 81"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "    [INFORMASI Shadowsocks-R & Shadowsocks]"  | tee -a log-install.txt
echo "    ---------------------------------------" | tee -a log-install.txt
echo "   - Websocket Shadowsocks   : 443"  | tee -a log-install.txt
echo "   - Shadowsocks GRPC        : 443"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "    [INFORMASI XRAY]"  | tee -a log-install.txt
echo "    ----------------" | tee -a log-install.txt
echo "   - Xray Vmess Ws Tls       : 443"  | tee -a log-install.txt
echo "   - Xray Vless Ws Tls       : 443"  | tee -a log-install.txt
echo "   - Xray Vmess Ws None Tls  : 80"  | tee -a log-install.txt
echo "   - Xray Vless Ws None Tls  : 80"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "    [INFORMASI TROJAN]"  | tee -a log-install.txt
echo "    ------------------" | tee -a log-install.txt
echo "   - Websocket Trojan        : 443"  | tee -a log-install.txt
echo "   - Trojan GRPC             : 443"  | tee -a log-install.txt
echo "   --------------------------------------------------------------" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : Asia/Jakarta (GMT +7)"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot             : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Auto Reboot On           : $aureb:00 $gg GMT +7" | tee -a log-install.txt
echo "   - Custom Path " | tee -a log-install.txt
echo "   - Auto Backup Data" | tee -a log-install.txt
echo "   - AutoKill Multi Login User" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Fully Automatic Script" | tee -a log-install.txt
echo "   - VPS Settings" | tee -a log-install.txt
echo "   - Admin Control" | tee -a log-install.txt
echo "   - Backup & Restore Data" | tee -a log-install.txt
echo "   - Full Orders For Various Services" | tee -a log-install.txt
echo "   - REST API                : https://$pp/api" | tee -a log-install.txt
echo "   - API Documentation       : https://$pp/docs/" | tee -a log-install.txt
echo "   - API Key Management      : menu -> 13 (or: menu-api)" | tee -a log-install.txt
echo "   - Script Version          : v$(cat /opt/.ver) ($(cut -c1-7 /etc/katsutun/commit 2>/dev/null))" | tee -a log-install.txt
echo "   - Auto Update             : [ON] every 5 min from GitHub (menu -> 14)" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "=========================[SCRIPT PREMIUM]========================"
echo ""
sleep 3
echo -e "    ${tyblue}.------------------------------------------.${NC}"
echo -e "    ${tyblue}|     SUCCESFULLY INSTALLED THE SCRIPT     |${NC}"
echo -e "    ${tyblue}'------------------------------------------'${NC}"

rm /root/cf.sh >/dev/null 2>&1
rm /root/setup.sh >/dev/null 2>&1
rm /root/insshws.sh >/dev/null 2>&1
rm /root/lawsc >/dev/null 2>&1

echo ""
echo -e "Setting up autorefresh on xray user login"
#echo -ne "Choose between 1-30 minutes: "; read afresh
cd
wget -q "$RAW/data/addons/crontab.sh"
chmod +x crontab.sh; ./crontab.sh; rm crontab.sh
# crontab.sh rewrites /etc/crontab only; the auto update lives in /etc/cron.d
katsu-update cron

cat <<EOF > /usr/bin/regionchecker
#!/bin/bash
echo "0" | bash <(curl -L -a https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en -M 4
read -n 1 -s -r -p "  Press any key to go back"
menu-set
EOF
chmod +x /usr/bin/regionchecker

if [ -s /etc/autosc-api/first-key.txt ]; then
echo ""
echo "=========================[ API ACCESS ]========================="
echo " Your first API key (shown once, also saved in"
echo " /etc/autosc-api/first-key.txt):"
echo ""
echo "   $(cat /etc/autosc-api/first-key.txt)"
echo ""
echo " Docs : https://$pp/docs/"
echo " Usage: curl -H \"X-API-Key: <key>\" https://$pp/api/system/info"
echo " Manage keys later with: menu-api"
echo "================================================================"
fi

echo ""
echo -e "   ${tyblue}Your VPS Will Be Automatical Reboot In 10 seconds${NC}"

sleep 10
reboot
