#!/bin/bash
# Configure private backup settings without storing credentials in Git.
set -euo pipefail

CONF_DIR="${KATSU_CONF_DIR:-/etc/katsutun}"
CONF="$CONF_DIR/backup.conf"
mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"

current() {
    [ -r "$CONF" ] || return 0
    # shellcheck disable=SC1090
    . "$CONF"
}

configure() {
    current
    read -rp "Nama remote rclone (tanpa titik dua) [${RCLONE_REMOTE:-}]: " remote
    remote=${remote:-${RCLONE_REMOTE:-}}
    read -rp "Email penerima backup [${BACKUP_EMAIL:-}]: " recipient
    recipient=${recipient:-${BACKUP_EMAIL:-}}
    read -rsp "Password enkripsi backup (kosongkan untuk mempertahankan): " encryption
    echo
    encryption=${encryption:-${BACKUP_ENCRYPTION_PASSWORD:-}}

    if [[ ! "$remote" =~ ^[A-Za-z0-9_-]+$ ]] || [[ ! "$recipient" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || [ -z "$encryption" ]; then
        echo "Remote, email valid, dan password enkripsi wajib diisi."
        return 1
    fi

    read -rp "Host SMTP opsional (kosong = MTA lokal) [${BACKUP_SMTP_HOST:-}]: " smtp_host
    smtp_host=${smtp_host:-${BACKUP_SMTP_HOST:-}}
    smtp_port=${BACKUP_SMTP_PORT:-587}
    smtp_user=${BACKUP_SMTP_USER:-}
    smtp_pass=${BACKUP_SMTP_PASS:-}
    if [ -n "$smtp_host" ]; then
        read -rp "Port SMTP [$smtp_port]: " value; smtp_port=${value:-$smtp_port}
        read -rp "User SMTP [$smtp_user]: " value; smtp_user=${value:-$smtp_user}
        read -rsp "Password SMTP (kosongkan untuk mempertahankan): " value; echo
        smtp_pass=${value:-$smtp_pass}
        [ -n "$smtp_user" ] && [ -n "$smtp_pass" ] || { echo "User dan password SMTP wajib diisi."; return 1; }
    fi

    tmp=$(mktemp "$CONF.XXXXXX")
    {
        printf 'RCLONE_REMOTE=%q\n' "$remote"
        printf 'BACKUP_EMAIL=%q\n' "$recipient"
        printf 'BACKUP_ENCRYPTION_PASSWORD=%q\n' "$encryption"
        printf 'BACKUP_SMTP_HOST=%q\n' "$smtp_host"
        printf 'BACKUP_SMTP_PORT=%q\n' "$smtp_port"
        printf 'BACKUP_SMTP_USER=%q\n' "$smtp_user"
        printf 'BACKUP_SMTP_PASS=%q\n' "$smtp_pass"
    } > "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$CONF"

    if [ -n "$smtp_host" ]; then
        cat > /etc/msmtprc <<EOF

defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account default
host $smtp_host
port $smtp_port
auth on
user $smtp_user
from $smtp_user
password $smtp_pass
logfile /var/log/msmtp.log
EOF
        chmod 600 /etc/msmtprc
        chown root:root /etc/msmtprc
    fi
    echo "Konfigurasi backup tersimpan dengan mode 600."
}

case "${1:-}" in
    --show) current; printf 'Remote: %s\nEmail: %s\n' "${RCLONE_REMOTE:-belum diatur}" "${BACKUP_EMAIL:-belum diatur}" ;;
    *)
        echo "Sebelum melanjutkan, buat remote penyimpanan dengan: rclone config"
        configure
        ;;
esac
