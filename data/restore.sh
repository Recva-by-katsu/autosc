#!/bin/bash
set -euo pipefail
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
clear
echo "This Feature Can Only Be Used According To Vps Data With This Autoscript"
echo "Please input link to your vps data backup file."
echo "You can check it on your email if you run backup data vps before."
read -rp "Link File: " -e url
read -rsp "Password enkripsi backup: " backup_password
echo
if [ -z "$backup_password" ]; then
    echo "Password enkripsi wajib diisi."
    exit 1
fi
umask 077
wget -O backup.zip.enc "$url"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in backup.zip.enc -out backup.zip -pass pass:"$backup_password"
unzip backup.zip
rm -f backup.zip backup.zip.enc
sleep 1
echo Start Restore
cd /root/backup
cp passwd /etc/
cp group /etc/
cp shadow /etc/
cp gshadow /etc/
cp -r alexxa-pro /var/lib/
cp -r xray /etc/
cp -r public_html /home/vps/
cp crontab /etc/
rm -rf /root/backup
rm -f backup.zip backup.zip.enc
echo Done
