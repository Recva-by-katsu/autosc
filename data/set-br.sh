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

CONF_DIR="${KATSU_CONF_DIR:-/etc/katsutun}"
BACKUP_CONF="$CONF_DIR/backup.conf"

apt install rclone msmtp-mta ca-certificates bsd-mailx -y
mkdir -p "$CONF_DIR"
if [ ! -s "$BACKUP_CONF" ]; then
cat > "$BACKUP_CONF" <<'EOF'
# Private backup configuration. Keep this file mode 600 and never commit it.
# Configure a named remote first: rclone config
RCLONE_REMOTE=""
BACKUP_EMAIL=""
BACKUP_ENCRYPTION_PASSWORD=""

# Optional SMTP delivery. Leave blank when the VPS already has a local MTA.
BACKUP_SMTP_HOST=""
BACKUP_SMTP_PORT="587"
BACKUP_SMTP_USER=""
BACKUP_SMTP_PASS=""
EOF
chmod 600 "$BACKUP_CONF"
fi

# shellcheck disable=SC1090
. "$BACKUP_CONF"
git clone  https://github.com/magnific0/wondershaper.git
cd wondershaper
make install
cd
rm -rf wondershaper
echo > /home/limit
if [ -n "${BACKUP_SMTP_HOST:-}" ] && [ -n "${BACKUP_SMTP_USER:-}" ] && [ -n "${BACKUP_SMTP_PASS:-}" ]; then
cat >/etc/msmtprc <<EOF
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
chmod 600 /etc/msmtprc
chown root:root /etc/msmtprc
fi
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
echo "[INFO] Konfigurasi backup: $BACKUP_CONF"
echo "[INFO] Jalankan 'rclone config', lalu isi RCLONE_REMOTE, BACKUP_EMAIL, dan BACKUP_ENCRYPTION_PASSWORD."
