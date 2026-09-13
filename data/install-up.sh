#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
###########- COLOR CODE -##############
colornow=$(cat /etc/yudhynetwork/theme/color.conf)
export NC="\e[0m"
export YELLOW='\033[0;33m';
export RED="\033[0;31m" 
export COLOR1="$(cat /etc/yudhynetwork/theme/$colornow | grep -w "TEXT" | cut -d: -f2|sed 's/ //g')"
export COLBG1="$(cat /etc/yudhynetwork/theme/$colornow | grep -w "BG" | cut -d: -f2|sed 's/ //g')"                    
###########- END COLOR CODE -##########

echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Remove Old Script"
rm /usr/bin/menu-bot

sleep 2
echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Downloading New Script"

mkdir -p /usr/local/lib/katsutun
wget -q -O /usr/local/lib/katsutun/ui.sh "$RAW/data/katsu-ui.sh" && chmod 644 /usr/local/lib/katsutun/ui.sh
wget -q -O /usr/bin/menu "$RAW/data/menu.sh" && chmod +x /usr/bin/menu
wget -q -O /usr/bin/menu-ss "$RAW/data/menu-ss.sh" && chmod +x /usr/bin/menu-ss
wget -q -O /usr/bin/menu-vmess "$RAW/data/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
wget -q -O /usr/bin/menu-vless "$RAW/data/menu-vless.sh" && chmod +x /usr/bin/menu-vless
wget -q -O /usr/bin/menu-trojan "$RAW/data/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
wget -q -O /usr/bin/menu-bot "$RAW/data/menu-bot.sh" && chmod +x /usr/bin/menu-bot
wget -q -O /usr/bin/menu-ssh "$RAW/data/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
wget -q -O /usr/bin/menu-set "$RAW/data/menu-set.sh" && chmod +x /usr/bin/menu-set
wget -q -O /usr/bin/menu-theme "$RAW/data/menu-theme.sh" && chmod +x /usr/bin/menu-theme
wget -q -O /usr/bin/menu-backup "$RAW/data/menu-backup.sh" && chmod +x /usr/bin/menu-backup
wget -q -O /usr/bin/menu-ip "$RAW/data/menu-ip.sh" && chmod +x /usr/bin/menu-ip
wget -q -O /usr/bin/menu-tor "$RAW/data/menu-tor.sh" && chmod +x /usr/bin/menu-tor
wget -q -O /usr/bin/autoboot "$RAW/data/autoboot.sh" && chmod +x /usr/bin/autoboot
wget -q -O /usr/bin/menu-tcp "$RAW/data/menu-tcp.sh" && chmod +x /usr/bin/menu-tcp
wget -q -O /usr/bin/rebootvps "$RAW/data/rebootvps.sh" && chmod +x /usr/bin/rebootvps
wget -q -O /usr/bin/menu-dns "$RAW/data/menu-dns.sh" && chmod +x /usr/bin/menu-dns
wget -q -O /usr/bin/info "$RAW/data/info.sh" && chmod +x /usr/bin/info
wget -q -O /usr/bin/mspeed "$RAW/data/menu-speedtest.sh" && chmod +x /usr/bin/mspeed
wget -q -O /usr/bin/mbandwith "$RAW/data/menu-bandwith.sh" && chmod +x /usr/bin/mbandwith
wget -q -O /usr/bin/restart "$RAW/data/restart.sh" && chmod +x /usr/bin/restart
wget -q -O /usr/bin/update "$RAW/data/update.sh" && chmod +x /usr/bin/update
echo -e " [INFO] Update Successfully"
wget -q -O /opt/.ver "$RAW/data/version"

sleep 2
echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Download Changelog File"
wget -q -O /root/changelog.txt "$RAW/data/changelog.txt" && chmod +x /root/changelog.txt
echo -e "$COLOR1│${NC}  $COLOR1[INFO]${NC} Read Changelog? do \"cat /root/changelog.txt\""
sleep 2
