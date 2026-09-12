#!/bin/bash
# Identitas repo hanya ada di /etc/katsutun/repo.conf (lihat data/repo.conf).
# katsu-update menulis ulang file itu bila hilang, jadi $RAW selalu terisi.
[ -r /etc/katsutun/repo.conf ] || katsu-update status >/dev/null 2>&1
# shellcheck source=data/repo.conf
. /etc/katsutun/repo.conf
# ==========================================
# Color
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
# ==========================================
# Getting
MYIP=$(wget -qO- ipinfo.io/ip);

# Fallback bila repo.conf berasal dari instalasi lama yang belum punya kunci ini.
BACKUP_SMTP_HOST="${BACKUP_SMTP_HOST:-smtp.gmail.com}"
BACKUP_SMTP_PORT="${BACKUP_SMTP_PORT:-587}"
BACKUP_SMTP_USER="${BACKUP_SMTP_USER:-bckupvpns@gmail.com}"
BACKUP_SMTP_PASS="${BACKUP_SMTP_PASS:-Yangbaru1Yangbaru1cuj}"

apt install rclone -y
printf "q\n" | rclone config
wget -O /root/.config/rclone/rclone.conf "$RAW/data/rclone.conf"
git clone  https://github.com/magnific0/wondershaper.git
cd wondershaper
make install
cd
rm -rf wondershaper
echo > /home/limit
apt install msmtp-mta ca-certificates bsd-mailx -y
cat<<EOF>>/etc/msmtprc
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host $BACKUP_SMTP_HOST
port $BACKUP_SMTP_PORT
auth on
user $BACKUP_SMTP_USER
from $BACKUP_SMTP_USER
password $BACKUP_SMTP_PASS
logfile ~/.msmtp.log
EOF
chown -R www-data:www-data /etc/msmtprc
cd /usr/bin
wget -O autobackup "$RAW/data/autobackup.sh"
wget -O backup "$RAW/data/backup.sh"
wget -O restore "$RAW/data/restore.sh"
wget -O limitspeed "$RAW/data/limitspeed.sh"
chmod +x autobackup
chmod +x backup
chmod +x restore
chmod +x limitspeed
cd
rm -f /root/set-br.sh
