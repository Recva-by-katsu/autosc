#!/bin/bash
# Validate the operating-system support matrix and derive a safe install profile.
set -euo pipefail

OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
CONF_DIR="${KATSU_CONF_DIR:-/etc/katsutun}"

if [ ! -r "$OS_RELEASE_FILE" ]; then
    echo "[ERROR] /etc/os-release tidak ditemukan"
    exit 1
fi

# shellcheck disable=SC1090
. "$OS_RELEASE_FILE"
case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|debian:10|debian:11|debian:12) ;;
    *)
        echo "[ERROR] OS tidak didukung: ${PRETTY_NAME:-$ID $VERSION_ID}"
        echo "        Dukungan: Ubuntu 20.04/22.04/24.04 atau Debian 10/11/12."
        exit 1
        ;;
esac

memory_mb=$(awk '/MemTotal:/ {print int($2 / 1024)}' /proc/meminfo)
cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
if [ "$memory_mb" -lt 768 ]; then
    profile="minimal"
elif [ "$memory_mb" -lt 2048 ]; then
    profile="standard"
else
    profile="performance"
fi

echo "[INFO] Sistem didukung: ${PRETTY_NAME:-$ID $VERSION_ID}"
echo "[INFO] Profil instalasi: $profile (${memory_mb} MiB RAM, ${cpu_count} CPU)"

if [ "${1:-}" = "--write" ]; then
    mkdir -p "$CONF_DIR"
    cat > "$CONF_DIR/system.conf" <<EOF
# Dibuat oleh system-check.sh saat instalasi.
OS_ID=$ID
OS_VERSION=$VERSION_ID
INSTALL_PROFILE=$profile
MEMORY_MB=$memory_mb
CPU_COUNT=$cpu_count
EOF
    chmod 644 "$CONF_DIR/system.conf"
fi
