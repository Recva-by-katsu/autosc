#!/bin/bash
# Schedule the encrypted backup command once daily.
set -euo pipefail

CONF="${KATSU_CONF_DIR:-/etc/katsutun}/backup.conf"
CRON_FILE=/etc/cron.d/katsu-backup

configured() {
    [ -r "$CONF" ] || return 1
    # shellcheck disable=SC1090
    . "$CONF"
    [ -n "${RCLONE_REMOTE:-}" ] && [ -n "${BACKUP_EMAIL:-}" ] && [ -n "${BACKUP_ENCRYPTION_PASSWORD:-}" ]
}

case "${1:-}" in
    start)
        configured || { echo "Atur backup terlebih dahulu melalui backup_setting."; exit 1; }
        cat > "$CRON_FILE" <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
5 0 * * * root /usr/bin/backup >> /var/log/katsu-backup.log 2>&1
EOF
        chmod 644 "$CRON_FILE"
        echo "Auto backup aktif setiap hari pukul 00:05."
        ;;
    stop)
        rm -f "$CRON_FILE"
        echo "Auto backup dinonaktifkan."
        ;;
    status)
        [ -f "$CRON_FILE" ] && echo "Auto backup: aktif" || echo "Auto backup: nonaktif"
        ;;
    *)
        echo "1) Aktifkan auto backup  2) Nonaktifkan  3) Atur konfigurasi"
        read -rp "Pilih: " choice
        case "$choice" in
            1) "$0" start ;;
            2) "$0" stop ;;
            3) backup_setting ;;
            *) echo "Pilihan tidak valid"; exit 1 ;;
        esac
        ;;
esac
