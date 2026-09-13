#!/bin/bash
#!/bin/bash
set -euo pipefail

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
clear
IP=$(wget -qO- ipinfo.io/ip);
date=$(date +"%Y-%m-%d")
clear
BACKUP_CONF="${KATSU_CONF_DIR:-/etc/katsutun}/backup.conf"
if [ ! -r "$BACKUP_CONF" ]; then
    echo "Konfigurasi backup belum tersedia. Jalankan backup_setting terlebih dahulu."
    exit 1
fi
# shellcheck disable=SC1090
. "$BACKUP_CONF"
if [ -z "${RCLONE_REMOTE:-}" ] || [ -z "${BACKUP_EMAIL:-}" ] || [ -z "${BACKUP_ENCRYPTION_PASSWORD:-}" ]; then
    echo "Isi RCLONE_REMOTE, BACKUP_EMAIL, dan BACKUP_ENCRYPTION_PASSWORD di $BACKUP_CONF terlebih dahulu."
    exit 1
fi
umask 077
export BACKUP_ENCRYPTION_PASSWORD
clear
echo "Mohon Menunggu , Proses Backup sedang berlangsung !!"
rm -rf /root/backup
mkdir /root/backup
cp /etc/passwd backup/
cp /etc/group backup/
cp /etc/shadow backup/
cp /etc/gshadow backup/
cp /etc/crontab backup/
if [ -d /var/lib/alexxa-pro ]; then
    cp -r /var/lib/alexxa-pro/ backup/alexxa-pro
fi
cp -r /etc/xray backup/xray
cp -r /home/vps/public_html backup/public_html
cd /root
archive="$IP-$date.zip"
encrypted_archive="$archive.enc"
zip -r "$archive" backup > /dev/null 2>&1
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
  -in "$archive" -out "$encrypted_archive" -pass env:BACKUP_ENCRYPTION_PASSWORD
rm -f "$archive"
rclone copy "/root/$encrypted_archive" "$RCLONE_REMOTE:backup/"
url=$(rclone link "$RCLONE_REMOTE:backup/$encrypted_archive")
id=(`echo $url | grep '^https' | cut -d'=' -f2`)
link="https://drive.google.com/u/4/uc?id=${id}&export=download"
echo -e "
Detail Backup 
==================================
IP VPS        : $IP
Link Backup   : $link
Tanggal       : $date
==================================
" | mail -s "Backup Data" "$BACKUP_EMAIL"
rm -rf /root/backup
rm -f "/root/$encrypted_archive"
clear
echo -e "
Detail Backup 
==================================
IP VPS        : $IP
Link Backup   : $link
Tanggal       : $date
==================================
"
echo "BACKUP BERHASIL SILAHKAN SALIN LINK DIATAS"
